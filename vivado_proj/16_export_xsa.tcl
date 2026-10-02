open_project ./viterbi_zcu104_axis.xpr
open_run impl_1
write_hw_platform -fixed -include_bit -force ./viterbi_zcu104_axis_wrapper.xsa
puts "XSA_EXPORT: done"
