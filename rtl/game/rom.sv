// Synchronous ROM, inferred as block RAM by Yosys/Quartus/Verilator alike.
// Same timing as the altsyncram "UNREGISTERED" output it replaces:
// address sampled on the clock edge, data valid after it (1 cycle latency).
module rom #(
  parameter int    WIDTH     = 8,
  parameter int    DEPTH     = 256,
  parameter int    AW        = $clog2(DEPTH),
  parameter string INIT_FILE = ""
) (
  input  logic             clk,
  input  logic [AW-1:0]    addr,
  output logic [WIDTH-1:0] q
);
  logic [WIDTH-1:0] mem [0:DEPTH-1];

  initial $readmemh(INIT_FILE, mem);

  always_ff @(posedge clk) q <= mem[addr];
endmodule
