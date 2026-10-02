# Corrected waveform script for the current AXI-stream testbench (tb_viterbi_axis),
# replacing the stale open_wave.tcl which referenced the old tb_viterbi_k7 signal
# names (din/din_valid, no AXI). Adding signals against a live xsim snapshot
# (not a standalone open_wave_database) so add_wave actually binds real data,
# since three attempts at add_wave against a loaded .wdb in the project GUI
# resolved names with no errors but drew no trace data.
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
run all
puts "WAVE_RUN_DONE"
