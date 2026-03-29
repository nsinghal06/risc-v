import serial
import time


def hx(b: bytes) -> str:
    return " ".join(f"{x:02x}" for x in b)

def xor_chk(bs: bytes) -> int:
    c = 0
    for b in bs:
        c ^= b
    return c & 0xFF

def read_exact(ser, n) -> bytes:
    d = ser.read(n)
    if len(d) != n:
        raise RuntimeError(f"need {n}, got {len(d)}: {hx(d)}")
    return d

def expect_ack(resp: bytes, label: str) -> int:

    if len(resp) != 4 or resp[0] != 0x5A or resp[1] != 0x90:
        raise RuntimeError(f"{label}: not ACK: {hx(resp)}")
    status = resp[2]
    chk = resp[3]
    exp = (0x90 ^ status) & 0xFF
    if chk != exp:
        raise RuntimeError(f"{label}: bad ACK chk got {chk:02x} expect {exp:02x} frame={hx(resp)}")
    return status

def cmd_halt(ser):
    ser.write(bytes([0xA5, 0x13, 0x13]))  # CHK=0x13
    resp = read_exact(ser, 4)
    st = expect_ack(resp, "HALT")
    print("HALT resp:", hx(resp), "status=", hex(st))
    return st

def cmd_run(ser):
    ser.write(bytes([0xA5, 0x12, 0x12]))  # CHK=0x12
    resp = read_exact(ser, 4)
    st = expect_ack(resp, "RUN")
    print("RUN  resp:", hx(resp), "status=", hex(st))
    return st

def cmd_wr32(ser, addr: int, data: int):
    pkt = bytearray([0xA5, 0x10])
    pkt += addr.to_bytes(4, "little")
    pkt += data.to_bytes(4, "little")
    pkt += bytes([xor_chk(pkt[1:])])
    ser.write(pkt)
    resp = read_exact(ser, 4)
    st = expect_ack(resp, "WR32")
    if st != 0:
        raise RuntimeError(f"WR32 status={st:02x} addr=0x{addr:08x} resp={hx(resp)}")
    return st

def cmd_rdreg(ser, reg_idx: int) -> int:
    reg_idx &= 0x1F
    cmd = 0x14
    chk = cmd ^ reg_idx
    ser.write(bytes([0xA5, cmd, reg_idx, chk]))

    hdr = read_exact(ser, 2)

    if hdr == bytes([0x5A, 0x90]):
        tail = read_exact(ser, 2)
        st = expect_ack(hdr + tail, "RDREG(ACK)")
        raise RuntimeError(f"RDREG returned ACK status=0x{st:02x} frame={hx(hdr+tail)}")

    if hdr != bytes([0x5A, 0x92]):
        rest = ser.read(16)
        raise RuntimeError(f"RDREG bad header: {hx(hdr)} rest={hx(rest)}")

    rest = read_exact(ser, 5)  # d0 d1 d2 d3 chk
    d0, d1, d2, d3, rcv_chk = rest
    exp_chk = (0x92 ^ d0 ^ d1 ^ d2 ^ d3) & 0xFF
    if rcv_chk != exp_chk:
        raise RuntimeError(f"RDREG bad chk got {rcv_chk:02x} expect {exp_chk:02x} frame={hx(hdr+rest)}")

    return int.from_bytes(bytes([d0, d1, d2, d3]), "little")


def parse_hex_file(filename):
    try:
        with open(filename, 'r') as f:
            return [int(line.strip(), 16) for line in f if line.strip()]
    except FileNotFoundError:
        print(f"Wow there! Error: {filename} not found.")
        return []
    except ValueError:
        print(f"Hold it right there. Error: {filename} contains invalid hex data.")
        return []


def main_menu(ser):
    print("   ___  _______________   ____")
    print("  / _ \\/  _/ __/ ___/ /  /  _/")
    print(" / , _// /_\\ \\/ /__/ /___/ /  ")
    print("/_/|_/___/___/\\___/____/___/ ")
    print()
    print("Pick an option (1-4)")
    print("1. Load program in memory")
    print("2. Run program in memory")
    print("3. Instruction console")
    print("4. Exit")
    
    try:
        command = int(input("?> "))
    except ValueError:
        print("Invalid selection. Please enter a number 1-4.")
        return 0
    
    if command == 1:  # upload program

        filename = input("Input filename > ").strip()
        WORDS = parse_hex_file(filename)
        if not WORDS:
            print("No data loaded; aborting upload.")
            return 0

        print("Loading program...") # TODO: Add proper RV31I assembly instruction support
        base = 0x00000000
        for i, w in enumerate(WORDS):
            addr = base + 4*i
            cmd_wr32(ser, addr, w)
            if (i % 4) == 3:
                print(f"Wrote up to 0x{addr:08x}")
        print("Program loaded!")

        run = input("Run program? (y/n) > ").lower()
        if run == "y":
            cmd_run(ser)
            print("Program execution completed.")
        return 0

    if command == 2:
        run = input("Run program? (y/n) > ").lower()
        if run == "y":
            cmd_run(ser)
            print("Program execution completed.")
        return 0

    if command == 3: # TODO: Add ability to send instructions sequentially in console interface
        print("Instruction console not implemented yet.")
        return 0

    if command == 4:
        return 1

    print("Invalid selection. Please choose 1-4.")
    return 0


def main():

    user_ready = False
    COM = ""
    BAUD = 0
    
    while (not user_ready):
        COM = input("Input serial port (e.g. COM8) > ") # TODO: Add dynamic serial port detection and selection instead of manual input
        BAUD = int(input("Input baud rate (e.g. 115200) > "))
        ready = input(f"Confirm serial port: {COM}, baud rate: {BAUD}, (y/n) > ").lower()
        if ready == "y":
            user_ready = True
    
    TIMEOUT = 1.0
    WORDS = []

    try:
        ser = serial.Serial(COM, BAUD, timeout=TIMEOUT)
        time.sleep(0.2)
        print(f"{COM} opened successfully!")
    except serial.serialutil.SerialException as e:
        print(f"Oops! An error occurred with the serial connection: {e}")
        return
    except Exception as e:
        print(f"Oh no! An unexpected error occurred: {e}")
        return  

    ser.reset_input_buffer()
    ser.reset_output_buffer()

    cmd_halt(ser)

    while (main_menu(ser) != 1):
        pass
    ser.close()
    print("Serial port closed. Goodbye.")


if __name__ == "__main__":
    main()