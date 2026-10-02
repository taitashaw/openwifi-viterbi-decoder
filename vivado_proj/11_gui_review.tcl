# Corrected GUI review script: points at the FINAL, timing-closed AXI4-Stream
# + DMA project and the real current AXI-stream simulation waveform, not the
# stale viterbi_zcu104.xpr / tb_viterbi_k7 references the old scripts used.
# Each step is caught independently so one failure doesn't block the rest.

set proj_ok [catch {open_project /home/jotshawlinux/Downloads/openwifi-viterbi-decoder/vivado_proj/viterbi_zcu104_axis.xpr} proj_err]
if {$proj_ok == 0} { puts "PROJECT_OPEN: OK" } else { puts "PROJECT_OPEN: FAILED: $proj_err" }

set bd_ok [catch {open_bd_design [get_files viterbi_axis_system.bd]} bd_err]
if {$bd_ok == 0} { puts "BD_OPEN: OK" } else { puts "BD_OPEN: FAILED: $bd_err" }

set run_ok [catch {open_run impl_1} run_err]
if {$run_ok == 0} { puts "RUN_OPEN: OK" } else { puts "RUN_OPEN: FAILED: $run_err" }

set wave_ok [catch {open_wave_database /home/jotshawlinux/Downloads/openwifi-viterbi-decoder/vhdl/tb_axis2.wdb} wave_err]
if {$wave_ok == 0} { puts "WAVE_OPEN: OK" } else { puts "WAVE_OPEN: FAILED: $wave_err" }

puts "GUI_REVIEW_READY"
