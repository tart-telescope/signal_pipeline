FROM debian:trixie
MAINTAINER Tim Molteno "tim@elec.ac.nz"
ARG DEBIAN_FRONTEND=noninteractive

# debian setup
RUN apt-get update -y && apt-get install -y \
    iverilog build-essential pandoc rustc cargo

RUN apt-get install -y inkscape
RUN apt-get install -y make

RUN rm -rf /var/lib/apt/lists/*

COPY . /build/
WORKDIR /build
RUN ls -al
RUN make

CMD ["openFPGALoader --board tangprimer20k --write-flash impl/pnr/dummy.fs"]
