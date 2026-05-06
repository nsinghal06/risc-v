`include "src/ext/b/types.svh"

module zbb(
    input [`PROCESSOR_BITNESS - 1:0] a
  , input [`PROCESSOR_BITNESS - 1:0] b
  , input ext__b__types::b_alu_control_t b_alu_control
  , output reg [`PROCESSOR_BITNESS - 1:0] out
  , output zeroE
  );

  import ext__b__types::*;

  localparam int XLEN = `PROCESSOR_BITNESS;
  localparam int COUNT_WIDTH = $clog2(XLEN + 1);

  function automatic logic [COUNT_WIDTH - 1:0] get_clz(input logic [XLEN - 1:0] val);
    get_clz = XLEN;
    for (int i=0; i < XLEN; i++) begin
      if (val[i]) get_clz = XLEN - 1 - i;
    end
  endfunction

  function automatic logic [COUNT_WIDTH - 1:0] get_ctz(input logic [XLEN - 1:0] val);
    get_ctz = XLEN;
    for (int i=XLEN - 1; i >= 0; i--) begin
      if (val[i]) get_ctz = i;
    end
  endfunction

  function automatic logic [COUNT_WIDTH - 1:0] get_cpop(input logic [XLEN - 1:0] val);
    get_cpop = 0;
    for (int i=0; i < XLEN; i++) begin
      if (val[i]) get_cpop++;
    end
  endfunction

  always_comb
    case (b_alu_control)
      B_ALU_CTRL__ANDN: out = a & ~b; //andn
      B_ALU_CTRL__ORN: out = a | ~b; //orn
      B_ALU_CTRL__XNOR: out = ~(a ^ b); //xnor
      B_ALU_CTRL__MIN: out = ($signed(a) < $signed(b) ? a : b); //min
      B_ALU_CTRL__MAX: out = ($signed(a) < $signed(b) ? b : a); //max
      B_ALU_CTRL__SEXTB: out = {{(XLEN - 8){a[7]}}, a[7:0]}; //sext.b (sign extend byte)
      B_ALU_CTRL__SEXTH: out = {{(XLEN - 16){a[15]}}, a[15:0]}; //sext.h (sign extend halfword)
      B_ALU_CTRL__ZEXTH: out = {{(XLEN - 16){1'b0}}, a[15:0]}; //zext.h (zero extend halfword)
      B_ALU_CTRL__CLZ: out = {{(XLEN - COUNT_WIDTH){1'b0}}, get_clz(a)}; //clz (count leading zeroes)
      B_ALU_CTRL__CTZ: out = {{(XLEN - COUNT_WIDTH){1'b0}}, get_ctz(a)}; //ctz (count trailing zeroes)
      B_ALU_CTRL__CPOP: out = {{(XLEN - COUNT_WIDTH){1'b0}}, get_cpop(a)}; //cpop (count population)
      default: out = '0; //other
    endcase

  assign zeroE = (out == 0);

endmodule
