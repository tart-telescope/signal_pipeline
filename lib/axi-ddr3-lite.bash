#!/bin/bash
# Use TMP dir to clone
TMP=`mktemp --directory`
pushd ${TMP}
git clone --depth=1 https://github.com/psuggate/axi-ddr3-lite.git
cd axi-ddr3-lite
git checkout 7d161ae3cd79ae35461b2de4b9c954e7cff31fe6
popd
mkdir -p axi-ddr3-lite
cp -a ${TMP}/axi-ddr3-lite/rtl/* axi-ddr3-lite/
cp -a ${TMP}/axi-ddr3-lite/*.md axi-ddr3-lite/
echo "removing temp directory ${TMP}"
rm -rf ${TMP}
