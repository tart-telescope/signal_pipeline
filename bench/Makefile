.PHONY:	all build doc sim clean
all:	doc sim

#
#  Icarus Verilog settings
##
IVC	?= iverilog
VERINC	:= ../include/
VEROPT	:= -g2005-sv -D__icarus -Wall -I$(VERINC)

LIBDIR	:= ../lib
AXIS	:= $(wildcard $(LIBDIR)/verilog-axis/rtl/*.v)
USBDIR	:= $(LIBDIR)/axis_usbd/rtl
USB	:= $(wildcard $(USBDIR)/usb/*.v) $(wildcard $(USBDIR)/arch/*.v)

RTLDIR	:= ../rtl
MISC	:= $(wildcard $(RTLDIR)/misc/*.v)
CORR	:= $(wildcard $(RTLDIR)/correlator/*.v)
DDR3	:= $(wildcard $(RTLDIR)/ddr3/*.v)
SIMSRC	:= $(wildcard *.v)
SRC	:= $(filter-out %_tb.v, $(SIMSRC))

VERLIB	:= $(MISC) $(CORR) $(AXIS) $(USB) $(DDR3) $(SRC)

VERTOP	?= $(wildcard *_tb.v)
VEROUT	?= $(VERTOP:%.v=../build/%.out)
VCDOUT	?= ../vcd

sim:	$(VEROUT) build

build:
	echo $(VERINC)
	@mkdir -p $(VCDOUT)

../build/%.out: %.v $(VERLIB)
	$(IVC) $(VEROPT) -o $@ -s $(*F) $^


#
#  Documentation settings
##

# Source Markdown files and PDF outputs:
DIR	:= ../doc
MD	:= $(wildcard *.md)
DOC	:= $(filter-out %.inc.md, $(MD))
PDF	:= $(DOC:.md=.pdf)

# Include-files:
INC	:= $(filter %.inc.md, $(MD))
TMP	?= $(DIR)/tart.latex
CLS	?= $(DIR)/tartreport.cls

# Images:
PNG	:= $(wildcard $(DIR)/images/*.png)
SVG	:= $(wildcard $(DIR)/images/*.svg)
DOT	:= $(wildcard $(DIR)/images/*.dot)
PIC	:= $(SVG:.svg=.pdf) $(DOT:.dot=.pdf)

# Pandoc settings:
FLT	?= --citeproc
OPT	?= --number-sections

doc:	$(PDF) $(PIC) $(PNG) $(INC)

clean:
	rm -f $(PDF) $(LTX) $(PIC)

# Implicit rules:
%.pdf: %.md $(PIC) $(PNG) $(TMP) $(INC)
	+pandoc --template=$(TMP) $(FLT) $(OPT) -f markdown+tex_math_double_backslash -t latex -V papersize:a4 -V geometry:margin=2cm $< -o $@

%.tex: %.md $(PIC) $(PNG) $(TMP)
	+pandoc --filter=pandoc-fignos --filter=pandoc-citeproc --bibliography=$(REF) \
		-f markdown+tex_math_double_backslash -t latex $< -o $@

%.pdf: %.svg
	+inkscape --export-area-drawing --export-text-to-path --export-pdf=$@ $<

%.pdf: %.dot
	+dot -Tpdf -o$@ $<

%.pdf: %.eps
	+inkscape --export-area-drawing --export-text-to-path --export-pdf=$@ $<
