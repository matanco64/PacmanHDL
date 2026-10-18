// Simple counter initializer for bomb timer, but since we are using a switch, we need a debouncer
module counter_initializer (
  input  logic clk, resetN,
  input  logic startN, pauseN, OneSecPulse, tc,
  output logic countLoadN, countEnable, lampEnable, show88, timerEnd
);

  // --- sync external signal driven by switch---
  logic pauseN_sync;

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      pauseN_sync <= 1'b1;
    end else begin
      pauseN_sync <= pauseN;
    end
  end

  // --- state machine ---
  typedef enum logic [1:0] {
            s_idle,
            s_load,
            s_run,
            s_pause
  } SMcounter_t;

  SMcounter_t SMcounter;
  SMcounter_t prev_SMcounter;

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      SMcounter   <= s_idle;
      countLoadN  <= 1'b1;
      countEnable <= 1'b0;
      lampEnable  <= 1'b0;
      show88      <= 1'b0;
      timerEnd    <= 1'b0;
      prev_SMcounter <= s_idle;
    end else begin
      // defaults
      countLoadN  <= 1'b1;
      countEnable <= 1'b0;
      lampEnable  <= 1'b1;
      show88      <= 1'b0;
      timerEnd    <= 1'b0;
      prev_SMcounter <= SMcounter;

      unique case (SMcounter)
        s_idle:  begin
          lampEnable <= 1'b0; timerEnd <= 1'b1; countLoadN <= 1'b0;
          if (!startN) SMcounter <= s_load;
        end
        s_load:  begin
          countLoadN <= 1'b0;
          SMcounter  <= s_run;
        end
        s_run:   begin
          countEnable <= 1'b1;
          if (!pauseN_sync)       SMcounter <= s_pause;
          else if (!startN)  SMcounter <= s_load;
          else if (tc)       SMcounter <= s_idle;
        end
        s_pause: begin
          if (pauseN_sync) SMcounter <= s_run;
        end
        default: SMcounter <= prev_SMcounter; // recovery
      endcase
    end
  end
endmodule