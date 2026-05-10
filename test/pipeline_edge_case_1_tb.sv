`include "src/timescale.svh"

`include "test/utils.svh"

/* verilator lint_off IMPORTSTAR */
import pkg_control_fsm::*;

module pipeline_edge_case_1_tb;

  reg clk;
  reg reset;

  top uut
    ( .clk   ( clk   )
    , .reset ( reset )
    );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  task tick;
    @(posedge clk); #1;
  endtask

  initial begin
    bit saw_flush_e = 0;

    reset = `TRUE;

    // lw x1, 0(x2)
    // addi x1, x1, 5
    // nop
    // nop
    // nop
    // nop
    uut.memory.M[0] = 32'h00012083;
    uut.memory.M[1] = 32'h00508093;
    uut.memory.M[2] = 32'h00000013;
    uut.memory.M[3] = 32'h00000013;
    uut.memory.M[4] = 32'h00000013;
    uut.memory.M[5] = 32'h00000013;

    // Data loaded by the lw above: 7 + 5 = 12.
    uut.memory.M[40] = 32'h00000007;

    // x2 points at address 0xa0.
    uut.core.decode.RegFile.RFMem[2] = 32'ha0;
    uut.core.decode.RegFile.RFMem[1] = 32'hdeadbeef;

    tick();
    reset = `FALSE;

    repeat (100) begin
      tick();

      if (uut.core.FlushE) begin
        saw_flush_e = 1;
        `assert_equal(uut.core.StallF, 1'b1)
        `assert_equal(uut.core.StallD, 1'b1)
      end
    end

    assert (saw_flush_e)
      else $fatal(1, "Expected FlushE to assert for the load-use hazard");

    `assert_equal(uut.core.decode.RegFile.RFMem[1], 32'd12)
    `assert_equal(uut.core.decode.RegFile.RFMem[2], 32'ha0)

    $finish;
  end

  `SETUP_VCD_DUMP(pipeline_edge_case_1_tb)

/* verilator lint_on IMPORTSTAR */
endmodule
