`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/interfaces/ex_to_mem_if.svh"
`include "src/interfaces/mem_to_wb_if.svh"

module mem_stage
  ( input ex_to_mem_t ex_to_mem
  , input data_t dataFromMemory
  , output data_t dataToMemory
  , output logic [3:0] memWriteEnable
  , output addr_t mem_address
  , output mem_to_wb_t mem_to_wb
  );

  // Inputs from EX_to_MEM interface
  data_t WriteDataM;
  data_t ALUResultM;
  logic MemWrite;

  // logic [3:0] MemWriteByteAddress;

  assign WriteDataM = ex_to_mem.write_data_e;
  assign ALUResultM = ex_to_mem.alu_result;
  assign MemWrite = ex_to_mem.mem_write;

  logic [3:0] tempMemWriteByteAddress;
  MemoryLoader memory_loader
    ( .memory_data         ( dataFromMemory          )
    , .memory_address      ( ALUResultM              )
    , .funct3              ( ex_to_mem.funct3        )
    , .dataB               ( WriteDataM              )
    , .mem_load_result     ( mem_to_wb.read_data     )
    , .MemWriteByteAddress ( tempMemWriteByteAddress )
    , .__tmp_MemData       ( dataToMemory            )
    );

  assign memWriteEnable = (MemWrite == 'b0) ? 4'b0 : tempMemWriteByteAddress;
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
