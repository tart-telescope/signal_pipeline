#!/bin/bash
# Use TMP dir to clone
TMP=`mktemp --directory`
pushd ${TMP}
git clone --depth=1 https://github.com/psuggate/misc-verilog-cores.git
cd misc-verilog-cores
git checkout 4c60fee3a40dbcedb835e06663c41ea02c4abfc2
popd
mkdir -p misc-verilog-cores
cp -a ${TMP}/misc-verilog-cores/rtl/* misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/*.md misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/driver misc-verilog-cores/
echo "removing temp directory ${TMP}"
rm -rf ${TMP}
