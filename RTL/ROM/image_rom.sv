module image_rom #(
  parameter INIT_FILE = "start.hex",  // $readmemh file
  parameter int    AW        = 12           // 64*64 = 4096 => 12-bit address
)(
  input  logic           clk,
  input  logic [AW-1:0]  addr,
  output logic           dout
);
  // Inference hint for Intel/Altera; M10K on Cyclone V/10, etc.
  (* ramstyle = "M10K" *) logic [0:0] mem [0:(1<<AW)-1];

  initial $readmemh(INIT_FILE, mem);

  always_ff @(posedge clk) begin
    dout <= mem[addr][0];
  end
endmodule