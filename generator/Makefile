.PHONY:	all doc build run clean
all:	run build build/gen doc

#
#  Generator settings
##

# Build sources and artifacts
SRCS	= $(wildcard src/*.c)
OBJS	= $(SRCS:src/%.c=build/%.o)

SOURCES	?= 8
CORRELS ?= 4

run:	build build/gen
	./build/gen $(SOURCES) $(CORRELS)

build/gen:	$(OBJS)
	+gcc $^ -lm -o $@

build:
	@mkdir -p build

build/%.o: src/%.c
	+gcc -c $< -o $@


#
#  Documentation settings
##

# Source Markdown files and PDF outputs:
MD	:= $(wildcard *.md)
DOC	:= $(filter-out %.inc.md, $(MD))
PDF	:= $(DOC:.md=.pdf)

# Include-files:
INC	:= $(filter %.inc.md, $(MD))
TMP	?= /home/patrick/texmf/tex/latex/consult.latex
CLS	?= /home/patrick/texmf/tex/latex/consultreport.cls

# Images:
PNG	:= $(wildcard doc/images/*.png)
SVG	:= $(wildcard doc/images/*.svg)
DOT	:= $(wildcard doc/images/*.dot)
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
