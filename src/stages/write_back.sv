`default_nettype none

`include "src/interfaces/mem_to_wb_if.svh"

module write_back
  ( input mem_to_wb_t from_memory
  , input data_t dataFromMemory
  , input ex_to_mem_t EX_to_MEM
  , output var data_t      result
  , output var logic [4:0] rd
  );
/////

  data_t WriteDataM;
  data_t ALUResultM;
  // logic [4:0] RdM;
  // logic MemWrite;

  // logic [3:0] MemWriteByteAddress;

  assign WriteDataM = EX_to_MEM.WriteDataE;
  assign ALUResultM = from_memory.alu_result;
  // assign RdM = EX_to_MEM.rd;
  // assign MemWrite = EX_to_MEM.MemWrite;

  logic [3:0] tempMemWriteByteAddress;
  data_t tempOutput;
  data_t memResult;

 MemoryLoader memory_loader
    ( .memory_data         ( dataFromMemory          )
    , .memory_address      ( ALUResultM              )
    , .funct3              ( from_memory.funct3        )
    , .dataB               ( WriteDataM              )
    , .mem_load_result     (  memResult)//MEM_to_WB.read_data     )
    , .MemWriteByteAddress ( tempMemWriteByteAddress )
    , .__tmp_MemData       ( tempOutput            )
    );

////

  assign rd = from_memory.rd;

  // TODO: `REULST_SRC__ALU_OUT` is no longer covered, revisit during integration
  always_comb
    case (from_memory.cfsm__result_src)
      WRITE_BACK_RESULT_SRC__ALU_RESULT: result = from_memory.alu_result;
      WRITE_BACK_RESULT_SRC__READ_DATA:  result = memResult;//from_memory.read_data;
      WRITE_BACK_RESULT_SRC__PC_PLUS_4:  result = from_memory.pc_cur; // TODO: address
      default:                           result = 32'hxxxxxxxx;
    endcase

  wire unused = &{from_memory.RegWriteW
  , from_memory.pc_plus_4
  , EX_to_MEM.WriteDataE
  , EX_to_MEM.rd
  , EX_to_MEM.MemWrite
  , tempOutput
  , tempMemWriteByteAddress /* remove/rename? */};

  wire _unused_ex_to_mem = &{1'b0, EX_to_MEM};
  wire _unused_from_mem = &{1'b0, from_memory};


endmodule
