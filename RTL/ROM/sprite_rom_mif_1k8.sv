//------------------------------------------------------------------------------
// Pac-Man mouth sprite, sourced from two MIF ROMs (open/close)
//   - Sprite size: 32x32, 8-bit palette indices
//   - ROMs: pacman_mouth_open.mif, pacman_mouth_close.mif (1024 bytes each)
//   - One-cycle synchronous read (altsyncram outdata_reg_a = "CLOCK0")
//------------------------------------------------------------------------------

// --------- Single-port ROM wrapper initialized from a MIF (1024 x 8) ---------
module sprite_rom_mif_1k8 #(
  parameter string MIF_FILE = "pacman_mouth_open.mif"
) (
  input  logic       clk,
  input  logic [9:0] addr,   // 0..1023
  output logic [7:0] q
);
  // Force block ROM and initialize from MIF
  (* romstyle = "M10K", ramstyle = "M10K", ram_init_file = MIF_FILE *)
  logic [7:0] mem [0:1023];

  // 1-cycle synchronous read (ensures BRAM inference)
  always_ff @(posedge clk) begin
    q <= mem[addr];
  end
endmodule

