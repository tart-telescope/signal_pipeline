#!/bin/bash
# Use TMP dir to clone
TMP=`mktemp --directory`
pushd ${TMP}
git clone https://github.com/alexforencich/verilog-axis.git
popd
cp -a ${TMP}/verilog-axis/rtl verilog-axis/
echo "removing temp directory ${TMP}"
rm -rf ${TMP}
