module controller_translator (
		input  logic [7:0] ps5_data_export,     
		input logic [3:0] RegularkeyPad,
		input logic [3:0] RegularkeyPadValid,
		output logic [3:0] keyPadCode,
		output  logic      keyPadValid    
);

 assign keyPadCode = ps5_data_export || RegularkeyPad;
 assign keyPadValid = RegularkeyPadValid || ps5_data_export != 0;

endmodule