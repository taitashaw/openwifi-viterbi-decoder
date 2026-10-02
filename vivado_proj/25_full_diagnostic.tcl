proc masked_write {addr mask value} {
    set cur "0x[string range [mrd -force $addr] end-8 end]"
    set newval [expr {($cur & ~$mask) | ($value & $mask)}]
    mwr -force $addr [format 0x%08x $newval]
}

connect -url tcp:127.0.0.1:3121
after 1000
puts "CONNECTED"; flush stdout

targets -set -filter {name =~ "PSU"}
masked_write 0xFFD80118 0x00800000 0x00800000
masked_write 0xFFD80120 0x00800000 0x00800000
set count 0
while {1} {
    set st "0x[string range [mrd -force 0xFFD80110] end-8 end]"
    if {($st & 0x00800000) == 0} { break }
    incr count
    if {$count > 200} { break }
    after 10
}
puts "ISOLATION_REMOVED: status=$st tries=$count"; flush stdout

masked_write 0xFF0A002C 0xFFFF0000 0x80000000
masked_write 0xFF0A0344 0xFFFFFFFF 0x80000000
masked_write 0xFF0A0348 0xFFFFFFFF 0x80000000
masked_write 0xFF0A0054 0xFFFFFFFF 0x80000000
after 50
masked_write 0xFF0A0054 0xFFFFFFFF 0x00000000
after 50
masked_write 0xFF0A0054 0xFFFFFFFF 0x80000000
puts "FABRIC_RESET_RELEASED"; flush stdout
after 500

targets -set -filter {name =~ "PSU"}
rst -system
puts "SYSTEM_RESET: done"; flush stdout
after 1500

targets -set -filter {name =~ "Cortex-A53 #0*"}
rst -processor -clear-registers
puts "A53_RESET_FOR_FSBL: done"; flush stdout
after 200

dow /home/jotshawlinux/Downloads/openwifi-viterbi-decoder/vivado_proj/vitis_ws/viterbi_platform/zynqmp_fsbl/build/fsbl.elf
con
puts "FSBL_RUNNING: done"; flush stdout
after 15000

stop
puts "A53_STOPPED_AFTER_FSBL"; flush stdout
after 200

puts "=== EL/register state after FSBL, core halted ==="
foreach r {pc sp CurrentEL cpsr CPSR SCR_EL3 SPSR_EL3 ELR_EL3} {
    catch {puts "$r = [rrd $r]"} e
    if {[info exists e]} { }
}
flush stdout
catch {puts "full rrd: [rrd]"} e3
flush stdout

targets -set -filter {name =~ "Cortex-A53 #0*"}
rst -processor -clear-registers
puts "A53_RESET_FOR_HELLO: done"; flush stdout
after 200

puts "=== EL/register state immediately after reset, BEFORE dow ==="
foreach r {pc sp CurrentEL cpsr CPSR} {
    catch {puts "$r = [rrd $r]"} e
}
flush stdout

dow /home/jotshawlinux/Downloads/openwifi-viterbi-decoder/vivado_proj/vitis_ws/hello_test/build/hello_test.elf
puts "HELLO_DOWNLOAD: done"; flush stdout

con
puts "HELLO_RUNNING: done"; flush stdout
after 3000

stop
puts "HELLO_STOPPED: done (if this prints, halt succeeded after a trivial app too)"; flush stdout
after 200

puts "=== register state after hello app ==="
catch {puts "full rrd: [rrd]"} e4
flush stdout

puts "ALL_DONE"; flush stdout
