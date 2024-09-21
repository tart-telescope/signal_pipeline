#!/bin/bash
# Use TMP dir to clone
TMP=`mktemp --directory`
pushd ${TMP}
git clone --depth=1 https://github.com/psuggate/misc-verilog-cores.git
cd misc-verilog-cores
git checkout 4c85a3051c88b1aa3ccfdd3ffbfda6ff63334f00
popd
mkdir -p misc-verilog-cores
cp -a ${TMP}/misc-verilog-cores/rtl/* misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/*.md misc-verilog-cores/
cp -a ${TMP}/misc-verilog-cores/driver misc-verilog-cores/
echo "removing temp directory ${TMP}"
rm -rf ${TMP}
