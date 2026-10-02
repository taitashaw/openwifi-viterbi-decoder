open_project ./viterbi_zcu104.xpr

launch_runs synth_1 -jobs 4
wait_on_run synth_1

set status [get_property STATUS [get_runs synth_1]]
set progress [get_property PROGRESS [get_runs synth_1]]
puts "SYNTH_STATUS: $status"
puts "SYNTH_PROGRESS: $progress"

if {$progress ne "100%"} {
    puts "SYNTH_RESULT: FAILED"
} else {
    open_run synth_1 -name synth_1

    report_utilization -file ./viterbi_utilization.rpt
    report_utilization -hierarchical -file ./viterbi_utilization_hier.rpt
    report_timing_summary -file ./viterbi_timing_summary.rpt

    puts "SYNTH_RESULT: OK"
}
