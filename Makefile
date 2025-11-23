.PHONY:	all sim docker gowin ide doc diagrams clean
all:
	@make -C generator all
	@make -C bench all
	@make -C rtl all
	@make -C synth all

sim:
	@make -C rtl/correlator sim
	@make -C synth sim
	@make -C build sim

# Settings for building the Docker image:
UID	:= `id -u $(USER)`
GID	:= `id -g $(USER)`
ARGS	:= --build-arg USERNAME=$(USER) --build-arg USER_UID=$(UID) --build-arg

# Settings for running Gowin synthesis within the Docker image:
USERDIR	:= /home/$(USER)/:/home/$(USER):rw
PASSWD	:= /etc/passwd:/etc/passwd:ro
GROUP	:= /etc/group:/etc/group:ro
VOLUMES	:= -v `pwd`:/build/signal_pipeline:rw -v $(PASSWD) -v $(GROUP) -v $(USERDIR)
TOPDIR	:= /build/signal_pipeline/synth/sipeed-tang-primer-20k
MAKE	:= make -f gowin.mk GW_SH=/opt/gowin/IDE/bin/gw_sh

docker:
	@docker build -f Dockerfile.gowin $(ARGS) USER_GID=$(GID) -t gowin-eda:latest .

gowin:	docker
	@docker run $(VOLUMES) -e USER=$(USER) --user=$(UID):$(GID) -w=$(TOPDIR) \
--rm -it gowin-eda bash -c "$(MAKE)"

synth:	docker
	@docker run $(VOLUMES) -e USER=$(USER) --user=$(UID):$(GID) -w=$(TOPDIR) \
--rm -it gowin-eda bash

# Todo: does not work, yet ...
ide:
	@scripts/docker-gowin-ide.sh

SYNDIR	:= `pwd`/synth/sipeed-tang-primer-20k
BIT	:= $(SYNDIR)/impl/pnr/project.fs
flash:	gowin
	openFPGALoader --board tangprimer20k --write-sram $(BIT)

#
#  Documentation settings
##

# Source Markdown files and PDF outputs:
MD	:= $(wildcard *.md)
DOC	:= $(filter-out %.inc.md, $(MD))
PDF	:= $(DOC:.md=.pdf)

# Include-files:
INC	:= $(filter %.inc.md, $(MD))
TMP	?= doc/tart.latex
CLS	?= doc/tartreport.cls

# Images:
PNG	:= $(wildcard doc/images/*.png)
SVG	:= $(wildcard doc/images/*.svg)
DOT	:= $(wildcard doc/images/*.dot)
PIC	:= $(SVG:.svg=.pdf) $(DOT:.dot=.pdf)

BOX_RAW	:= $(wildcard doc/diagrams/*.box)

# Pandoc settings:
FLT	?= --citeproc
# FLT	?= --filter=pandoc-include --filter=pandoc-fignos --filter=pandoc-citeproc
#OPT	?= --number-sections --bibliography=$(REF)
OPT	?= --number-sections

diagrams:
	@make -C doc/diagrams all

doc:	$(PDF) $(PIC) $(PNG) $(INC) diagrams
	@make -C bench doc
	@make -C generator doc
	@make -C rtl doc
	@make -C synth doc

clean:
	@rm -f synth/sipeed-tang-primer-20k/toy-tart.tcl
	rm -f $(PDF) $(LTX) $(PIC)

# Implicit rules:
%.pdf: %.md $(PIC) $(PNG) $(TMP) $(INC) diagrams
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
