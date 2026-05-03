`include "src/ext/b/types.svh"

module zbb(
    input [31:0] a
  , input [31:0] b
  , input ext__b__types::b_alu_control_t b_alu_control
  , output reg [31:0] out
  , output zeroE
  );

  import ext__b__types::*;

  function automatic logic [5:0] get_clz(input logic [31:0] val);
      get_clz = 6'd32;
      for (int i=0; i < 32; i++) begin
        if (val[i]) get_clz = 6'(31 - i);
      end
  endfunction

  function automatic logic [5:0] get_ctz(input logic [31:0] val);
    get_ctz = 6'd32;
    for (int i=31; i >= 0; i--) begin
      if (val[i]) get_ctz = 6'(i);
    end
  endfunction

  function automatic logic [5:0] get_cpop(input logic [31:0] val);
    get_cpop = 6'd0;
    for (int i=0; i < 32; i++) begin
      if (val[i]) get_cpop += 6'd1;
    end
  endfunction

  always_comb
    case (b_alu_control)
      B_ALU_CTRL__ANDN: out = a & ~b; //andn
      B_ALU_CTRL__ORN: out = a | ~b; //orn
      B_ALU_CTRL__XNOR: out = ~(a ^ b); //xnor
      B_ALU_CTRL__MIN: out = ($signed(a) < $signed(b) ? a : b); //min
      B_ALU_CTRL__MAX: out = ($signed(a) < $signed(b) ? b : a); //max
      B_ALU_CTRL__SEXTB: out = { {24{a[7]}}, a[7:0]}; //sext.b (sign extend byte)
      B_ALU_CTRL__SEXTH: out = { {16{a[15]}}, a[15:0]}; //sext.h (sign extend halfword)
      B_ALU_CTRL__ZEXTH: out = {16'b0, a[15:0]}; //zext.h (zero extend halfword)
      B_ALU_CTRL__CLZ: out = {26'b0, get_clz(a)}; //clz (count leading zeroes)
      B_ALU_CTRL__CTZ: out = {26'b0, get_ctz(a)}; //ctz (count trailing zeroes)
      B_ALU_CTRL__CPOP: out = {26'b0, get_cpop(a)}; //cpop (count population)
      default: out = 32'd0; //other
    endcase

  assign zeroE = (out == 0);

endmodule
