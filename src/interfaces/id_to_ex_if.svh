`ifndef ID_TO_EX_IF__HG
`define ID_TO_EX_IF__HG

`include "src/headers/params.svh"
`include "src/headers/types.svh"

typedef struct packed {
  alu_src_a_t alu_src_a;
  alu_src_b_t ALUSrcB;

  write_back_result_src_t ResultSrc;
  addr_t                  pc_prev;
  addr_t                  pc_cur;
  addr_t                  pc_plus_4;
  logic                   Branch;
  logic                   Jump;
  logic                   pc_target_kind;
  logic                   MemWrite;
  logic                   RegWrite;
  logic [3:0]             ALUControl;
  logic [2:0]             funct3;
  data_t                  rd1;
  data_t                  rd2;
  logic [4:0]             rd;
  logic [4:0]             rs1;
  logic [4:0]             rs2;
  imm_t                   imm_ext;
} id_to_ex_t;

`endif
