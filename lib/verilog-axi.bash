#!/bin/bash
# Use TMP dir to clone
TMP=`mktemp --directory`
pushd ${TMP}
git clone https://github.com/alexforencich/verilog-axi.git
cd verilog-axi
git checkout 38915fb5330cb8270b454afc0140a94489dc56db
popd
mkdir -p verilog-axi
cp -a ${TMP}/verilog-axi/rtl/* verilog-axi/
echo "removing temp directory ${TMP}"
rm -rf ${TMP}
