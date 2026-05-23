import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.uart import UartSource, UartSink

from uart_cli import xor_chk, hx, expect_ack

BAUD = 115200

# changes made:
# - in uart_bus_master: declared state before assigned rx_ready, just something icarus verilator needs
# - created a new top level wrapper with all uart modules to connect to the cocotb uart module
# - makefile


async def recv(sink, n: int) -> bytes:
    """Wait until n bytes have arrived in the UartSink queue, then return them.

    sink.read() in cocotbext-uart v0.1.4 is synchronous — it raises QueueEmpty
    if the bytes haven't arrived yet. sink.wait() is async and suspends until
    at least one more byte appears, so we loop until we've collected enough.
    """
    data = bytearray()
    while len(data) < n:
        await sink.wait()
        data.extend(sink.read_nowait())
    return bytes(data[:n])


# ---------------------------------------------------------------------------
# Async command helpers
#
# These mirror the cmd_* functions in uart_cli.py exactly, but use
# UartSource/UartSink instead of a pyserial Serial object. The logic —
# packet layout, checksums, response parsing — is identical to what runs
# on real hardware.
# ---------------------------------------------------------------------------

async def cmd_halt(source, sink):
    source.write_nowait(bytes([0xA5, 0x13, 0x13]))
    resp = bytes(await recv(sink, 4))
    return expect_ack(resp, "HALT")


async def cmd_run(source, sink):
    source.write_nowait(bytes([0xA5, 0x12, 0x12]))
    resp = bytes(await recv(sink, 4))
    return expect_ack(resp, "RUN")


async def cmd_wr32(source, sink, addr: int, data: int):
    pkt = bytearray([0xA5, 0x10])
    pkt += addr.to_bytes(4, "little")
    pkt += data.to_bytes(4, "little")
    pkt += bytes([xor_chk(pkt[1:])])
    source.write_nowait(bytes(pkt))
    resp = bytes(await recv(sink, 4))
    st = expect_ack(resp, "WR32")
    if st != 0:
        raise RuntimeError(f"WR32 status={st:02x} addr=0x{addr:08x} resp={hx(resp)}")
    return st


async def cmd_rdreg(source, sink, reg_idx: int) -> int:
    reg_idx &= 0x1F
    cmd = 0x14
    source.write_nowait(bytes([0xA5, cmd, reg_idx, cmd ^ reg_idx]))
    resp = bytes(await recv(sink, 7))  # 5A 92 d0 d1 d2 d3 chk
    if resp[0] != 0x5A or resp[1] != 0x92:
        raise RuntimeError(f"RDREG bad header: {hx(resp)}")
    exp_chk = (0x92 ^ resp[2] ^ resp[3] ^ resp[4] ^ resp[5]) & 0xFF
    if resp[6] != exp_chk:
        raise RuntimeError(f"RDREG bad chk got {resp[6]:02x} expect {exp_chk:02x} frame={hx(resp)}")
    return int.from_bytes(resp[2:6], "little")


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

async def reset_dut(dut):
    dut.rst.value           = 1
    dut.bus_read_data.value = 0
    for i in range(32):
        dut.dbg_regs[i].value = 0
    dut.dbg_pc.value = 0
    await Timer(200, units="ns")
    dut.rst.value = 0
    await Timer(100, units="ns")


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_halt(dut):
    """HALT travels through uart_rx → uart_bus_master → uart_tx and back."""
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    source = UartSource(dut.i_rxd, baud=BAUD, bits=8)
    sink   = UartSink  (dut.o_txd, baud=BAUD, bits=8)
    await reset_dut(dut)

    await cmd_halt(source, sink)

    assert int(dut.hold_core.value) == 1, "hold_core should be 1 after HALT"


@cocotb.test()
async def test_wr32(dut):
    """HALT then write 0xDEADBEEF to address 0 and verify the bus outputs.

    bus_write_enable is a one-cycle strobe inside uart_bus_master. A background
    watcher catches it the cycle it fires; by the time the ACK arrives over
    the serial link the strobe is long gone.
    """
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    source = UartSource(dut.i_rxd, baud=BAUD, bits=8)
    sink   = UartSink  (dut.o_txd, baud=BAUD, bits=8)
    await reset_dut(dut)

    await cmd_halt(source, sink)

    captured = {}
    async def watch_strobe():
        while True:
            await RisingEdge(dut.clk)
            if int(dut.bus_write_enable.value) == 0b1111:
                captured["addr"] = int(dut.bus_addr.value)
                captured["data"] = int(dut.bus_write_data.value)
                break
    cocotb.start_soon(watch_strobe())

    await cmd_wr32(source, sink, 0x00000000, 0xDEADBEEF)

    assert captured.get("addr") == 0x00000000, "wrong bus address"
    assert captured.get("data") == 0xDEADBEEF, "wrong write data"


@cocotb.test()
async def test_load_and_run(dut):
    """Full CLI flow: halt, load a program word-by-word, run.

    This replicates exactly what uart_cli.py does in menu option 1 + run,
    using the same WORDS from test_uart.py. The entire sequence goes through
    uart_rx and uart_tx at real 115200 baud timing.
    """
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    source = UartSource(dut.i_rxd, baud=BAUD, bits=8)
    sink   = UartSink  (dut.o_txd, baud=BAUD, bits=8)
    await reset_dut(dut)

    WORDS = [
        0xFE010113, 0x00112E23, 0x00812C23, 0x00912A23,
        0x02010413, 0x00000493, 0x00148793, 0x3FF7F493,
        0x100007B7, 0x0097A023, 0xFE042623, 0x0100006F,
        0xFEC42783, 0x00178793, 0xFEF42623, 0xFEC42703,
        0x000F47B7, 0x23F78793, 0xFEE7D4E3, 0xFCDFF06F,
    ]

    await cmd_halt(source, sink)

    base = 0x00000000
    for i, w in enumerate(WORDS):
        addr = base + 4 * i
        await cmd_wr32(source, sink, addr, w)
        dut._log.info(f"  wrote 0x{w:08x} → 0x{addr:08x}")

    await cmd_run(source, sink)

    assert int(dut.hold_core.value) == 0, "hold_core should be 0 after RUN"


@cocotb.test()
async def test_rdreg(dut):
    """Drive dbg_regs[9] to a known value and verify RDREG echoes it back."""
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    source = UartSource(dut.i_rxd, baud=BAUD, bits=8)
    sink   = UartSink  (dut.o_txd, baud=BAUD, bits=8)
    await reset_dut(dut)

    dut.dbg_regs[9].value = 0xCAFEBABE

    val = await cmd_rdreg(source, sink, 9)

    assert val == 0xCAFEBABE, f"expected 0xCAFEBABE, got {val:#010x}"


@cocotb.test()
async def test_bad_checksum(dut):
    """Corrupt a packet checksum and verify STATUS_CHK (0x01) is returned."""
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    source = UartSource(dut.i_rxd, baud=BAUD, bits=8)
    sink   = UartSink  (dut.o_txd, baud=BAUD, bits=8)
    await reset_dut(dut)

    good = bytes([0xA5, 0x13, 0x13])
    bad  = good[:-1] + bytes([good[-1] ^ 0xFF])   # flip all bits in CHK byte
    source.write_nowait(bad)
    resp = bytes(await recv(sink, 4))

    dut._log.info(f"bad-chk resp: {hx(resp)}")
    assert resp[0] == 0x5A and resp[1] == 0x90, f"expected ACK frame, got {hx(resp)}"
    assert resp[2] == 0x01, f"expected STATUS_CHK 0x01, got {resp[2]:02x}"
