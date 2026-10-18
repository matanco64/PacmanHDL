// 8N1 UART receiver. `valid` pulses for one clock with each received byte.
module uart_rx #(
  parameter int CLK_HZ = 33_750_000,
  parameter int BAUD   = 115_200
) (
  input  logic       clk,
  input  logic       resetN,
  input  logic       rx,
  output logic [7:0] data,
  output logic       valid
);
  localparam int DIV = CLK_HZ / BAUD;

  logic [1:0]  rxSync;
  logic [$clog2(DIV*3/2+1)-1:0] cnt;
  logic [3:0]  bitIdx;      // 0 = idle, 1..8 data bits, 9 = stop bit
  logic [7:0]  shift;

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      rxSync <= 2'b11;
      cnt    <= '0;
      bitIdx <= '0;
      shift  <= '0;
      data   <= '0;
      valid  <= 1'b0;
    end else begin
      rxSync <= {rxSync[0], rx};
      valid  <= 1'b0;
      if (bitIdx == 0) begin
        if (!rxSync[1]) begin       // start bit: sample bit 0 in its middle
          bitIdx <= 4'd1;
          cnt    <= DIV * 3 / 2;
        end
      end else if (cnt != 0) begin
        cnt <= cnt - 1'b1;
      end else if (bitIdx <= 8) begin
        shift  <= {rxSync[1], shift[7:1]};
        bitIdx <= bitIdx + 1'b1;
        cnt    <= DIV - 1;
      end else begin                // stop bit
        if (rxSync[1]) begin
          data  <= shift;
          valid <= 1'b1;
        end
        bitIdx <= '0;
      end
    end
  end
endmodule
