#!/bin/bash
#
# Todo: Not sure why I can not run GW_IDE under Wayland or Xorg.
#
export WAYLAND_SRC=$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY
export WAYLAND_DST=/home/$USER/tmp/$WAYLAND_DISPLAY
export QT_PLUGIN_PATH=/lib/x86_64-linux-gnu/qt5/plugins
export LD_PRELOAD=/lib/x86_64-linux-gnu/libfreetype.so.6
echo "DISPLAY=$DISPLAY"

docker run -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro \
       -v /home/$USER/:/home/$USER:rw -v /dev/dri:/dev/dri:rw \
       -v $WAYLAND_SRC:/$WAYLAND_DST:rw --device /dev/dri -e USER=$USER \
       -e QT_PLUGIN_PATH=$QT_PLUGIN_PATH -e WAYLAND_DISPLAY=$WAYLAND_DISPLAY \
       -e QT_QPA_PLATFORM=wayland -e XDG_RUNTIME_DIR=/home/$USER/tmp \
       -e LD_PRELOAD=$LD_PRELOAD --user=`id -u $USER`:`id -g $USER` \
       -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
       --rm -it gowin-eda /bin/dbus-run-session -- /bin/bash
