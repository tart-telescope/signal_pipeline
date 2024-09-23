#!/bin/bash
# Use TMP dir to clone
TMP=`mktemp --directory`
pushd ${TMP}
git clone --depth=1 https://github.com/psuggate/axi-ddr3-lite.git
cd axi-ddr3-lite
git checkout a0dbd662c0188036655f05caa7dc0cfc33c5006c
popd
mkdir -p axi-ddr3-lite
cp -a ${TMP}/axi-ddr3-lite/rtl/* axi-ddr3-lite/
cp -a ${TMP}/axi-ddr3-lite/*.md axi-ddr3-lite/
echo "removing temp directory ${TMP}"
rm -rf ${TMP}
