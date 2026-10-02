# Corrected GUI review script, round 2.
# Round 1 opened the wave database but never added signals to the trace pane
# (open_wave_database only makes signals browsable, add_wave is what actually
# draws traces), and the Block Design tab ended up behind the Simulation tab.
# This round: load the run + waveform, explicitly add the key AXI-stream
# signals plus the real internal decoder/adapter signals, then open the BD
# last so it is the frontmost tab when the script finishes.

set proj_ok [catch {open_project /home/jotshawlinux/Downloads/openwifi-viterbi-decoder/vivado_proj/viterbi_zcu104_axis.xpr} proj_err]
if {$proj_ok == 0} { puts "PROJECT_OPEN: OK" } else { puts "PROJECT_OPEN: FAILED: $proj_err" }

set run_ok [catch {open_run impl_1} run_err]
if {$run_ok == 0} { puts "RUN_OPEN: OK" } else { puts "RUN_OPEN: FAILED: $run_err" }

set wave_ok [catch {open_wave_database /home/jotshawlinux/Downloads/openwifi-viterbi-decoder/vhdl/tb_axis2.wdb} wave_err]
if {$wave_ok == 0} { puts "WAVE_OPEN: OK" } else { puts "WAVE_OPEN: FAILED: $wave_err" }

set add_ok [catch {
    add_wave /tb_viterbi_axis/clk
    add_wave /tb_viterbi_axis/rst
    add_wave /tb_viterbi_axis/s_axis_tvalid
    add_wave /tb_viterbi_axis/s_axis_tready
    add_wave /tb_viterbi_axis/s_axis_tdata
    add_wave /tb_viterbi_axis/s_axis_tlast
    add_wave /tb_viterbi_axis/m_axis_tvalid
    add_wave /tb_viterbi_axis/m_axis_tready
    add_wave /tb_viterbi_axis/m_axis_tdata
    add_wave /tb_viterbi_axis/m_axis_tlast
    add_wave /tb_viterbi_axis/dut/u_core/cur_state
    add_wave /tb_viterbi_axis/dut/u_core/busy
    add_wave /tb_viterbi_axis/dut/u_core/decode_done
    add_wave /tb_viterbi_axis/dut/u_core/tb_state
    add_wave /tb_viterbi_axis/dut/u_core/tb_idx
    add_wave /tb_viterbi_axis/dut/u_out/streaming_busy
    add_wave /tb_viterbi_axis/rx_frame_count
    add_wave /tb_viterbi_axis/rx_count
} add_err]
if {$add_ok == 0} { puts "ADD_WAVE: OK" } else { puts "ADD_WAVE: FAILED: $add_err" }

set bd_ok [catch {open_bd_design [get_files viterbi_axis_system.bd]} bd_err]
if {$bd_ok == 0} { puts "BD_OPEN: OK" } else { puts "BD_OPEN: FAILED: $bd_err" }

puts "GUI_REVIEW_FULL_READY"
