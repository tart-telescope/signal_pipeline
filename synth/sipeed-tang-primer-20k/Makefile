.PHONY:	all build clean
all:	build

#
#  Icarus Verilog settings
##

LIBDIR	:= ../../lib/misc-verilog-cores

# Various cores & modules
ARCH	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/arch/*.v))
AXIS	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/axis/*.v))
FIFO	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/fifo/*.v))
MISC	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/misc/*.v))
SPI	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/spi/*.v))
USB	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/usb/*.v))

DIR	:= ../../rtl
CORR	:= $(wildcard $(DIR)/correlator/*.v)

LIB	:= $(ARCH) $(AXIS) $(CORR) $(FIFO) $(MISC) $(SPI) $(USB)

SRC	:= $(wildcard *.v)
RTL	:= $(filter-out %_tb.v, $(SRC)) $(LIB)
BENCH	:= $(filter %_tb.v, $(SRC))
OUT	:= $(BENCH:%.v=../../build/%.out)

IVC	?= iverilog
OPT	:= -g2005-sv -D__icarus -Wall -I$(LIBDIR)/usb/

build:	$(OUT)

../../build/%.out: %.v $(RTL)
	$(IVC) $(OPT) -o $@ -s $(*F) $^
