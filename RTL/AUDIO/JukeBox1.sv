module JukeBox1

    (
    input logic [3:0] melodySelect ,     // selector of one melody  
    input logic [4:0] noteIndex,         // serial number of current note. ( maximum 31 ). noteIndex determines freqIndex and note_length, via JueBox
    
    output logic [3:0] tone,        // index to toneDecoder
    output logic [3:0] note_length,      // length of notes, in beats
    output logic silenceOutN
 ) ;        
 
	
// ************** frequencies: *************************************************************************************************
    typedef enum logic [3:0] {do_, doD, re, reD, mi, fa, faD, sol, solD, la, laD, si, do_H, doDH, re_H, silence } musicNote ;//*
//              Hex value:     0    1    2   3   4    5   6    7     8    9   A   B    C      D    E      F                  //*
// *****************************************************************************************************************************
      
   // type of frequency is musicNote   (enum)  
   // Frequency index is 0....15   
   // length is in beats ( 1 to 15 )
   // length = 0 means end of melody	
	
  localparam MELODY_GAME_START = 4'd0;
  localparam MELODY_WIN = 4'd1;
  localparam MELODY_LOSE = 4'd2;
  localparam MELODY_LIFE_LOST = 4'd3;
  localparam MELODY_LIFE_GAINED = 4'd4;
  localparam MELODY_PICKUP_CHERRY = 4'd5;
  localparam MELODY_PICKUP_BANANA = 4'd6;
  localparam MELODY_PICKUP_STRAW = 4'd7;
  localparam MELODY_PICKUP_POISON = 4'd8;
  localparam MELODY_PICKUP_PENALTY = 4'd9;
  localparam MELODY_FRUIT_APPEAR = 4'd10;
  localparam MELODY_BREAK = 4'd11;
  localparam MELODY_EAT_GHOST = 4'd12;
  localparam MELODY_POWER_MODE = 4'd13;
  localparam MELODY_COIN = 4'd14;
  localparam MELODY_SILENCE = 4'd15;
   	
