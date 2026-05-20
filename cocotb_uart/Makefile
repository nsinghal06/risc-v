SIM           = icarus
TOPLEVEL_LANG = verilog
VERILOG_SOURCES = \
	$(PWD)/../src/uart_rx.sv \
	$(PWD)/../src/uart_tx.sv \
	$(PWD)/../src/uart.sv \
	$(PWD)/../src/uart_bus_master.sv \
	$(PWD)/../src/uart_top.sv
TOPLEVEL      = uart_top
COCOTB_TEST_MODULES = test_uart_master

include $(shell cocotb-config --makefiles)/Makefile.sim
