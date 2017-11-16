#!/bin/sh

set -x

cd oic-sample 
rm -rf iotivity
git clone -b 1.1.1_android_darwin https://github.com/runtimeco/iotivity
cd iotivity
git clone https://github.com/01org/tinycbor.git extlibs/tinycbor/tinycbor
cd extlibs/tinycbor/tinycbor
git checkout 47a78569c0
cd ../../..
ln -s out/ios ios
tools/darwin/build-ios.sh
tools/darwin/mkfwk_ios.sh 
