set_global_assignment -entity "pll01" -library "lib_pll01" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "pll01" -library "lib_pll01" -name IP_TOOL_VERSION "25.1"
set_global_assignment -entity "pll01" -library "lib_pll01" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_pll01" -name SPD_FILE [file join $::quartus(sip_path) "pll01.spd"]

set_global_assignment -library "lib_pll01" -name MISC_FILE [file join $::quartus(sip_path) "pll01_sim/pll01.vo"]
