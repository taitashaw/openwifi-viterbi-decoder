# Real Vivado IP Integrator block design connecting the AXI4-Stream-wrapped
# Viterbi decoder to the PS via a real AXI DMA, following the same proven
# pattern as the hls4ml build (PS + AXI DMA + custom IP, SmartConnect via
# apply_bd_automation). Unlike the earlier minimal BD, external port count
# here is zero data pins (both stream interfaces terminate inside the DMA
# connection), so full place-and-route to real silicon should succeed --
# the prior attempt failed outright with 1521 I/O ports from raw
# decoded_bits/etc pins brought straight to the top level.

create_project viterbi_zcu104_axis . -part xczu7ev-ffvc1156-2-e -force
set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]

set_property ip_repo_paths [list ./ip_repo] [current_project]
update_ip_catalog

create_bd_design "viterbi_axis_system"

create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} [get_bd_cells zynq_ultra_ps_e_0]

# The board preset alone does not enable the HP slave ports (confirmed by a
# real "No interface pins matched" failure on the first attempt). GP2/GP3
# are the properties that yield HP0/HP1 respectively, per the same mapping
# already confirmed in the hls4ml build. Two separate HP ports, one per DMA
# master, not one HP port for both: a first attempt at the latter via two
# separate apply_bd_automation calls onto the same port reproduced the
# exact "second, orphaned SmartConnect with no master connection" problem
# the hls4ml build's own script already hit and documented. Also disable
# the unused M_AXI_GP1 (HPM1_FPD) master -- left enabled by the board
# preset but connected to nothing, it leaves a dangling clock pin that
# fails validate_bd_design, the same class of issue fixed in the earlier
# minimal (non-DMA) build for its GP0/GP1.
set_property -dict [list \
  CONFIG.PSU__USE__S_AXI_GP2 {1} \
  CONFIG.PSU__USE__S_AXI_GP3 {1} \
  CONFIG.PSU__USE__M_AXI_GP1 {0} \
] [get_bd_cells zynq_ultra_ps_e_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
set_property -dict [list \
  CONFIG.c_include_sg {0} \
  CONFIG.c_sg_include_stscntrl_strm {0} \
  CONFIG.c_m_axis_mm2s_tdata_width {8} \
  CONFIG.c_s_axis_s2mm_tdata_width {8} \
] [get_bd_cells axi_dma_0]

create_bd_cell -type ip -vlnv user.org:user:viterbi_k7_axis:1.0 viterbi_k7_axis_0

connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins viterbi_k7_axis_0/s_axis]
connect_bd_intf_net [get_bd_intf_pins viterbi_k7_axis_0/m_axis] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { \
  Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_FPD} \
  Slave {/axi_dma_0/S_AXI_LITE} \
  intc_ip {Auto} master_apm {0} } [get_bd_intf_pins axi_dma_0/S_AXI_LITE]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { \
  Master {/axi_dma_0/M_AXI_MM2S} \
  Slave {/zynq_ultra_ps_e_0/S_AXI_HP0_FPD} \
  intc_ip {Auto} master_apm {0} } [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { \
  Master {/axi_dma_0/M_AXI_S2MM} \
  Slave {/zynq_ultra_ps_e_0/S_AXI_HP1_FPD} \
  intc_ip {Auto} master_apm {0} } [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP1_FPD]

apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config { Clk {Auto} } [get_bd_pins viterbi_k7_axis_0/clk]

# --- Verify, don't assume, the reset wiring (same bug class caught before:
# automation can pick the active-low peripheral_aresetn for a port whose
# VHDL treats rst='1' as "in reset").
set rst_net [get_bd_nets -of_objects [get_bd_pins viterbi_k7_axis_0/rst]]
set rst_src [get_bd_pins -of_objects $rst_net -filter {DIR == "O"}]
puts "VERIFY (pre-fix): rst net = $rst_net, driven by = $rst_src"
if {[string match "*aresetn*" $rst_src]} {
    set reset_cell [get_bd_cells -of_objects [get_bd_pins $rst_src]]
    disconnect_bd_net $rst_net [get_bd_pins viterbi_k7_axis_0/rst]
    connect_bd_net [get_bd_pins $reset_cell/peripheral_reset] [get_bd_pins viterbi_k7_axis_0/rst]
}
set rst_net2 [get_bd_nets -of_objects [get_bd_pins viterbi_k7_axis_0/rst]]
set rst_src2 [get_bd_pins -of_objects $rst_net2 -filter {DIR == "O"}]
puts "VERIFY (post-fix): rst net = $rst_net2, driven by = $rst_src2"
if {![string match "*peripheral_reset" $rst_src2]} {
    error "Reset fix did not take effect -- rst is driven by $rst_src2, not a peripheral_reset (active-high) pin."
}

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 irq_concat
set_property -dict [list CONFIG.NUM_PORTS {2}] [get_bd_cells irq_concat]
connect_bd_net [get_bd_pins axi_dma_0/mm2s_introut] [get_bd_pins irq_concat/In0]
connect_bd_net [get_bd_pins axi_dma_0/s2mm_introut] [get_bd_pins irq_concat/In1]
connect_bd_net [get_bd_pins irq_concat/dout] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]

validate_bd_design
save_bd_design

make_wrapper -files [get_files ./viterbi_zcu104_axis.srcs/sources_1/bd/viterbi_axis_system/viterbi_axis_system.bd] -top
add_files -norecurse ./viterbi_zcu104_axis.gen/sources_1/bd/viterbi_axis_system/hdl/viterbi_axis_system_wrapper.v
update_compile_order -fileset sources_1

puts "BLOCK_DESIGN_BUILD: complete"
