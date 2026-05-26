`default_nettype none
module registerFile (
	Addr1,
	Addr2,
	Addr3,
	clk,
	regWrite,
	dataIn,
	reset,
	baseAddr,
	writeData,
	dbg_regs
);
	input [4:0] Addr1;
	input [4:0] Addr2;
	input [4:0] Addr3;
	input clk;
	input regWrite;
	input [31:0] dataIn;
	input reset;
	output wire [31:0] baseAddr;
	output wire [31:0] writeData;
	output reg [1023:0] dbg_regs;
	reg [31:0] RFMem [0:31];
	assign baseAddr = (Addr1 == 5'd0 ? 32'd0 : RFMem[Addr1]);
	assign writeData = (Addr2 == 5'd0 ? 32'd0 : RFMem[Addr2]);
	always @(*) begin
		dbg_regs[992+:32] = 32'd0;
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 1; i < 32; i = i + 1)
				dbg_regs[(31 - i) * 32+:32] = RFMem[i];
		end
	end
	always @(posedge clk)
		if (reset) begin : sv2v_autoblock_2
			integer k;
			for (k = 0; k < 32; k = k + 1)
				RFMem[k] <= 32'b00000000000000000000000000000000;
		end
		else if (regWrite && (Addr3 != 0))
			RFMem[Addr3] <= dataIn;
endmodule
