#!/bin/bash
# Use TMP dir to clone
TMP=`mktemp --directory`
pushd ${TMP}
git clone https://github.com/psuggate/misc-verilog-cores.git
cd misc-verilog-cores
git checkout 4f01a9b041a01cf5c44a80069ab5963eaada6bb4
popd
cp -a ${TMP}/misc-verilog-cores/rtl misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/*.md misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/driver misc-verilog-cores/
echo "removing temp directory ${TMP}"
rm -rf ${TMP}
