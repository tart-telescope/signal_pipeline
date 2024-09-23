.PHONY:	all build doc sim clean
all:	doc sim

#
#  Icarus Verilog sources & settings
##

LIBDIR	:= ../lib/misc-verilog-cores
AXIDIR	:= $(LIBDIR)/axis
DDRDIR	:= ../lib/axi-ddr3-lite
USBDIR	:= ../lib/axis-usb

# Various cores & modules
ARCH	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/arch/*.v))
AXIS	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/axis/*.v))
FIFO	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/fifo/*.v))
MISC	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/misc/*.v))
SPI	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/spi/*.v))
UART	:= $(filter-out %_tb.v, $(wildcard $(LIBDIR)/uart/*.v))

#DDR3_V	:= $(wildcard $(DDRDIR)/*.v $(DDRDIR)/arch/*.v $(DDRDIR)/extra/*.v)
DDR3_V	:= $(wildcard $(DDRDIR)/*.v $(DDRDIR)/extra/*.v)
DDR3	:= $(filter-out %_tb.v, $(DDR3_V))

USB_V	:= $(wildcard $(LIBDIR)/usb/*.v)
USB	:= $(filter-out %_tb.v, $(USB_V))

# Correlator cores & testbenches
RTL	:= ../rtl
CORR	:= $(wildcard $(RTL)/correlator/*.v)
VERLIB	:= $(ARCH) $(AXIS) $(CORR) $(DDR3) $(FIFO) $(MISC) $(SPI) $(UART) $(USB)

# Icarus settings
IVC	?= iverilog
VERINC	:= ../include/
VEROPT	:= -g2005-sv -D__icarus -Wall -I$(VERINC) -I$(DDRDIR) -I$(USBDIR) -I$(AXIDIR)

# Testbenches
VERTOP	?= $(wildcard *_tb.v)
VEROUT	?= $(VERTOP:%.v=../build/%.out)
VCDOUT	?= ../vcd

sim:	$(VEROUT) build

build:
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
