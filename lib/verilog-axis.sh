#!/bin/bash
# Use TMP dir to clone
TMP=`mktemp --directory`
cd ${TMP}
git clone https://github.com/alexforencich/verilog-axis.git
cp -a ${TMP}/verilog-axis/rtl verilog-axis/
rm -rf ${TMP}
