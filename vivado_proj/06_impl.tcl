open_project ./viterbi_zcu104.xpr

launch_runs impl_1 -jobs 4
wait_on_run impl_1

set status [get_property STATUS [get_runs impl_1]]
set progress [get_property PROGRESS [get_runs impl_1]]
puts "IMPL_STATUS: $status"
puts "IMPL_PROGRESS: $progress"

if {$progress ne "100%"} {
    puts "IMPL_RESULT: FAILED"
} else {
    open_run impl_1
    report_utilization -file ./viterbi_utilization_impl.rpt
    report_timing_summary -file ./viterbi_timing_summary_impl.rpt
    puts "IMPL_RESULT: OK"
}
