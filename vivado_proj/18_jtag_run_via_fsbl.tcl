proc masked_write {addr mask value} {
    set cur "0x[string range [mrd -force $addr] end-8 end]"
    set newval [expr {($cur & ~$mask) | ($value & $mask)}]
    mwr -force $addr [format 0x%08x $newval]
}

connect -url tcp:127.0.0.1:3121
after 1000
puts "CONNECTED"; flush stdout

targets -set -filter {name =~ "PSU"}

puts "=== PS-PL isolation removal (real regs from this design's psu_init.c) ==="
masked_write 0xFFD80118 0x00800000 0x00800000
masked_write 0xFFD80120 0x00800000 0x00800000
set count 0
while {1} {
    set st "0x[string range [mrd -force 0xFFD80110] end-8 end]"
    if {($st & 0x00800000) == 0} { break }
    incr count
    if {$count > 200} { puts "ISOLATION_POLL: gave up after 200 tries"; break }
    after 10
}
puts "ISOLATION_REMOVED: status=$st tries=$count"; flush stdout

puts "=== PL fabric reset release (GPIO bank5 EMIO bit31, real regs from this design) ==="
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
puts "FSBL_DOWNLOAD: done"; flush stdout

con
puts "FSBL_RUNNING: done"; flush stdout

after 15000
puts "FSBL_WAIT_DONE"; flush stdout

stop
puts "A53_STOPPED_AFTER_FSBL"; flush stdout

targets -set -filter {name =~ "Cortex-A53 #0*"}
rst -processor -clear-registers
puts "A53_RESET_FOR_APP: done"; flush stdout
after 200

dow /home/jotshawlinux/Downloads/openwifi-viterbi-decoder/vivado_proj/vitis_ws/viterbi_hw_test/build/viterbi_hw_test.elf
puts "APP_DOWNLOAD: done"; flush stdout

con
puts "APP_RUNNING: done"; flush stdout

after 3000

stop
puts "APP_STOPPED"; flush stdout
after 200

puts "=== RX buffer @0x02100000 (expect 7a fc 8a, if PASS) ==="
catch {puts [mrd -force -bin 0x02100000 4]} rx_err
puts "rx_err: $rx_err"
flush stdout

puts "=== TX buffer @0x02000000 (first 8 bytes, expect 50 8c 98 90 3c 14 d0 d4) ==="
catch {puts [mrd -force -bin 0x02000000 8]} tx_err
puts "tx_err: $tx_err"
flush stdout

puts "ALL_DONE"; flush stdout
