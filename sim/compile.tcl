#!/usr/bin/tclsh

# Source files listed in hierarchical order: bottom -> top
set sourceFiles {
    ../src/MIPS_package.vhd
    ../src/RegisterNbits.vhd
    ../src/RegisterFile.vhd
    ../src/ALU.vhd
    ../src/DataPath.vhd 
    ../src/ControlPath.vhd
    ../src/MIPS_monocycle.vhd
    Util_package.vhd
    Memory.vhd
    MIPS_monocycle_tb.vhd
}

set top MIPS_monocycle_tb

# Compilation, warnings during the analyzing are ignored
if { [llength $sourceFiles] > 0 } {
    foreach file $sourceFiles {
        if {[catch {exec ghdl -a $file} result]} {
        	puts stderr "During analizyng $top : $result"
        }
    }
}

# Elaboration
if {[catch {exec ghdl -e $top} result]} {
    puts stderr "Error elaborating $top: $result"
    exit 1
}

# Simulation with waveform generation
set wavefile "$top.ghw"
if {[catch {exec ghdl -r $top --wave=$wavefile --stop-time=10us} result]} {
    puts stderr "Error simulating $top: $result"
    exit 1
}

puts "Compilation and elaboration successful"
