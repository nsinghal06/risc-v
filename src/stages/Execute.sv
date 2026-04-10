`include "src/headers/types.svh"
`include "src/interfaces/id_to_ex_if.svh"
`include "src/interfaces/ex_to_mem_if.svh"
`include "src/interfaces/ex_to_if_if.svh"

module Execute
  ( input id_to_ex_t ID_to_EX

  , input hazard_forward_a_t hz_forward_a
  , input hazard_forward_b_t hz_forward_b

  , input data_t wb_result
  , input data_t mem_alu_result

  , output ex_to_if_t EX_to_IF
  , output ex_to_mem_t EX_to_MEM
  );

  data_t alu_input_a;
  data_t alu_input_b;
  data_t safe_rd1; // hazard-safe version of rd1
  data_t safe_rd2; // hazard-safe version of rd2
  data_t alu_result;
  logic zero_flag;

  // ALU computation

  always_comb
    case (hz_forward_a)
      HAZARD_FORWARD_A__EXECUTE_RD1:       safe_rd1 = ID_to_EX.rd1;
      HAZARD_FORWARD_A__WRITE_BACK_RESULT: safe_rd1 = wb_result;
      HAZARD_FORWARD_A__MEMORY_ALU_RESULT: safe_rd1 = mem_alu_result;
      default:                             safe_rd1 = 'x;
    endcase

  always_comb
    case (hz_forward_b)
      HAZARD_FORWARD_B__EXECUTE_RD2:       safe_rd2 = ID_to_EX.rd2;
      HAZARD_FORWARD_B__WRITE_BACK_RESULT: safe_rd2 = wb_result;
      HAZARD_FORWARD_B__MEMORY_ALU_RESULT: safe_rd2 = mem_alu_result;
      default:                             safe_rd2 = 'x;
    endcase

  always_comb
    case (ID_to_EX.alu_src_a)
      ALU_SRC_A__RD1: alu_input_a = safe_rd1;
      ALU_SRC_A__PC:  alu_input_a = ID_to_EX.pc_cur;
      default:        alu_input_a = 'x;
    endcase

  always_comb
    case (ID_to_EX.ALUSrcB)
      ALU_SRC_B__RD2:     alu_input_b = safe_rd2;
      ALU_SRC_B__IMM_EXT: alu_input_b = ID_to_EX.imm_ext;
      default:            alu_input_b = 'x;
    endcase

  ALU alu
    ( .a              ( alu_input_a         )
    , .b              ( alu_input_b         )
    , .alu_control    ( ID_to_EX.ALUControl )
    , .out            ( alu_result          )
    , .zeroE          ( zero_flag           )
    );

  // branching logic

  typedef enum logic [2:0]
    { FUNCT3__BEQ  = 3'b000
    , FUNCT3__BNE  = 3'b001
    , FUNCT3__BLT  = 3'b100
    , FUNCT3__BGE  = 3'b101
    , FUNCT3__BLTU = 3'b110
    , FUNCT3__BGEU = 3'b111
    } funct3_branch_t;

  logic JumpE;
  logic BranchE;
  pc_src_t pc_src;
  addr_t pc_target;

  assign JumpE = ID_to_EX.Jump;
  assign BranchE = ID_to_EX.Branch;

  always_comb
    case (ID_to_EX.pc_target_kind)
      PC_TARGET_KIND__RELATIVE: pc_target = ID_to_EX.pc_cur + ID_to_EX.imm_ext;

      // here the control FSM arranges for the computation to have been done via the ALU, i.e. to
      // add the register value to imm_ext to abvoid building another adder
      PC_TARGET_KIND__ABSOLUTE: pc_target = alu_result;
      default:                  pc_target = addr_t'('x);
    endcase

  logic branch_condition_met;
  always_comb
    case (ID_to_EX.funct3)
      FUNCT3__BEQ:               branch_condition_met =  zero_flag;
      FUNCT3__BNE:               branch_condition_met = ~zero_flag;
      FUNCT3__BLT, FUNCT3__BLTU: branch_condition_met =  alu_result[0];
      FUNCT3__BGE, FUNCT3__BGEU: branch_condition_met = ~alu_result[0];
      default:                   branch_condition_met =  zero_flag;
    endcase

  logic should_branch;
  assign should_branch = JumpE | (BranchE & branch_condition_met);

  assign pc_src = should_branch ? PC_SRC__ALU_RESULT : PC_SRC__INCREMENT;

  assign EX_to_MEM.ResultSrc        = ID_to_EX.ResultSrc;
  // assign EX_to_MEM.AdrSrc = ID_to_EX.AdrSrc;
  // assign EX_to_MEM.pc_src = ID_to_EX.pc_src;
  // assign EX_to_MEM.IRWrite = ID_to_EX.IRWrite;
  // assign EX_to_MEM.MemWriteByteAddress = ID_to_EX.MemWriteByteAddress;
  assign EX_to_MEM.MemWrite         = ID_to_EX.MemWrite;
  assign EX_to_MEM.RegWrite         = ID_to_EX.RegWrite;
  assign EX_to_MEM.funct3           = ID_to_EX.funct3;
  assign EX_to_MEM.WriteDataE       = safe_rd2;
  // assign EX_to_MEM.funct3           = ID_to_EX.funct3;
  // assign EX_to_MEM.rd2 <= ID_to_EX.rd2;
  assign EX_to_MEM.rd               = ID_to_EX.rd;
  assign EX_to_MEM.alu_result       = alu_result;
  assign EX_to_MEM.pc_cur           = ID_to_EX.pc_cur;
  assign EX_to_MEM.pc_plus_4        = ID_to_EX.pc_plus_4;
  assign EX_to_IF.imm_ext           = ID_to_EX.imm_ext;
  assign EX_to_IF.pc_src            = pc_src;
  assign EX_to_IF.pc_target         = pc_target;
  assign EX_to_IF.pc_old            = ID_to_EX.pc_cur;

  wire unused = &{ID_to_EX.rs1, ID_to_EX.rs2};
endmodule
