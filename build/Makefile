.PHONY:	sim all clean
all:	sim

OUT	:= $(wildcard *_tb.out)
VCD	:= $(OUT:%.out=../vcd/%.vcd)

sim:	$(VCD)

../vcd/%.vcd: %.out
	./$<
