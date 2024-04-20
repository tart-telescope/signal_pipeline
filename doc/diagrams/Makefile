.PHONY:	all clean

DOT	:= $(wildcard *.dot)
SVG	:= $(wildcard *.svg)

BOX_RAW	:= $(wildcard *.box)
LIB	:= $(filter %_lib.box, $(BOX_RAW))
BOX	:= $(filter-out %_lib.box, $(BOX_RAW))

PDF	:= $(BOX:.box=.pdf) $(DOT:.dot=.pdf)

all: $(PDF)

clean:
	rm -rf $(EPS) $(PDF)

%.pdf: %.dot
	dot -Tpdf -o $@ $<

%.pdf: %.box $(LIB)
	box -l g -I . $<

%.pdf:	%.svg
	+inkscape --export-area-drawing --export-text-to-path --export-pdf=$@ $<
