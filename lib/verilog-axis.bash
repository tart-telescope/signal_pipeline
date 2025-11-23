#!/bin/bash
# Use TMP dir to clone
TMP=`mktemp --directory`
pushd ${TMP}
git clone https://github.com/alexforencich/verilog-axis.git
# git clone --depth=1 https://github.com/alexforencich/verilog-axis.git
cd verilog-axis
git checkout 7823b916bfd298441d5fdabf0b03d0ae8dc210e8
popd
mkdir -p verilog-axis
cp -a ${TMP}/verilog-axis/rtl verilog-axis/
echo "removing temp directory ${TMP}"
rm -rf ${TMP}
