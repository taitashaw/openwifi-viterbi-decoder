open_hw_manager
connect_hw_server
open_hw_target

set dev [lindex [get_hw_devices xczu7_0] 0]
puts "TARGET_DEVICE: $dev"

set_property PROGRAM.FILE {./viterbi_zcu104_axis.runs/impl_1/viterbi_axis_system_wrapper.bit} $dev

set prog_ok [catch {program_hw_devices $dev} prog_err]
if {$prog_ok == 0} { puts "PROGRAM_HW_DEVICES: OK" } else { puts "PROGRAM_HW_DEVICES: FAILED: $prog_err" }

set refresh_ok [catch {refresh_hw_device $dev} refresh_err]
if {$refresh_ok == 0} { puts "REFRESH_HW_DEVICE: OK" } else { puts "REFRESH_HW_DEVICE: FAILED: $refresh_err" }

if {$prog_ok == 0 && $refresh_ok == 0} {
    puts "PROGRAM_RESULT: SUCCESS"
} else {
    puts "PROGRAM_RESULT: FAILED"
}
