#!/bin/bash
# Use TMP dir to clone
TMP=`mktemp --directory`
pushd ${TMP}
git clone --depth=1 https://github.com/psuggate/axis-usb.git
cd axis-usb
git checkout 1a74de5eb868cff06d9c50ec253c8ed74c7968c8
popd
mkdir -p axis-usb
cp -a ${TMP}/axis-usb/rtl/* axis-usb/
cp -a ${TMP}/axis-usb/driver axis-usb/
cp -a ${TMP}/axis-usb/vpi axis-usb/
cp -a ${TMP}/axis-usb/*.md axis-usb/
echo "removing temp directory ${TMP}"
rm -rf ${TMP}
