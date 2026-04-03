`include "src/packages/pkg_execute_stage.svh"

// TODO: review all the signal assignments
/* verilator lint_off DECLFILENAME */
module control_fsm_pipelined
/* verilator lint_off DECLFILENAME */
  ( input opcode_t opcode

  , output var logic               reg_write
  , output write_back_result_src_t result_src
  , output var logic               mem_write
  , output var logic               jump
  , output var logic               branch
  , output pc_target_kind_t        pc_target_kind

  , output pkg_execute_stage::alu_src_a_t alu_src_a
  , output pkg_execute_stage::alu_src_b_t alu_src_b
  );

  always_comb
    reg_write = opcode inside {JType, RType, IType_load, IType_logic, IType_jalr, UType_auipc, UType_lui};

  always_comb
    case (opcode)
      RType, IType_logic:
        result_src = WRITE_BACK_RESULT_SRC__ALU_RESULT;
      IType_load:
        result_src = WRITE_BACK_RESULT_SRC__READ_DATA;
      JType, IType_jalr:
        result_src = WRITE_BACK_RESULT_SRC__PC_PLUS_4;
      default:
        result_src = write_back_result_src_t'('0);
    endcase

  always_comb mem_write = opcode == SType;

  always_comb jump = opcode inside {JType, IType_jalr};

  always_comb branch = opcode == BType;

  always_comb
    case (opcode)
      JType:      pc_target_kind = PC_TARGET_KIND__RELATIVE;
      IType_jalr: pc_target_kind = PC_TARGET_KIND__ABSOLUTE;
      default:    pc_target_kind = pc_target_kind_t'('x);
    endcase

  always_comb
    case (opcode)
      RType, IType_logic, IType_load, IType_jalr, SType, BType, UType_lui /* TODO: triple check lui */:
        alu_src_a = pkg_execute_stage::ALU_SRC_A__RD1;
      UType_auipc, JType:
        alu_src_a = pkg_execute_stage::ALU_SRC_A__PC;
      default:
        alu_src_a = pkg_execute_stage::alu_src_a_t'('x);
    endcase

  always_comb
    case (opcode)
      RType, BType:
        alu_src_b = pkg_execute_stage::ALU_SRC_B__RD2;
      UType_auipc, UType_lui, IType_logic, IType_jalr, IType_load, SType:
        alu_src_b = pkg_execute_stage::ALU_SRC_B__IMM_EXT;
      default:
        alu_src_b = pkg_execute_stage::alu_src_b_t'('x);
    endcase
endmodule
