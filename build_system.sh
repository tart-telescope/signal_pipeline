# docker compose --progress=plain build gowin

pushd lib
./verilog-axis.bash
./misc-verilog-cores.bash
popd

pushd synth/sipeed-tang-primer-20k/

make -f Makefile.gowin GW_SH=/opt/gowin/IDE/bin/gw_sh

popd
