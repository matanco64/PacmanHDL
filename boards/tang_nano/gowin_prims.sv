// Interface of the Gowin rPLL primitive, so the SystemVerilog frontend can
// check the instance; synth_gowin maps it onto the real hard block.
(* blackbox *)
module rPLL #(
  parameter FCLKIN           = "100.0",
  parameter DEVICE           = "GW1N-1",
  parameter DYN_IDIV_SEL     = "false",
  parameter IDIV_SEL         = 0,
  parameter DYN_FBDIV_SEL    = "false",
  parameter FBDIV_SEL        = 0,
  parameter DYN_ODIV_SEL     = "false",
  parameter ODIV_SEL         = 8,
  parameter PSDA_SEL         = "0000",
  parameter DYN_DA_EN        = "false",
  parameter DUTYDA_SEL       = "1000",
  parameter CLKOUT_FT_DIR    = 1'b1,
  parameter CLKOUTP_FT_DIR   = 1'b1,
  parameter CLKOUT_DLY_STEP  = 0,
  parameter CLKOUTP_DLY_STEP = 0,
  parameter CLKFB_SEL        = "internal",
  parameter CLKOUT_BYPASS    = "false",
  parameter CLKOUTP_BYPASS   = "false",
  parameter CLKOUTD_BYPASS   = "false",
  parameter DYN_SDIV_SEL     = 2,
  parameter CLKOUTD_SRC      = "CLKOUT",
  parameter CLKOUTD3_SRC     = "CLKOUT"
) (
  input  CLKIN, CLKFB, RESET, RESET_P,
  input  [5:0] FBDSEL, IDSEL, ODSEL,
  input  [3:0] PSDA, DUTYDA, FDLY,
  output CLKOUT, LOCK, CLKOUTP, CLKOUTD, CLKOUTD3
);
endmodule
