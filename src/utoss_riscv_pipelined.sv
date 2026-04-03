`include "src/headers/types.svh"
`include "src/interfaces/if_to_id_if.svh"
`include "src/interfaces/id_to_ex_if.svh"
`include "src/interfaces/ex_to_mem_if.svh"
`include "src/interfaces/ex_to_if_if.svh"
`include "src/interfaces/mem_to_wb_if.svh"

// pipelined implementation of our core
module utoss_riscv_pipelined
  ( input wire clk
  , input wire reset

  // instruction memory interface begin
  , output addr_t       memory_instr__address
  , output data_t       memory_instr__write_data
  , output logic  [3:0] memory_instr__write_enable
  , input  data_t       memory_instr__read_data
  // instruction memory interface end

  // data memory interface begin
  , output addr_t       memory_data__address
  , output data_t       memory_data__write_data
  , output logic  [3:0] memory_data__write_enable
  , input  data_t       memory_data__read_data
  // data memory interface end
  );

  // common declarations begin

  if_to_id_t  if_to_id_out;
  if_to_id_t  if_to_id_reg;

  id_to_ex_t  id_to_ex_out;
  id_to_ex_t  id_to_ex_reg;

  ex_to_if_t  ex_to_if_out;
  ex_to_mem_t ex_to_mem_out;
  ex_to_mem_t ex_to_mem_reg;

  mem_to_wb_t mem_to_wb_out;
  mem_to_wb_t mem_to_wb_reg;

  data_t      wb_result;
  logic [4:0] wb_rd;

  // common declarations end

  // fetch stage start (@thatlittlegit)

  fetch_stage u_fetch_stage
    ( .IF_to_ID ( if_to_id_out )
    , .EX_to_IF ( ex_to_if_out )

    , .clk    ( clk    )
    , .reset  ( reset  )
    , .StallF ( StallF )

    , .imem__address ( memory_instr__address   )
    , .imem__data    ( memory_instr__read_data )
    );

  assign memory_instr__write_data = data_t'(0);
  assign memory_instr__write_enable = 4'b0;

  // fetch stage end

  // decode stage begin (@marwannismail)

  // we need to flush one cycle later than we discover the control hazard; this is due to
  // synchronous memory making the instruction available one cycle later than with async memory
  reg flushD_lag;
  always_ff @ (posedge clk) flushD_lag <= FlushD;

  always_ff @ (posedge clk)
    if (reset) if_to_id_reg <= '0;
    else if (flushD_lag) if_to_id_reg <= '0;
    else if (!StallD) if_to_id_reg <= if_to_id_out;

  wire [4:0] id_rs1, id_rs2;

  Decode decode
    ( .IF_to_ID    ( if_to_id_reg               )
    , .clk         ( clk                        )
    , .reset       ( reset                      )
    , .data        ( wb_result                  )
    , .rd_wb       ( wb_rd                      )
    , .RegWriteW   ( mem_to_wb_reg.RegWriteW    )
    , .ID_to_EX    ( id_to_ex_out               )

    , .rs1 ( id_rs1 )
    , .rs2 ( id_rs2 )
    );

  // decode stage end

  // execute stage begin (@MSh-786 and tandr3w)

  // we need to flush both the current data in the execute pipeline and the next one that will be
  // passed from the decode on the next cycle
  reg flushE_lag;
  always_ff @ (posedge clk) flushE_lag <= FlushE;

  always_ff @ (posedge clk)
    if (reset) id_to_ex_reg <= '0;
    else if (FlushE || flushE_lag) id_to_ex_reg <= '0;
    else       id_to_ex_reg <= id_to_ex_out;

  Execute execute
    ( .ID_to_EX ( id_to_ex_reg  )

    , .hz_forward_a ( hz_forward_a )
    , .hz_forward_b ( hz_forward_b )

    , .wb_result      ( wb_result                )
    , .mem_alu_result ( ex_to_mem_reg.alu_result )

    , .EX_to_MEM  ( ex_to_mem_out )
    , .EX_to_IF   ( ex_to_if_out  )
    );

  // execute stage end

  // memory stage begin (@Invisipac)

  always_ff @ (posedge clk)
    if (reset) ex_to_mem_reg <= '0;
    else       ex_to_mem_reg <= ex_to_mem_out;

  mem_stage memory_stage
  ( .EX_to_MEM        ( ex_to_mem_reg )
  , .dataFromMemory   (memory_data__read_data)
  , .dataToMemory     (memory_data__write_data)
  , .memWriteEnable (memory_data__write_enable) // TODO: Is this required?
  , .mem_address      ( memory_data__address )
  , .MEM_to_WB        (mem_to_wb_out)
  );

  // memory stage end

  // writeback stage begin (@TheDeepestSpace)

  always_ff @ (posedge clk)
    if (reset) mem_to_wb_reg <= '0;
    else       mem_to_wb_reg <= mem_to_wb_out;

  write_back wb
    ( .from_memory ( mem_to_wb_reg )
    , .dataFromMemory (memory_data__read_data)
    , .result      ( wb_result     )
    , .rd          ( wb_rd         )
    );

  // writeback stage end

  // hazard module begin (@DanielTaoHuang123)

  pkg_hazard_unit::forward_a_t hz_forward_a;
  pkg_hazard_unit::forward_b_t hz_forward_b;
  logic StallF, StallD, FlushD, FlushE;

  hazard_unit u_hazard_unit
    ( .Rs1D       ( id_rs1                  )
    , .Rs2D       ( id_rs2                  )
    , .Rs1E       ( id_to_ex_reg.rs1        )
    , .Rs2E       ( id_to_ex_reg.rs2        )
    , .RdM        ( ex_to_mem_reg.rd        )
    , .RdW        ( mem_to_wb_reg.rd        )
    , .RdE        ( id_to_ex_reg.rd         )
    , .RegWriteM  ( ex_to_mem_reg.RegWrite  )
    , .RegWriteW  ( mem_to_wb_reg.RegWriteW )
    , .ResultSrcE ( id_to_ex_reg.ResultSrc  )
    , .PCSrcE     ( ex_to_if_out.pc_src     )

    , .ForwardAE ( hz_forward_a )
    , .ForwardBE ( hz_forward_b )
    , .StallF    ( StallF       )
    , .StallD    ( StallD       )
    , .FlushD    ( FlushD       )
    , .FlushE    ( FlushE       )
    );

  // hazard module end


endmodule
