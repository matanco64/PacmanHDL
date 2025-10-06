module JukeBox1

    (
    // Declare wires and regs :
 
 input logic [3:0] melodySelect ,     // selector of one melody  
 input logic [4:0] noteIndex,         // serial number of current note. ( maximum 31 ). noteIndex determines freqIndex and note_length, via JueBox
 
 output logic [3:0] tone,        // index to toneDecoder
 output logic [3:0] note_length,      // length of notes, in beats
 output logic silenceOutN ) ;         //  a silence note: disable sound
 

 localparam MaxMelodyLength = 6'h32;  // maximum melody length, in notes. 
	

// ************** frequencies: *************************************************************************************************
    typedef enum logic [3:0] {do_, doD, re, reD, mi, fa, faD, sol, solD, la, laD, si, do_H, doDH, re_H, silence } musicNote ;//*
//              Hex value:     0    1    2   3   4    5   6    7     8    9   A   B    C      D    E      F                  //*
// *****************************************************************************************************************************
      
   // type of frequency is musicNote   (enum)  
   // Frequency index is 0....15   
   // length is in beats ( 1 to 15 )
   // length = 0 means end of melody		

musicNote frq[(MaxMelodyLength-1'b1):0]  ;     // frq is the array of frequency indices of the melody. it includes up to 32 notes.  
logic [3:0] len[(MaxMelodyLength-1'b1):0] ;   // len is the array of note lengths , in terms of beats. it includes up to 32 notes.		

assign silenceOutN = !( tone == silence ) ; // disable sound if note is "silence"	 
	 
	 
	 
always_comb begin	 
    frq = '{default: 0};
	 len = '{default: 0}; 
  case (melodySelect) 
    0: begin 
      //************************************************************************************************** 
      // PAC-MAN GAME START (Intro melody) 
      // Classic ascending scale with rhythm
      //************************************************************************************************** 
      frq[0] = si ; len[0] = 1 ; 
      frq[1] = do_H ; len[1] = 1 ; 
      frq[2] = re_H ; len[2] = 1 ; 
      frq[3] = do_H ; len[3] = 1 ; 
      frq[4] = si ; len[4] = 1 ; 
      frq[5] = la ; len[5] = 1 ; 
      frq[6] = sol ; len[6] = 1 ; 
      frq[7] = la ; len[7] = 1 ; 
      frq[8] = si ; len[8] = 1 ; 
      frq[9] = do_H ; len[9] = 1 ; 
      frq[10] = re_H ; len[10] = 1 ; 
      frq[11] = mi ; len[11] = 1 ; 
      frq[12] = sol ; len[12] = 1 ; 
      frq[13] = do_H ; len[13] = 3 ; 
      frq[14] = do_ ; len[14] = 0 ; // End of melody 
    end 
    
    1: begin 
      //************************************************************************************************** 
      // PAC-MAN BACKGROUND MUSIC (Wakka-wakka rhythm)
      // Alternating two-note pattern that mimics the chomping sound
      //************************************************************************************************** 
      frq[0] = fa ; len[0] = 1 ; 
      frq[1] = sol ; len[1] = 1 ; 
      frq[2] = fa ; len[2] = 1 ; 
      frq[3] = sol ; len[3] = 1 ; 
      frq[4] = fa ; len[4] = 1 ; 
      frq[5] = sol ; len[5] = 1 ; 
      frq[6] = fa ; len[6] = 1 ; 
      frq[7] = sol ; len[7] = 1 ; 
      frq[8] = mi ; len[8] = 1 ; 
      frq[9] = fa ; len[9] = 1 ; 
      frq[10] = mi ; len[10] = 1 ; 
      frq[11] = fa ; len[11] = 1 ; 
      frq[12] = mi ; len[12] = 1 ; 
      frq[13] = fa ; len[13] = 1 ; 
      frq[14] = mi ; len[14] = 1 ; 
      frq[15] = fa ; len[15] = 1 ; 
      frq[16] = do_ ; len[16] = 0 ; // Loop point
    end 
    
    2: begin 
      //************************************************************************************************** 
      // COIN EATING SOUND (Wakka)
      // Very short, quick alternating notes
      //************************************************************************************************** 
      frq[0] = sol ; len[0] = 1 ; 
      frq[1] = do_H ; len[1] = 1 ; 
      frq[2] = do_ ; len[2] = 0 ; // End 
    end 
    
    3: begin 
      //************************************************************************************************** 
      // POWER PELLET MODE (Siren-like descending pattern)
      // Repeating descending chromatic sequence
      //************************************************************************************************** 
      frq[0] = si ; len[0] = 1 ; 
      frq[1] = laD ; len[1] = 1 ; 
      frq[2] = la ; len[2] = 1 ; 
      frq[3] = solD ; len[3] = 1 ; 
      frq[4] = sol ; len[4] = 1 ; 
      frq[5] = faD ; len[5] = 1 ; 
      frq[6] = fa ; len[6] = 1 ; 
      frq[7] = mi ; len[7] = 1 ; 
      frq[8] = si ; len[8] = 1 ; 
      frq[9] = laD ; len[9] = 1 ; 
      frq[10] = la ; len[10] = 1 ; 
      frq[11] = solD ; len[11] = 1 ; 
      frq[12] = sol ; len[12] = 1 ; 
      frq[13] = faD ; len[13] = 1 ; 
      frq[14] = fa ; len[14] = 1 ; 
      frq[15] = mi ; len[15] = 1 ; 
      frq[16] = do_ ; len[16] = 0 ; // Loop
    end 
    
    4: begin 
      //************************************************************************************************** 
      // PAC-MAN DEATH SOUND
      // Descending chromatic scale with slower rhythm - classic death sound
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
    
    5: begin 
      //************************************************************************************************** 
      // EATING GHOST SOUND
      // Quick ascending run
      //************************************************************************************************** 
      frq[0] = do_ ; len[0] = 1 ; 
      frq[1] = mi ; len[1] = 1 ; 
      frq[2] = sol ; len[2] = 1 ; 
      frq[3] = do_H ; len[3] = 2 ; 
      frq[4] = do_ ; len[4] = 0 ; // End 
    end 
    
    6: begin 
      //************************************************************************************************** 
      // GHOST RETREATING SOUND (Eyes returning to base)
      // Fast oscillating high notes
      //************************************************************************************************** 
      frq[0] = re_H ; len[0] = 1 ; 
      frq[1] = do_H ; len[1] = 1 ; 
      frq[2] = re_H ; len[2] = 1 ; 
      frq[3] = do_H ; len[3] = 1 ; 
      frq[4] = re_H ; len[4] = 1 ; 
      frq[5] = do_H ; len[5] = 1 ; 
      frq[6] = re_H ; len[6] = 1 ; 
      frq[7] = do_H ; len[7] = 1 ; 
      frq[8] = do_ ; len[8] = 0 ; // Loop
    end 
    
    7: begin 
      //************************************************************************************************** 
      // INTERMISSION / LEVEL COMPLETE
      // Cheerful ascending melody
      //************************************************************************************************** 
      frq[0] = do_ ; len[0] = 2 ; 
      frq[1] = mi ; len[1] = 2 ; 
      frq[2] = sol ; len[2] = 2 ; 
      frq[3] = do_H ; len[3] = 2 ; 
      frq[4] = sol ; len[4] = 2 ; 
      frq[5] = do_H ; len[5] = 4 ; 
      frq[6] = do_ ; len[6] = 0 ; // End 
    end 
    
    8: begin 
      //************************************************************************************************** 
      // FRUIT APPEARS
      // Sparkly ascending arpeggio
      //************************************************************************************************** 
      frq[0] = do_ ; len[0] = 1 ; 
      frq[1] = fa ; len[1] = 1 ; 
      frq[2] = la ; len[2] = 1 ; 
      frq[3] = do_H ; len[3] = 2 ; 
      frq[4] = do_ ; len[4] = 0 ; // End 
    end 
    
    9: begin 
      //************************************************************************************************** 
      // EXTRA LIFE
      // Triumphant fanfare
      //************************************************************************************************** 
      frq[0] = sol ; len[0] = 2 ; 
      frq[1] = do_H ; len[1] = 2 ; 
      frq[2] = mi ; len[2] = 2 ; 
      frq[3] = sol ; len[3] = 2 ; 
      frq[4] = do_H ; len[4] = 4 ; 
      frq[5] = do_ ; len[5] = 0 ; // End 
    end 
    
    default: begin 
      //************************************************************************************************** 
      // SILENCE / EMPTY
      //************************************************************************************************** 
      frq[0] = silence ; len[0] = 2 ; 
      frq[1] = do_ ; len[1] = 0 ; // End 
    end 
  endcase 
  end // always 
 
//***********************************************************************
//     Extract outputs of specific note from sheet music :                                                        *
//***********************************************************************

assign tone   = frq[noteIndex] ;
assign note_length = len[noteIndex] ; 

 
 
endmodule

