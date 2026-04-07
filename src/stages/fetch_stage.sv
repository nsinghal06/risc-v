`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/interfaces/if_to_id_if.svh"
`include "src/interfaces/ex_to_if_if.svh"

module fetch_stage
  ( output if_to_id_t IF_to_ID
  , input ex_to_if_t  EX_to_IF

  , input wire clk
  , input wire reset
  , input wire StallF

  , output addr_t imem__address
  , input data_t imem__data
);
  // The use of distinct registers for prev, cur and next PC requires some explanation. Below is the
  // timing diagram of the instruction retireval and subsequenct passing of the relevant data to
  // decode stage. Importantly, notice the one clock-cycle lag between PC placed on the `imem
  // address` line and the instruction on the `imem data`, this is due to us using synchronous
  // memory for instructions (and data for that matter).
  //
  // When it comes to decode stage, it expects instruction to be passed along with the PC value that
  // corresponds to it. Therefore since the instruction "lags" by one cycle, hence the PC value has
  // to also lag by one cycle, and therefore we provide `pc_prev` to ID's `pc_cur`.
  //
  // fetch timeline:
  //                                     module snapshot
  //                                   +----------------+
  // imem address  : < prev PC       > | < cur PC     > | < next PC    > | < 2x next PC >
  // imem data     : < 2x prev instr > | < prev instr > | < cur instr  > | < next instr >
  // if->id.pc_cur : < 2x prev PC    > | < prev PC    > | < cur PC     > | < next PC    >
  //                                   |                |
  // decode timeline:                  |                |
  //                                   |                |
  // if->id.pc_cur :                   | < prev PC    > | < cur PC    > | < next PC    >
  // if->id.instr  :                   | < prev instr > | < cur instr > | < next instr >
  //                                   +----------------+

  addr_t pc_prev;
  addr_t pc_cur;
  addr_t pc_next;

  always_comb
    case (EX_to_IF.pc_src)
      PC_SRC__INCREMENT:  pc_next = pc_cur + 32'h4;
      PC_SRC__ALU_RESULT: pc_next = EX_to_IF.pc_target;
      default:            pc_next = 32'hx;
    endcase

  always @ (posedge clk)
    if (!StallF) pc_cur <= reset ? 0 : pc_next;

  always @ (posedge clk)
    if (!StallF) pc_prev <= reset ? 0 : pc_cur;

  assign imem__address = pc_cur;
  assign IF_to_ID.instruction = imem__data;
  assign IF_to_ID.pc_cur = pc_prev;
  assign IF_to_ID.pc_plus_4 = pc_prev + 32'h4; // TODO: revisit

  // TODO: probably can just get rid of those altogether
  wire unused = &{EX_to_IF.pc_old, EX_to_IF.imm_ext};
endmodule
