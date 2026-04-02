`include "src/headers/types.svh"
`include "src/packages/pkg_hazard_unit.svh"

import pkg_hazard_unit::forward_a_t;
import pkg_hazard_unit::forward_b_t;

module hazard_unit
  ( input  wire clk
  , input  wire [4:0] Rs1E
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
  , output logic lwStall
  , output logic StallF
  , output logic StallD
  , output logic FlushD
  , output logic FlushE
  );

  import pkg_hazard_unit::*;

  wire ResultSrcE0;
  assign ResultSrcE0 = ResultSrcE[0];

  // Forwarding
  always_comb begin
    if ((Rs1E == RdM) && RegWriteM && (Rs1E != 5'd0))
      ForwardAE = FORWARD_A__MEMORY_ALU_RESULT;
    else if ((Rs1E == RdW) && RegWriteW && (Rs1E != 5'd0))
      ForwardAE = FORWARD_A__WRITE_BACK_RESULT;
    else
      ForwardAE = FORWARD_A__EXECUTE_RD1;
  end

  always_comb begin
    if ((Rs2E == RdM) && RegWriteM && (Rs2E != 5'd0))
      ForwardBE = FORWARD_B__MEMORY_ALU_RESULT;
    else if ((Rs2E == RdW) && RegWriteW && (Rs2E != 5'd0))
      ForwardBE = FORWARD_B__WRITE_BACK_RESULT;
    else
      ForwardBE = FORWARD_B__EXECUTE_RD2;
  end

  //Stall when a load hazard occurs
  always_comb begin
    lwStall = ResultSrcE0 && ((Rs1D == RdE) || (Rs2D == RdE)) && (RdE != 5'd0);

    StallF = lwStall;
    StallD = lwStall;
  end

  //Flush when a control hazard occurs
  always_comb begin
    FlushD = PCSrcE;
    FlushE = lwStall || PCSrcE;
  end

endmodule
