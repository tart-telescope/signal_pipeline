//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.11 Education
//Created Time: 2023-09-19 13:55:30
create_clock -name CLK_16 -period 61.095 -waveform {0 5} [get_ports {CLK_16}] -add
