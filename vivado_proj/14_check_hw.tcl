# Pure connectivity check: is there a real, powered, JTAG-reachable target
# right now. Does not touch the design or require a bitstream, just queries
# whatever IDCODE responds on the chain. A USB device being visible to the
# OS does not mean the board itself is powered (the FTDI JTAG/UART chip on
# a ZCU104 is USB-bus-powered independent of the board's own power rails),
# so this has to actually attempt the connection, not infer from lsusb.
open_hw_manager
set connect_ok [catch {connect_hw_server} connect_err]
if {$connect_ok == 0} { puts "HW_SERVER_CONNECT: OK" } else { puts "HW_SERVER_CONNECT: FAILED: $connect_err" }

set targets_ok [catch {set targets [get_hw_targets]} targets_err]
if {$targets_ok == 0} {
    puts "HW_TARGETS: $targets"
    if {[llength $targets] > 0} {
        set open_ok [catch {open_hw_target} open_err]
        if {$open_ok == 0} {
            puts "HW_TARGET_OPEN: OK"
            set devices [get_hw_devices]
            puts "HW_DEVICES: $devices"
            puts "HW_CHECK_RESULT: BOARD_PRESENT"
        } else {
            puts "HW_TARGET_OPEN: FAILED: $open_err"
            puts "HW_CHECK_RESULT: NO_BOARD"
        }
    } else {
        puts "HW_CHECK_RESULT: NO_TARGETS"
    }
} else {
    puts "HW_TARGETS: FAILED: $targets_err"
    puts "HW_CHECK_RESULT: NO_TARGETS"
}
