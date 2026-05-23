`timescale 1ns / 1ps

// Top-level wrapper for cocotb full-chain testing.
// Connects uart.sv (bit-level RX/TX) to uart_bus_master.sv (protocol FSM)
// so the testbench only needs to drive i_rxd / o_txd serial lines.
module uart_top #(
    parameter DATA_WIDTH = 8,
    parameter CLK_HZ     = 50000000,
    parameter BAUD       = 115200
)(
    input  wire clk,
    input  wire rst,

    input  wire i_rxd,
    output wire o_txd,

    output wire [31:0] bus_addr,
    output wire [31:0] bus_write_data,
    output wire [3:0]  bus_write_enable,
    input  wire [31:0] bus_read_data,
    output wire        hold_core,

    input  logic [31:0] dbg_regs [0:31],
    input  logic [31:0] dbg_pc
);

    // Internal byte-level bus between uart and uart_bus_master
    wire [7:0] rx_data;
    wire       rx_valid;
    wire       rx_ready;
    wire [7:0] tx_data;
    wire       tx_valid;
    wire       tx_ready;

    uart #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_HZ    (CLK_HZ),
        .BAUD      (BAUD)
    ) uart_inst (
        .clk              (clk),
        .rst              (rst),
        // TX: bus_master → uart_tx → serial
        .i_data_s         (tx_data),
        .i_valid_s        (tx_valid),
        .o_ready_s        (tx_ready),
        // RX: serial → uart_rx → bus_master
        .o_data_m         (rx_data),
        .o_valid_m        (rx_valid),
        .i_ready_m        (rx_ready),
        // Serial pins
        .i_rxd            (i_rxd),
        .o_txd            (o_txd)
    );

    uart_bus_master bus_master_inst (
        .clk             (clk),
        .rst             (rst),
        .rx_data         (rx_data),
        .rx_valid        (rx_valid),
        .rx_ready        (rx_ready),
        .tx_data         (tx_data),
        .tx_valid        (tx_valid),
        .tx_ready        (tx_ready),
        .bus_addr        (bus_addr),
        .bus_write_data  (bus_write_data),
        .bus_write_enable(bus_write_enable),
        .bus_read_data   (bus_read_data),
        .hold_core       (hold_core),
        .dbg_regs        (dbg_regs),
        .dbg_pc          (dbg_pc)
    );

endmodule