localparam MaxMelodyLength = 6'h32;  // maximum melody length, in notes. 
musicNote frq[(MaxMelodyLength-1'b1):0]  ;     // frq is the array of frequency indices of the melody. it includes up to 32 notes.  
logic [3:0] len[(MaxMelodyLength-1'b1):0] ;   // len is the array of note lengths , in terms of beats. it includes up to 32 notes.		

assign silenceOutN = !( tone == silence ) ; // disable sound if note is "silence"	 
	 
always_comb begin	 
  frq = '{default: 0};
	 len = '{default: 0}; 
  case (melodySelect) 
    MELODY_GAME_START: begin 
      //************************************************************************************************** 
      // GAME START (Intro melody) 
      //************************************************************************************************** 
        frq[0] = si; len[0] = 1;
        frq[1] = do_H; len[1] = 1;
        frq[2] = re_H; len[2] = 1;
        frq[3] = mi;   len[3] = 2;
        frq[4] = sol;  len[4] = 3;
        frq[5] = do_;  len[5] = 0;
    end 
    
    MELODY_WIN: begin 
      //************************************************************************************************** 
      //  WIN
      //************************************************************************************************** 
	      frq[0] = do_ ; len[0] = 2 ; 
			frq[1] = mi ; len[1] = 2 ; 
			frq[2] = sol ; len[2] = 2 ; 
			frq[3] = do_H ; len[3] = 2 ; 
			frq[4] = sol ; len[4] = 2 ; 
			frq[5] = do_H ; len[5] = 4 ; 
			frq[6] = do_ ; len[6] = 0 ; // End
    end 
    
    MELODY_LOSE: begin 
      //************************************************************************************************** 
      // LOSE
      //************************************************************************************************** 
			frq[0] = do_H ; len[0] = 2 ; 
			frq[1] = si ; len[1] = 2 ; 
			frq[2] = laD ; len[2] = 2 ; 
			frq[3] = la ; len[3] = 2 ; 
			frq[4] = solD ; len[4] = 2 ; 
			frq[5] = sol ; len[5] = 2 ; 
			frq[6] = faD ; len[6] = 2 ; 
			frq[7] = fa ; len[7] = 2 ; 
			frq[8] = mi ; len[8] = 2 ; 
			frq[9] = reD ; len[9] = 2 ; 
			frq[10] = re ; len[10] = 2 ; 
			frq[11] = doD ; len[11] = 2 ; 
			frq[12] = do_ ; len[12] = 4 ; 
			frq[13] = do_ ; len[13] = 0 ; // End 
    end 
    
    MELODY_LIFE_LOST: begin 
      //************************************************************************************************** 
      // LIFE LOST
      //************************************************************************************************** 
        frq[0] = mi; len[0] = 1;
        frq[1] = re; len[1] = 1;
        frq[2] = do_;len[2] = 2;
        frq[3] = silence; len[3] = 0;
    end 
    
    MELODY_LIFE_GAINED: begin 
      //************************************************************************************************** 
      // LIFE GAINED
      //************************************************************************************************** 
        frq[0] = sol; len[0] = 2;
        frq[1] = do_H;len[1] = 4;
        frq[2] = mi;  len[2] = 4;
        frq[3] = silence; len[3] = 0;
    end 
    
    MELODY_PICKUP_CHERRY: begin 
      //************************************************************************************************** 
      // PICKUP CHERRY
      //************************************************************************************************** 
		    frq[0] = do_; len[0] = 2;
        frq[1] = mi;  len[1] = 2;
        frq[2] = sol; len[2] = 2;
        frq[3] = silence; len[3] = 0;
    end 
    
    MELODY_PICKUP_BANANA: begin 
      //************************************************************************************************** 
      // PICKUP BANANA
      //************************************************************************************************** 
        frq[0] = fa; len[0] = 1;
        frq[1] = la; len[1] = 1;
        frq[2] = do_H;len[2] = 2;
        frq[3] = silence; len[3] = 0;
    end 
    
    MELODY_PICKUP_STRAW: begin 
      //************************************************************************************************** 
      // PICKUP STRAWBERRY
      //************************************************************************************************** 
        frq[0] = re; len[0] = 1;
        frq[1] = fa; len[1] = 1;
        frq[2] = si; len[2] = 2;
        frq[3] = silence; len[3] = 0; 
    end 
    
    MELODY_PICKUP_POISON: begin 
      //************************************************************************************************** 
      // PICKUP POISON
      //************************************************************************************************** 
        frq[0] = laD; len[0] = 2;
        frq[1] = sol; len[1] = 2;
        frq[2] = silence; len[2] = 1;
        frq[3] = laD; len[3] = 1;
        frq[4] = silence; len[4] = 0;
    end 
    
    MELODY_PICKUP_PENALTY: begin 
      //************************************************************************************************** 
      // PICKUP PENALTY
      //************************************************************************************************** 
        frq[0] = reD; len[0] = 2;
        frq[1] = do_; len[1] = 2;
        frq[2] = silence; len[2] = 0;
    end 
    MELODY_FRUIT_APPEAR: begin 
      //************************************************************************************************** 
      // PICKUP APPEARS
      //************************************************************************************************** 
        frq[0] = do_; len[0] = 1;
        frq[1] = fa;  len[1] = 1;
        frq[2] = la;  len[2] = 1;
        frq[3] = do_H;len[3] = 2;
        frq[4] = silence; len[4] = 0;
    end 
	 
	 MELODY_BREAK: begin 
      //************************************************************************************************** 
      // BREAKING WALLS
      //************************************************************************************************** 
          frq[0] = fa;     len[0] = 1;  
			 frq[1] = solD;   len[1] = 1;  
			 frq[2] = la;     len[2] = 1;  
			 frq[3] = re_H;   len[3] = 1;  
			 frq[4] = do_;    len[4] = 2;  
			 frq[5] = silence; len[5] = 0; 
    end 
	  
    MELODY_EAT_GHOST: begin 
      //************************************************************************************************** 
      // EAT GHOST
      //************************************************************************************************** 
			frq[0] = silence ; len[0] = 1 ; 
			frq[1] = do_ ; len[1] = 1 ; 
			frq[2] = mi ; len[2] = 1 ; 
			frq[3] = sol ; len[3] = 1 ; 
			frq[4] = do_H ; len[4] = 2 ; 
			frq[5] = do_ ; len[5] = 1 ;
			frq[6] = silence ;  len[6] = 0 ; // End
    end 
    MELODY_POWER_MODE: begin 
      //************************************************************************************************** 
      // POWER MODE BACKGROUND
      //************************************************************************************************** 
        frq[0] = si;   len[0] = 1;
        frq[1] = laD;  len[1] = 1;
        frq[2] = sol;  len[2] = 1;
        frq[3] = faD;  len[3] = 1;
        frq[4] = mi;   len[4] = 1;
        frq[5] = re;   len[5] = 1;
        frq[6] = si;   len[6] = 1;
        frq[7] = silence; len[7] = 1;
        frq[8] = do_;  len[8] = 0; // loop
    end 
    MELODY_COIN: begin 
      //************************************************************************************************** 
      // COIN COLLECTED
      //************************************************************************************************** 
			 frq[0]  = mi;      len[0]  = 1;
			 frq[1]  = sol;     len[1]  = 1;
			 frq[2]  = do_H;    len[2]  = 2;
			 frq[3]  = silence; len[3] = 0; // End
    end 
    
    default: begin 
      //************************************************************************************************** 
      // SILENCE
      //************************************************************************************************** 
      frq[0] = silence ; len[0] = 2 ; 
      frq[1] = do_ ; len[1] = 0 ;  
    end 
  endcase 
  end // always 
 
//***********************************************************************
//     Extract outputs of specific note from sheet music :                                                        *
//***********************************************************************

assign tone   = frq[noteIndex] ;
assign note_length = len[noteIndex] ; 

 
endmodule