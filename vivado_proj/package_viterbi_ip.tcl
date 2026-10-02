# Packages viterbi_k7_axis (the AXI4-Stream-wrapped decoder) as a real
# Vivado IP core so it can be dropped into an IP Integrator block design
# and connected directly to an AXI DMA. Run in batch mode:
#   vivado -mode batch -source package_viterbi_ip.tcl
#
# Uses a throwaway project (ip_pack_proj) purely as a packaging workspace;
# the real deliverable is the component at ./ip_repo/viterbi_k7_axis_1_0.
# Vivado auto-recognizes the s_axis_*/m_axis_* port naming convention as
# real AXI4-Stream interfaces during packaging, not just raw ports.

create_project ip_pack_proj ./ip_pack_proj -part xczu7ev-ffvc1156-2-e -force

add_files -norecurse {../vhdl/viterbi_k7_pkg.vhd ../vhdl/viterbi_k7_decoder.vhd ../vhdl/viterbi_axis_in.vhd ../vhdl/viterbi_axis_out.vhd ../vhdl/viterbi_k7_axis.vhd}
set_property top viterbi_k7_axis [current_fileset]
update_compile_order -fileset sources_1

file mkdir ./ip_repo
ipx::package_project -root_dir ./ip_repo/viterbi_k7_axis_1_0 -vendor user.org -library user -taxonomy /UserIP -import_files -set_current true

set_property vendor_display_name {Clean-room K7 Viterbi (AXI4-Stream)} [ipx::current_core]
set_property description {Block-based (171,133) octal K=7 rate-1/2 soft-decision Viterbi decoder for 802.11a/g/n, AXI4-Stream wrapped, verified against golden_reference.py (920/920 test vectors incl. real BPSK+AWGN channel data and erasure).} [ipx::current_core]

ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]

puts "IP_PACKAGE_RESULT: [file exists ./ip_repo/viterbi_k7_axis_1_0/component.xml]"
close_project
