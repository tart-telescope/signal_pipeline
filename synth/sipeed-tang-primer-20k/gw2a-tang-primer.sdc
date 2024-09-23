create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk_26}]
create_clock -name sig_clock -period 61.095 -waveform {0 30.547} [get_ports {CLK_16}]

create_clock -name ulpi_clk -period 16.667 -waveform {0 8.333} [get_ports {ulpi_clk}]

# set_clock_latency -source 0.4 [get_clocks {ulpi_clk}] 

set_input_delay -max -clock ulpi_clk 3.5 [get_ports {ulpi_data ulpi_dir ulpi_nxt}]
set_input_delay -min -clock ulpi_clk 1.5 [get_ports {ulpi_data ulpi_dir ulpi_nxt}]

set_output_delay -max -clock ulpi_clk 5 [get_ports {ulpi_data ulpi_stp}]
set_output_delay -min -clock ulpi_clk -5 [get_ports {ulpi_data ulpi_stp}]
