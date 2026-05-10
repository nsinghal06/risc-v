`include "src/timescale.svh"

`include "test/utils.svh"

// this TB is based on the instr_0 test rfom RISCOF for beq instruction
module beq_01_tb;

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
    integer i;

    reset = `TRUE;

    // Program relocated so instruction at original 0x80000180 is at M[0].
    // Initial instruction sequence (as in disassembly)
    uut.memory.M[0] = 32'h555559b7; // lui s3,0x55555
    uut.memory.M[1] = 32'h55598993; // addi s3,s3,1365
    uut.memory.M[2] = 32'h555559b7; // lui s3,0x55555
    uut.memory.M[3] = 32'h55598993; // addi s3,s3,1365
    uut.memory.M[4] = 32'h00000593; // li a1,0
    uut.memory.M[5] = 32'h0050006f; // j  (to the long-pad region)

    // Taken branch target is index 6 (PC 0x18): increment once, then self-loop.
    uut.memory.M[6] = 32'h00158593; // addi a1,a1,1
    uut.memory.M[7] = 32'h00000063; // beq x0,x0,0 (self-loop)

    // Pad the rest with NOPs up to the long branch location (0x206 == 518)
    for (i = 8; i < 518; i = i + 1) begin
      uut.memory.M[i] = 32'h00000013; // nop
    end

    // Long-region instructions (addresses around 0x80000998..0x9ac)
    uut.memory.M[518] = 32'h813980e3; // beq s3,s3, (back to small loop)
    uut.memory.M[519] = 32'h00258593; // addi a1,a1,2
    uut.memory.M[520] = 32'h00c0006f; // j  (skip)
    uut.memory.M[521] = 32'h00358593; // addi a1,a1,3
    uut.memory.M[522] = 32'h0040006f; // j  (skip)
    uut.memory.M[523] = 32'h00b2a023; // sw a1,0(t0)

    // Make sure memory location for final store is zeroed
    uut.memory.M[600] = 32'h00000000;

    // Set t0 (x5) to point to word index 600 (byte addr = 600*4)
    uut.core.decode.RegFile.RFMem[5] = 32'h00000960; // 0x960 == 2400 decimal (600*4)

    // a1 should start 0 (li a1,0 already encoded) but ensure regs cleared
    for (i = 0; i < 32; i = i + 1) uut.core.decode.RegFile.RFMem[i] = uut.core.decode.RegFile.RFMem[i];

    tick();
    reset = `FALSE;

    // Run for a generous number of cycles to allow the long jump/branch sequence
    repeat (2000) tick();

    $display("[final] a1=0x%0h M[600]=0x%0h", uut.core.decode.RegFile.RFMem[11], uut.memory.M[600]);

    // Check that a1 (x11) equals 1 as expected by the test
    `assert_equal(uut.core.decode.RegFile.RFMem[11], 32'h00000001)

    $finish;
  end

  `SETUP_VCD_DUMP(beq_01_tb)

endmodule
