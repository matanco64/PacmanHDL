transcript on
if ![file isdirectory Lab1Demo_iputf_libs] {
	file mkdir Lab1Demo_iputf_libs
}

if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

###### Libraries for IPUTF cores 
###### End libraries for IPUTF cores 
###### MIF file copy and HDL compilation commands for IPUTF cores 


vlog "C:/Users/mayai/Documents/eelabGit/PacmanHDL/CLK_31P5_sim/CLK_31P5.vo"

vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Bomb {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Bomb/one_sec_counter.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Bomb {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Bomb/hexss.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Bomb {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Bomb/down_counter.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Bomb {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Bomb/bomb.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Bomb {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Bomb/bcddn.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Pacman {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Pacman/map1_drawer.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Pacman {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Pacman/characterBitMap.sv}
vlog -vlog01compat -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Pacman {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Pacman/pacman_mouth_openBitMap.SV}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO/Mili_sec_counter.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO/melody_player_1.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO/JukeBox1.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/VGA {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/VGA/square_object.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/VGA {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/VGA/back_ground_draw.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/VGA {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/VGA/objects_mux.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/VGA {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/VGA/VGA_Controller.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/VGA {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/VGA/NumbersBitMap.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/KEYBOARDX {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/KEYBOARDX/keyPad_decoder.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/KEYBOARDX {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/KEYBOARDX/random.sv}
vlog -vlog01compat -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Seg7 {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Seg7/SEG7.SV}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO/SinTable.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO/addr_counter.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO/prescaler.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO/ToneDecoder.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO/audio_codec_controller {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO/audio_codec_controller/i2c.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO/audio_codec_controller {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO/audio_codec_controller/DualSerial2parallel.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO/audio_codec_controller {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO/audio_codec_controller/clock_500.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO/audio_codec_controller {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO/audio_codec_controller/audio_codec_controller.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/VGA {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/VGA/MyConstant.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Pacman {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Pacman/pacman_move.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Pacman {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Pacman/pacman_game_controller.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/VGA {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/VGA/ScoreBitMap.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Pacman {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Pacman/ghost_move.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Pacman {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Pacman/heartBitMap.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Pacman {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Pacman/random2.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/AUDIO/melody_selector.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Bitmaps {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Bitmaps/sideBitMaps.sv}
vlog -sv -work work +incdir+C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Bitmaps {C:/Users/mayai/Documents/eelabGit/PacmanHDL/RTL/Bitmaps/sideBitMapV1.sv}

