FROM debian:bookworm
MAINTAINER Tim Molteno "tim@elec.ac.nz"
ARG DEBIAN_FRONTEND=noninteractive

# debian setup
RUN apt-get update -y && apt-get install -y \
    iverilog build-essential rustc cargo \
    inkscape pandoc-sidenote pandoc-citeproc-preamble \
    texlive-latex-recommended

RUN apt-get install -y texlive-luatex
RUN apt-get install -y git texlive-science
RUN apt-get install -y autotools-dev
RUN apt-get install -y libtool automake libcairo2-dev
RUN apt-get install -y bison libfl-dev docbook-to-man

RUN rm -rf /var/lib/apt/lists/*


#########################################################################################
##
## Install the weird box diagram language from sourceforge
##
#########################################################################################

WORKDIR /box
RUN git clone https://git.code.sf.net/p/boxc/code boxc-code
WORKDIR /box/boxc-code/box

# Do libtool stuff.
RUN libtoolize --ltdl
RUN aclocal -I ./m4 -I libltdl/m4
RUN autoconf
RUN autoupdate
RUN autoheader
RUN automake --add-missing

# Confiture and Make
RUN ./configure  --with-cairo
RUN make
RUN make install

#########################################################################################
#
###################   Now build the signal signal_pipeline ##############################
#
#########################################################################################
WORKDIR /build
RUN ls
RUN git clone --recurse-submodules https://github.com/tart-telescope/signal_pipeline.git

WORKDIR /build/signal_pipeline
RUN ls -al
RUN make

CMD ["openFPGALoader --board tangprimer20k --write-flash impl/pnr/dummy.fs"]
