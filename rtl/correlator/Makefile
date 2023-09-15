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
CORR	:= $(wildcard *.v)
VERLIB	:= $(filter-out %_tb.v, $(MISC) $(CORR))

VERTOP	:= $(filter %_tb.v, $(CORR))
VEROUT	:= $(VERTOP:%.v=../../build/%.out)
VCDOUT	?= ../../vcd

sim:	$(VEROUT) build

build:
	echo $(VERINC)
	@mkdir -p $(VCDOUT)

../../build/%.out: %.v $(VERLIB)
	$(IVC) $(VEROPT) -o $@ -s $(*F) $^

#
#  Documentation settings
##

# Source Markdown files and PDF outputs:
DIR	:= ../../doc
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
# FLT	?= --filter=pandoc-include --filter=pandoc-fignos --filter=pandoc-citeproc
#OPT	?= --number-sections --bibliography=$(REF)
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
