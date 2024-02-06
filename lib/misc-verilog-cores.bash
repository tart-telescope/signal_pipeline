#!/bin/bash
# Use TMP dir to clone
TMP=`mktemp --directory`
pushd ${TMP}
git clone https://github.com/psuggate/misc-verilog-cores.git
cd misc-verilog-cores
git checkout b3b56d831f3f256c2c62a650bddd8340e7a66dd5
popd
cp -a ${TMP}/misc-verilog-cores/rtl misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/*.md misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/driver misc-verilog-cores/
echo "removing temp directory ${TMP}"
rm -rf ${TMP}
