`include "src/types.svh"
`timescale 1ns/1ps


module top
  #( parameter MEM_SIZE = 1024 )
  ( input wire clk
  , input wire reset
  );

  /* verilator lint_off UNUSEDSIGNAL */
  logic [31:0] dbg_regs [0:31];
  addr_t dbg_pc;
  /* verilator lint_on UNUSEDSIGNAL */

  addr_t       memory__address;
  data_t       memory__write_data;
  logic  [3:0] memory__write_enable;
  data_t       memory__read_data;

  MA #( .SIZE ( MEM_SIZE ) )
    memory
      ( .clk          ( clk                  )
      , .address      ( memory__address      )
      , .write_data   ( memory__write_data   )
      , .write_enable ( memory__write_enable )
      , .read_data    ( memory__read_data    )
      );

  utoss_riscv core
    ( .clk    ( clk    )
    , .reset  ( reset  )

    , .memory__address      ( memory__address      )
    , .memory__write_data   ( memory__write_data   )
    , .memory__write_enable ( memory__write_enable )
    , .memory__read_data    ( memory__read_data    )

    , .dbg_regs ( dbg_regs )
    , .dbg_pc   ( dbg_pc   )
    );

endmodule
