.PHONY:	all build doc sim clean
all:	doc sim

#
#  Icarus Verilog settings
##
IVC	?= iverilog
VERINC	:= ../../include/
VEROPT	:= -g2005-sv -D__icarus -Wall -I$(VERINC)

RTL	:= ..
MISC	:= $(wildcard $(RTL)/misc/*.v)
VERLIB	:= $(filter-out %_tb.v, $(MISC))

VERTOP	:= $(filter %_tb.v, .)
VEROUT	:= $(VERTOP:%.v=../../build/%.out)
VCDOUT	?= ../../vcd

sim:
	iverilog radio.v radio_all_tb.v

build:
	echo $(VERINC)
	@mkdir -p $(VCDOUT)

../../build/%.out: %.v $(VERLIB)
	$(IVC) $(VEROPT) -o $@ -s $(*F) $^
