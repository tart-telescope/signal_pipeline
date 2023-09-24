.PHONY:	all build clean
all:	build

#
#  Icarus Verilog settings
##
IVC	?= iverilog
OPT	:= -g2005-sv -D__icarus -Wall

DIR	:= ../../rtl
ARCH	:= $(wildcard $(DIR)/arch/*.v)
CORR	:= $(wildcard $(DIR)/correlator/*.v)
MISC	:= $(wildcard $(DIR)/misc/*.v)
SPI	:= $(wildcard $(DIR)/spi/*.v)
USB	:= $(wildcard $(DIR)/usb/*.v)

AXIS	:= $(wildcard ../../lib/verilog-axis/rtl/*.v)
LIB	:= $(ARCH) $(CORR) $(MISC) $(SPI) $(USB) $(AXIS)

SRC	:= $(wildcard *.v)
RTL	:= $(filter-out %_tb.v, $(SRC)) $(LIB)
BENCH	:= $(filter %_tb.v, $(SRC))
OUT	:= $(BENCH:%.v=../../build/%.out)

build:	$(OUT)

../../build/%.out: %.v $(RTL)
	$(IVC) $(OPT) -o $@ -s $(*F) $^
