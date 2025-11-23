.PHONY:	all sim build clean

#
#  Icarus Verilog settings
##
LIBDIR	:= ../../lib/misc-verilog-cores

IVC	?= iverilog
OPT	:= -g2005-sv -D__icarus -Wall -I$(LIBDIR)/usb/

# Various cores & modules
ARCH	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/arch/*.v) $(LIBDIR)/sim/arch/*.v)
AXIS	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/axis/*.v))
FIFO	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/fifo/*.v))
MISC	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/misc/*.v))
SPI	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/spi/*.v))
USB	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/usb/*.v))

DIR	:= ../../rtl
CORR	:= $(wildcard $(DIR)/correlator/*.v)
RADIO	:= $(filter-out %_tb.v, $(wildcard $(DIR)/radio/*.v))

# LIB	:= $(filter-out %_tb.v, $(ARCH) $(AXIS) $(CORR) $(RADIO) $(FIFO) $(MISC) $(SPI) $(USB))
LIB	:= $(ARCH) $(AXIS) $(CORR) $(RADIO) $(FIFO) $(MISC) $(SPI) $(USB)

SRC	:= $(wildcard *.v)
RTL	:= $(filter-out %_tb.v, $(SRC) $(LIB))
BENCH	?= $(filter %_tb.v, $(SRC))
OUT	?= $(BENCH:%.v=../../build/%.out)

all:	build

sim:	build
	@make -C ../../build sim

clean:
	@echo "$(RTL)"
	@rm -f $(OUT)

build:	$(OUT)
	@echo "$(LIB)"

../../build/%.out: %.v $(RTL)
	$(IVC) $(OPT) -o $@ -s $(*F) $^
