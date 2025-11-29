PROJECT  := toy-tart
TOP      := top
FAMILY   := GW2A-18C
DEVICE   := GW2A-LV18PG256C8/I7
CST	 := gw2a-tang-primer.cst
SDC	 := gw2a-tang-primer.sdc
GW_SH	 := /opt/gowin/IDE/bin/gw_sh

VROOT 	 := $(dir $(abspath $(CURDIR)/..))
RTL	 = $(VROOT)/rtl
LIB	 = $(VROOT)/lib/misc-verilog-cores
BENCH	 = $(VROOT)/bench
AXIDIR	:= $(VROOT)/lib/verilog-axi

# Library cores and sources
AXIS_V	:= $(filter-out %_tb.v, $(wildcard $(LIB)/axis/*.v))
DDR3_V	:= $(filter-out %_tb.v, $(wildcard $(LIB)/ddr3/*.v))
FIFO_V	:= $(filter-out %_tb.v, $(wildcard $(LIB)/fifo/*.v))
MISC_V	:= $(filter-out %_tb.v, $(wildcard $(LIB)/misc/*.v))
SPI_V	:= $(filter-out %_tb.v, $(wildcard $(LIB)/spi/*.v))
UART_V	:= $(filter-out %_tb.v, $(wildcard $(LIB)/uart/*.v))
USB_V	:= $(filter-out %_tb.v, $(wildcard $(LIB)/usb/*.v))

# Pick a few more from Alex Forencich's libraries
AXI_V	:= $(AXIDIR)/priority_encoder.v $(AXIDIR)/axi_register_wr.v \
	$(AXIDIR)/axi_crossbar_wr.v $(AXIDIR)/axi_crossbar_addr.v \
	$(AXIDIR)/arbiter.v \

VERLIB	:= $(AXIS_V) $(DDR3_V) $(FIFO_V) $(MISC_V) $(SPI_V) $(UART_V) $(USB_V) $(AXI_V)

# TART and architecture-specific sources
ARCH_V	:= $(filter-out %_tb.v, $(wildcard $(LIB)/arch/*.v))
CORR_V	:= $(filter-out %_tb.v, $(wildcard $(RTL)/correlator/*.v))
TART_V	:= $(filter-out %_tb.v, $(wildcard *.v))

SOURCES	:= \
	$(ARCH_V) $(TART_V) $(CORR_V) \
	${RTL}/radio/radio.v \
	${RTL}/radio/radio_dummy.v \
	${RTL}/tart/acquire.v \
	${RTL}/tart/controller.v \
	$(VERLIB)

gowin_build: impl/pnr/project.fs

$(PROJECT).tcl: $(SOURCES)
	@echo ${SOURCES}
	@echo "set_device -name $(FAMILY) $(DEVICE)" > $(PROJECT).tcl
	@for VAR in $^; do echo $$VAR | grep -s -q "\.v$$" && echo "add_file $$VAR" >> $(PROJECT).tcl; done
	@echo "add_file ${CST}" >> $(PROJECT).tcl
	@echo "add_file ${SDC}" >> $(PROJECT).tcl
	@echo "set_option -include_path $(LIB)/axis/" >> $(PROJECT).tcl
	@echo "set_option -include_path $(LIB)/ddr3/" >> $(PROJECT).tcl
	@echo "set_option -include_path $(LIB)/usb/" >> $(PROJECT).tcl
	@echo "set_option -top_module $(TOP)" >> $(PROJECT).tcl
	@echo "set_option -verilog_std sysv2017" >> $(PROJECT).tcl
	@echo "set_option -vhdl_std vhd2008" >> $(PROJECT).tcl
	@echo "set_option -use_sspi_as_gpio 1" >> $(PROJECT).tcl
	@echo "set_option -use_mspi_as_gpio 1" >> $(PROJECT).tcl
	@echo "set_option -use_done_as_gpio 1" >> $(PROJECT).tcl
	@echo "set_option -use_ready_as_gpio 1" >> $(PROJECT).tcl
	@echo "set_option -use_reconfign_as_gpio 1" >> $(PROJECT).tcl
	@echo "set_option -use_i2c_as_gpio 1" >> $(PROJECT).tcl
	@echo "run all" >> $(PROJECT).tcl

impl/pnr/project.fs: $(PROJECT).tcl
	${GW_SH} $(PROJECT).tcl

gowin_load: impl/pnr/project.fs
	openFPGALoader --board tangprimer20k --write-sram impl/pnr/project.fs

clean:
	rm -rf $(PROJECT).tcl impl
