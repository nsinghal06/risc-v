`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/interfaces/ex_to_mem_if.svh"
`include "src/interfaces/mem_to_wb_if.svh"

module memory_stage
  ( input ex_to_mem_t ex_to_mem

  , input  data_t      data_from_memory
  , output data_t      data_to_memory
  , output logic [3:0] mem_write_enable
  , output addr_t      mem_address

  , output mem_to_wb_t mem_to_wb
  );

  // Inputs from EX_to_MEM interface
  data_t write_data_m;
  data_t alu_result_m;
  logic  mem_write;

  assign write_data_m = ex_to_mem.write_data_e;
  assign alu_result_m = ex_to_mem.alu_result;
  assign mem_write    = ex_to_mem.mem_write;

  logic [3:0] temp_mem_write_byte_address;

  MemoryLoader memory_loader
    ( .memory_data         ( data_from_memory            )
    , .memory_address      ( alu_result_m                )
    , .funct3              ( ex_to_mem.funct3            )
    , .dataB               ( write_data_m                )
    , .mem_load_result     ( mem_to_wb.read_data         )
    , .MemWriteByteAddress ( temp_mem_write_byte_address )
    , .__tmp_MemData       ( data_to_memory              )
    );

  assign mem_write_enable = (mem_write == 'b0) ? 4'b0 : temp_mem_write_byte_address;
  assign mem_address = ex_to_mem.alu_result;

  // Combinational assignment to MEM_to_WB interface
  assign mem_to_wb.reg_write  = ex_to_mem.reg_write;
  assign mem_to_wb.result_src = ex_to_mem.result_src;
  assign mem_to_wb.rd         = ex_to_mem.rd;
  assign mem_to_wb.alu_result = ex_to_mem.alu_result;
  assign mem_to_wb.pc_cur     = ex_to_mem.pc_cur;
  assign mem_to_wb.pc_plus_4  = ex_to_mem.pc_plus_4;
  assign mem_to_wb.funct3     = ex_to_mem.funct3;

  // TODO: can we remove pc_cur from EX->MEM?
  wire unused = &{ex_to_mem.pc_cur};

endmodule
