#!/bin/bash
# Use TMP dir to clone
TMP=`mktemp --directory`
pushd ${TMP}
git clone --depth=1 https://github.com/psuggate/misc-verilog-cores.git
cd misc-verilog-cores
git checkout 781dad6696dc2ac72457a7b34538f45d2d30c39e
popd
mkdir -p misc-verilog-cores/sim
cp -a ${TMP}/misc-verilog-cores/bench/arch misc-verilog-cores/sim/
cp -a ${TMP}/misc-verilog-cores/rtl/arch misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/rtl/axis misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/rtl/ddr3 misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/rtl/fifo misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/rtl/misc misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/rtl/spi  misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/rtl/uart misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/rtl/usb misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/rtl/Makefile misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/*.md misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/driver misc-verilog-cores/
echo "removing temp directory ${TMP}"
rm -rf ${TMP}
