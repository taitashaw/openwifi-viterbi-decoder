connect -url tcp:127.0.0.1:3121
after 500
puts "CONNECTED"; flush stdout

targets -set -filter {name =~ "Cortex-A53 #0*"}
rst -processor -clear-registers
puts "A53_RESET_FOR_FSBL: done"; flush stdout
after 200

dow /home/jotshawlinux/Downloads/openwifi-viterbi-decoder/vivado_proj/vitis_ws/viterbi_platform/zynqmp_fsbl/build/fsbl.elf
con
after 15000

stop
puts "A53_STOPPED_AFTER_FSBL"; flush stdout
after 200

puts "=== register dump after FSBL, before app ==="
catch {puts [rrd]} e1
puts "err1: $e1"
flush stdout

puts "=== explicit EL-related regs ==="
foreach r {pc sp CurrentEL SCR_EL3 SPSR_EL3 ELR_EL3 CPSR cpsr} {
    catch {puts "$r = [rrd $r]"} e
}
flush stdout

targets -set -filter {name =~ "Cortex-A53 #0*"}
rst -processor -clear-registers
puts "A53_RESET_FOR_APP: done"; flush stdout
after 200

puts "=== register dump right after reset, BEFORE dow app ==="
catch {puts [rrd]} e2
puts "err2: $e2"
flush stdout

puts "=== explicit EL-related regs after reset ==="
foreach r {pc sp CurrentEL SCR_EL3 SPSR_EL3 ELR_EL3 CPSR cpsr} {
    catch {puts "$r = [rrd $r]"} e
}
flush stdout

puts "END"; flush stdout
