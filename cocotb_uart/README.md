# How to test uart

## Requirements:

Python 3.9+
cocotb — pip install cocotb
cocotbext-uart — pip install cocotbext-uart
Icarus Verilog — brew install icarus-verilog on Mac

In the cocotb_uart/ folder:

## to run all tests:

make SIM=icarus

## to run a single test:

make SIM=icarus COCOTB_TEST_FILTER=test_halt

## What each test does:

test_halt — sends HALT, verifies the DUT asserts hold_core
test_wr32 — sends HALT then writes a word, verifies correct address and data appear on the bus
test_load_and_run — full CLI flow: halt, load 20 program words, run. Mirrors cli option 1 in uart_cli.py. Takes ~30 seconds due to real baud-rate timing.
test_rdreg — reads back a register value through the debug interface
test_bad_checksum — verifies the DUT rejects a corrupted packet with STATUS_CHK