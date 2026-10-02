# Expanded waveform: adds the adapter-to-core signals, the frame-gating
# signal, the core's raw decode output, and the output adapter's own
# internal state, none of which the AXI-shell-only view showed.
add_wave /tb_viterbi_axis/clk
add_wave /tb_viterbi_axis/rst
add_wave /tb_viterbi_axis/s_axis_tvalid
add_wave /tb_viterbi_axis/s_axis_tready
add_wave /tb_viterbi_axis/s_axis_tdata
add_wave /tb_viterbi_axis/s_axis_tlast

add_wave /tb_viterbi_axis/dut/u_in/sym0
add_wave /tb_viterbi_axis/dut/u_in/sym1
add_wave /tb_viterbi_axis/dut/u_in/erase
add_wave /tb_viterbi_axis/dut/u_in/input_valid
add_wave /tb_viterbi_axis/dut/u_in/frame_start
add_wave /tb_viterbi_axis/dut/u_in/frame_end
add_wave /tb_viterbi_axis/dut/u_in/input_accept
add_wave /tb_viterbi_axis/dut/input_accept_gated

add_wave /tb_viterbi_axis/dut/u_core/cur_state
add_wave /tb_viterbi_axis/dut/u_core/busy
add_wave /tb_viterbi_axis/dut/u_core/decode_done
add_wave /tb_viterbi_axis/dut/u_core/decoded_bits
add_wave /tb_viterbi_axis/dut/u_core/decode_len
add_wave /tb_viterbi_axis/dut/u_core/tb_state
add_wave /tb_viterbi_axis/dut/u_core/tb_idx

add_wave /tb_viterbi_axis/dut/u_out/cur_state
add_wave /tb_viterbi_axis/dut/u_out/data_reg
add_wave /tb_viterbi_axis/dut/u_out/num_bytes
add_wave /tb_viterbi_axis/dut/u_out/byte_idx
add_wave /tb_viterbi_axis/dut/u_out/streaming_busy

add_wave /tb_viterbi_axis/m_axis_tvalid
add_wave /tb_viterbi_axis/m_axis_tready
add_wave /tb_viterbi_axis/m_axis_tdata
add_wave /tb_viterbi_axis/m_axis_tlast
add_wave /tb_viterbi_axis/rx_frame_count
add_wave /tb_viterbi_axis/rx_count
run all
puts "WAVE_RUN_DONE"
