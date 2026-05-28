`include "src/headers/params.svh"
`include "src/headers/types.svh"
`include "src/timescale.svh"

module Compressed_Decode
  ( input wire [15:0] instr_c // Compressed input instruction
  , output reg [31:0] instr_out // Expanded instruction
  , output reg is_illegal // Illegal or not implemented
  );

  wire [1:0] quadrant = instr_c[1:0];
  wire [2:0] funct3   = instr_c[15:13];

  // Common locations of registers in instruction format
  wire [4:0] rd_prime  = {2'b01, instr_c[4:2]};
  wire [4:0] rs1_prime = {2'b01, instr_c[9:7]};
  wire [4:0] rs2_prime = {2'b01, instr_c[4:2]};
  wire [4:0] rd_full  = instr_c[11:7];
  wire [4:0] rs1_full = instr_c[11:7];
  wire [4:0] rs2_full = instr_c[6:2];
  wire [4:0] shamt = instr_c[6:2];

  // Pre-compute immediates for each instruction format
  wire [11:0] ciw_imm     = {2'b00, instr_c[10:7], instr_c[12:11], instr_c[5], instr_c[6], 2'b00};
  wire [11:0] cl_cs_imm   = {5'b00000, instr_c[5], instr_c[12:10], instr_c[6], 2'b00};
  wire [11:0] ci_imm      = {{6{instr_c[12]}}, instr_c[12], instr_c[6:2]};
  wire [11:0] ci_sp_imm   = {{3{instr_c[12]}}, instr_c[4:3], instr_c[5], instr_c[2], instr_c[6], 4'b0000};
  wire [19:0] ci_lui_imm  = {{14{instr_c[12]}}, instr_c[12], instr_c[6:2]};
  wire [20:0] cj_imm      = {{9{instr_c[12]}}, instr_c[12], instr_c[8], instr_c[10:9], instr_c[6], instr_c[7], instr_c[2], instr_c[11], instr_c[5:3], 1'b0};
  wire [12:0] cb_imm      = {{4{instr_c[12]}}, instr_c[12], instr_c[6:5], instr_c[2], instr_c[11:10], instr_c[4:3], 1'b0};
  wire [11:0] ci_lwsp_imm = {4'b0000, instr_c[3:2], instr_c[12], instr_c[6:4], 2'b00};
  wire [11:0] css_imm     = {4'b0000, instr_c[8:7], instr_c[12:9], 2'b00};

  localparam bit [31:0] NOP = 32'h00000013;

  // Note: C.FLW, C.FSW, C.FLD, C.FSD, C.FLWSP, C.FLDSP, C.FSWSP, C.FSDSP should be added alongside future F/D extension support.
  always @(*) begin
    instr_out = NOP;
    is_illegal = 1'b0;

    case (quadrant) // Opcode
      2'b11: instr_out = {16'b0, instr_c}; // Not a compressed instruction, just pass through (should not actually happen i think?)

      2'b00: begin // Quadrant 0
        case (funct3)
          3'b000: begin
            instr_out = {ciw_imm, 5'd2, 3'b000, rd_prime, IType_logic}; // C.ADDI4SPN
            if (ciw_imm == 12'b0) is_illegal = 1'b1;
          end
          3'b010: instr_out = {cl_cs_imm, rs1_prime, 3'b010, rd_prime, IType_load}; // C.LW
          3'b110: instr_out = {cl_cs_imm[11:5], rs2_prime, rs1_prime, 3'b010, cl_cs_imm[4:0], SType}; // C.SW
          default: is_illegal = 1'b1;
        endcase
      end

      2'b01: begin // Quadrant 1
        case (funct3)
          3'b000: instr_out = {ci_imm, rd_full, 3'b000, rd_full, IType_logic}; // C.ADDI
          // TODO C.JAL does not expand exactly to a base RVI instruction since the link address should be pc+2 instead of pc+4
          // Need to add support for offset of 2 bytes and e.g. preserve an is_compressed wire
          3'b001: instr_out = {cj_imm[20], cj_imm[10:1], cj_imm[11], cj_imm[19:12], 5'd1, JType}; // C.JAL
          3'b010: instr_out = {ci_imm, 5'd0, 3'b000, rd_full, IType_logic}; // C.LI
          3'b011: begin
            case (instr_c[11:7])
              5'd2: begin
                instr_out = {ci_sp_imm, 5'd2, 3'b000, 5'd2, IType_logic}; // C.ADDI16SP
                if (ci_sp_imm == 12'b0) is_illegal = 1'b1;
              end
              default: begin
                instr_out = {ci_lui_imm, rd_full, UType_lui}; // C.LUI
                if (ci_lui_imm == 20'b0 ) is_illegal = 1'b1;
              end
            endcase
          end
          3'b100: begin
            case (instr_c[11:10])
              2'b00: begin
                instr_out = {7'h00, instr_c[6:2], rs1_prime, 3'b101, rs1_prime, IType_logic}; // C.SRLI
                if (instr_c[12]) is_illegal = 1'b1;
              end
              2'b01: begin
                instr_out = {7'h20, instr_c[6:2], rs1_prime, 3'b101, rs1_prime, IType_logic}; // C.SRAI
                if (instr_c[12]) is_illegal = 1'b1;
              end
              2'b10: instr_out = {ci_imm, rs1_prime, 3'b111, rs1_prime, IType_logic}; // C.ANDI
              2'b11: begin
                if (instr_c[12]) is_illegal = 1'b1;
                case (instr_c[6:5])
                  2'b00: instr_out = {7'h20, rs2_prime, rs1_prime, 3'b000, rs1_prime, RType}; // C.SUB
                  2'b01: instr_out = {7'h00, rs2_prime, rs1_prime, 3'b100, rs1_prime, RType}; // C.XOR
                  2'b10: instr_out = {7'h00, rs2_prime, rs1_prime, 3'b110, rs1_prime, RType}; // C.OR
                  2'b11: instr_out = {7'h00, rs2_prime, rs1_prime, 3'b111, rs1_prime, RType}; // C.AND
                endcase
              end
              default: instr_out = NOP;
            endcase
          end
          3'b101: instr_out = {cj_imm[20], cj_imm[10:1], cj_imm[11], cj_imm[19:12], 5'd0, JType}; // C.J
          3'b110: instr_out = {cb_imm[12], cb_imm[10:5], 5'd0, rs1_prime, 3'b000, cb_imm[4:1], cb_imm[11], BType}; // C.BEQZ
          3'b111: instr_out = {cb_imm[12], cb_imm[10:5], 5'd0, rs1_prime, 3'b001, cb_imm[4:1], cb_imm[11], BType}; // C.BNEZ
        endcase
      end

      2'b10: begin // Quadrant 2
        case (funct3)
          3'b000: begin
            instr_out = {7'h00, shamt, rd_full, 3'b001, rd_full, IType_logic}; // C.SLLI
            if (instr_c[12]) is_illegal = 1'b1;
          end
          3'b010: begin
            instr_out = {ci_lwsp_imm, 5'd2, 3'b010, rd_full, IType_load}; // C.LWSP
            if (rd_full == 5'd0) is_illegal = 1'b1;
          end
          3'b100: begin
            case ({instr_c[12], instr_c[11:7] != 5'd0, instr_c[6:2] != 5'd0})
              3'b010:         instr_out = {12'd0, rs1_full, 3'h0, 5'd0, IType_jalr}; // C.JR
              3'b011, 3'b001: instr_out = {7'h00, rs2_full, 5'd0, 3'h0, rd_full, RType}; // C.MV
              3'b100:         instr_out = {12'h001, 5'd0, 3'h0, 5'd0, SYSTEM}; // C.EBREAK
              3'b110:         instr_out = {12'd0, rs1_full, 3'h0, 5'd1, IType_jalr}; // C.JALR (TODO see note on C.JAL)
              3'b111, 3'b101: instr_out = {7'h00, rs2_full, rd_full, 3'h0, rd_full, RType}; // C.ADD
              default: is_illegal = 1'b1;
            endcase
          end
          3'b110: instr_out = {css_imm[11:5], rs2_full, 5'd2, 3'b010, css_imm[4:0], SType}; // C.SWSP
          default: is_illegal = 1'b1;
        endcase
      end
    endcase
  end

endmodule
