# Real Vivado IP Integrator block design for the clean-room K7 Viterbi
# decoder, targeting this session's established hardware target: ZCU104
# (ZU7EV), same part/board_part already validated in the hls4ml build.
#
# Scope (deliberately minimal, per explicit user choice to avoid the
# version-locked openwifi-hw board flow): instantiate the PS, clock and
# reset the decoder for real from it, and bring its native (non-AXI) data
# ports out as external BD ports. Wrapping those in AXI4-Stream to match
# openofdm's viterbi.v is a separate, already-identified follow-on task,
# not done here.

create_project viterbi_zcu104 . -part xczu7ev-ffvc1156-2-e -force
set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]

set_property ip_repo_paths [list ./ip_repo] [current_project]
update_ip_catalog

create_bd_design "viterbi_system"

create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} [get_bd_cells zynq_ultra_ps_e_0]

# This minimal design has no AXI slave in the PL for the PS to master, so
# the board preset's general-purpose AXI masters would be left with
# dangling clock pins (confirmed by a first real validate_bd_design run
# that failed with exactly that error). Disable them rather than wiring a
# clock to an interface nothing uses.
set_property -dict [list \
  CONFIG.PSU__USE__M_AXI_GP0 {0} \
  CONFIG.PSU__USE__M_AXI_GP1 {0} \
] [get_bd_cells zynq_ultra_ps_e_0]

create_bd_cell -type ip -vlnv user.org:user:viterbi_k7_decoder:1.0 viterbi_k7_decoder_0

# Clock+reset automation: same proven pattern as the hls4ml build. Let
# Vivado pick/insert whatever reset infrastructure it judges correct for
# this IP's declared (inferred) reset interface, then VERIFY by querying
# the actual net, rather than assuming polarity matched.
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config { Clk {Auto} } [get_bd_pins viterbi_k7_decoder_0/clk]

# Bring the decoder's native data ports out as external BD ports: no AXI
# wrapper exists yet, so these are left for the next, separately-scoped
# integration step rather than fake-connected to anything.
make_bd_pins_external [get_bd_pins viterbi_k7_decoder_0/sym0]
make_bd_pins_external [get_bd_pins viterbi_k7_decoder_0/sym1]
make_bd_pins_external [get_bd_pins viterbi_k7_decoder_0/erase]
make_bd_pins_external [get_bd_pins viterbi_k7_decoder_0/input_valid]
make_bd_pins_external [get_bd_pins viterbi_k7_decoder_0/input_accept]
make_bd_pins_external [get_bd_pins viterbi_k7_decoder_0/frame_start]
make_bd_pins_external [get_bd_pins viterbi_k7_decoder_0/frame_end]
make_bd_pins_external [get_bd_pins viterbi_k7_decoder_0/decoded_bits]
make_bd_pins_external [get_bd_pins viterbi_k7_decoder_0/decode_len]
make_bd_pins_external [get_bd_pins viterbi_k7_decoder_0/decode_done]
make_bd_pins_external [get_bd_pins viterbi_k7_decoder_0/busy]

# --- Verify, don't assume, the reset wiring actually matches this port's
# real active-high semantics (VHDL: "if rst = '1' then ... IDLE").
set rst_net [get_bd_nets -of_objects [get_bd_pins viterbi_k7_decoder_0/rst]]
set rst_src [get_bd_pins -of_objects $rst_net -filter {DIR == "O"}]
puts "VERIFY (pre-fix): rst net = $rst_net, driven by = $rst_src"

# Confirmed by that output: automation picked peripheral_aresetn (active
# LOW) for a port whose VHDL treats rst='1' as "in reset" -- backwards.
# Same proc_sys_reset cell also exposes the active-HIGH peripheral_reset
# output; move the pin onto that one instead.
if {[lsearch $rst_src "*peripheral_aresetn*"] >= 0 || [string match "*aresetn*" $rst_src]} {
    set reset_cell [get_bd_cells -of_objects [get_bd_pins $rst_src]]
    disconnect_bd_net $rst_net [get_bd_pins viterbi_k7_decoder_0/rst]
    connect_bd_net [get_bd_pins $reset_cell/peripheral_reset] [get_bd_pins viterbi_k7_decoder_0/rst]
}

set rst_net2 [get_bd_nets -of_objects [get_bd_pins viterbi_k7_decoder_0/rst]]
set rst_src2 [get_bd_pins -of_objects $rst_net2 -filter {DIR == "O"}]
puts "VERIFY (post-fix): rst net = $rst_net2, driven by = $rst_src2"
if {![string match "*peripheral_reset" $rst_src2]} {
    error "Reset fix did not take effect as expected -- rst is driven by $rst_src2, not a peripheral_reset (active-high) pin. Stopping rather than validating a design with wrong reset polarity."
}

validate_bd_design
save_bd_design

make_wrapper -files [get_files ./viterbi_zcu104.srcs/sources_1/bd/viterbi_system/viterbi_system.bd] -top
add_files -norecurse ./viterbi_zcu104.gen/sources_1/bd/viterbi_system/hdl/viterbi_system_wrapper.v
update_compile_order -fileset sources_1

puts "BLOCK_DESIGN_BUILD: complete"
