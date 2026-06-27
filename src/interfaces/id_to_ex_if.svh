`ifndef ID_TO_EX_IF__HG
`define ID_TO_EX_IF__HG

`include "src/headers/params.svh"
`include "src/headers/types.svh"

typedef struct packed {
  alu_src_a_t   alu_src_a;
  alu_src_b_t   alu_src_b;
  result_src_t  result_src;
  addr_t        pc_cur;
  addr_t        pc_plus_4;
  logic         branch;
  logic         jump;
  logic         pc_target_kind;
  logic         mem_write;
  logic         reg_write;
  alu_control_t alu_control;
  ext__b__types::b_alu_control_t b_alu_control; //NEW
  logic [2:0]   funct3;
  data_t        rd1;
  data_t        rd2;
  logic [4:0]   rd;
  logic [4:0]   rs1;
  logic [4:0]   rs2;
  imm_t         imm_ext;
} id_to_ex_t;

`endif