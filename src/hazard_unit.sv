`include "src/headers/types.svh"
`include "src/packages/pkg_hazard_unit.svh"

import pkg_hazard_unit::forward_a_t;
import pkg_hazard_unit::forward_b_t;

module hazard_unit
  ( input  wire [4:0] Rs1E
  , input  wire [4:0] Rs2E
  , input  wire [4:0] RdM
  , input  wire [4:0] RdW
  , input  wire RegWriteM
  , input  wire RegWriteW
  , input  write_back_result_src_t ResultSrcE
  , input  wire [4:0] Rs1D
  , input  wire [4:0] Rs2D
  , input  wire [4:0] RdE
  , input  pc_src_t PCSrcE
  , output forward_a_t ForwardAE
  , output forward_b_t ForwardBE
  , output logic StallF
  , output logic StallD
  , output logic FlushD
  , output logic FlushE
  );

  import pkg_hazard_unit::*;

  wire ResultSrcE0;
  assign ResultSrcE0 = ResultSrcE[0];

  wire unused = &{ResultSrcE[$bits(write_back_result_src_t) -1:1]};

  // Forwarding
  always_comb
    if ((Rs1E == RdM) && RegWriteM && (Rs1E != 5'd0))
      ForwardAE = FORWARD_A__MEMORY_ALU_RESULT;
    else if ((Rs1E == RdW) && RegWriteW && (Rs1E != 5'd0))
      ForwardAE = FORWARD_A__WRITE_BACK_RESULT;
    else
      ForwardAE = FORWARD_A__EXECUTE_RD1;

  always_comb
    if ((Rs2E == RdM) && RegWriteM && (Rs2E != 5'd0))
      ForwardBE = FORWARD_B__MEMORY_ALU_RESULT;
    else if ((Rs2E == RdW) && RegWriteW && (Rs2E != 5'd0))
      ForwardBE = FORWARD_B__WRITE_BACK_RESULT;
    else
      ForwardBE = FORWARD_B__EXECUTE_RD2;

  logic lwStall;

  //Stall when a load hazard occurs
  assign lwStall = ResultSrcE0 && ((Rs1D == RdE) || (Rs2D == RdE)) && (RdE != 5'd0);
  assign StallF = lwStall;
  assign StallD = lwStall;

  //Flush when a control hazard occurs
  assign FlushD = PCSrcE;
  assign FlushE = lwStall || PCSrcE;

endmodule
