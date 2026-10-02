open_project ./viterbi_zcu104_axis.xpr

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set progress [get_property PROGRESS [get_runs impl_1]]
set status [get_property STATUS [get_runs impl_1]]
puts "BITSTREAM_PROGRESS: $progress"
puts "BITSTREAM_STATUS: $status"

set bit_file "./viterbi_zcu104_axis.runs/impl_1/viterbi_axis_system_wrapper.bit"
if {[file exists $bit_file]} {
    puts "BITSTREAM_FILE: EXISTS at $bit_file"
    puts "BITSTREAM_SIZE: [file size $bit_file] bytes"
    puts "BITSTREAM_RESULT: OK"
} else {
    puts "BITSTREAM_FILE: MISSING"
    puts "BITSTREAM_RESULT: FAILED"
}
