`ifndef PKG_EXECUTE_STAGE_VH
`define PKG_EXECUTE_STAGE_VH

package pkg_execute_stage;

  typedef enum logic [0:0]
    { ALU_SRC_A__RD1 = 1'b0
    , ALU_SRC_A__PC  = 1'b1
    } alu_src_a_t;

  typedef enum logic [0:0]
    { ALU_SRC_B__RD2     = 1'b0
    , ALU_SRC_B__IMM_EXT = 1'b1
    } alu_src_b_t;

endpackage

`endif
