#!/bin/bash

cat <<'EOF' > ../usr/bin/prun
#!/bin/bash
varname=$(basename $PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/*)
pd login debian --user $varname --shared-tmp -- env DISPLAY=:1.0 $@

EOF
chmod +x ../usr/bin/prun

#cp2menu utility ... Allows copying of Debian proot desktop menu items into Termux xfce menu to allow for launching programs from Debian proot from within the xfce menu rather than launching from terminal. 

cat <<'EOF' > $PREFIX/bin/cp2menu
#!/bin/bash

cd

user_dir="$PREFIX/var/lib/proot-distro/installed-rootfs/debian/home/"

# Get the username from the user directory
username=$(basename "$user_dir"/*)

action=$(zenity --list --title="Choose Action" --text="Select an action:" --radiolist --column="" --column="Action" TRUE "Copy .desktop file" FALSE "Remove .desktop file")

if [[ -z $action ]]; then
  zenity --info --text="No action selected. Quitting..." --title="Operation Cancelled"
  exit 0
fi

if [[ $action == "Copy .desktop file" ]]; then
  selected_file=$(zenity --file-selection --title="Select .desktop File" --file-filter="*.desktop" --filename="$PREFIX/var/lib/proot-distro/installed-rootfs/debian/usr/share/applications")

  if [[ -z $selected_file ]]; then
    zenity --info --text="No file selected. Quitting..." --title="Operation Cancelled"
    exit 0
  fi

  desktop_filename=$(basename "$selected_file")

  cp "$selected_file" "$PREFIX/share/applications/"
  sed -i "s/^Exec=\(.*\)$/Exec=pd login debian --user $username --shared-tmp -- env DISPLAY=:1.0 \1/" "$PREFIX/share/applications/$desktop_filename"

  zenity --info --text="Operation completed successfully!" --title="Success"
elif [[ $action == "Remove .desktop file" ]]; then
  selected_file=$(zenity --file-selection --title="Select .desktop File to Remove" --file-filter="*.desktop" --filename="$PREFIX/share/applications")

  if [[ -z $selected_file ]]; then
    zenity --info --text="No file selected for removal. Quitting..." --title="Operation Cancelled"
    exit 0
  fi

  desktop_filename=$(basename "$selected_file")

  rm "$selected_file"

  zenity --info --text="File '$desktop_filename' has been removed successfully!" --title="Success"
fi

EOF
chmod +x $PREFIX/bin/cp2menu

echo "[Desktop Entry]
Version=1.0
Type=Application
Name=cp2menu
Comment=
Exec=cp2menu
Icon=edit-move
Categories=System;
Path=
Terminal=false
StartupNotify=false
" > $PREFIX/share/applications/cp2menu.desktop 
chmod +x $PREFIX/share/applications/cp2menu.desktop 

#App Installer Utility .. For installing additional applications not available in Termux or Debian proot repositories. 

git clone https://github.com/phoenixbyrd/App-Installer.git
mv $HOME/App-Installer $HOME/.App-Installer
chmod +x $HOME/.App-Installer/*

echo "[Desktop Entry]
Version=1.0
Type=Application
Name=App Installer
Comment=
Exec=/data/data/com.termux/files/home/.App-Installer/app-installer
Icon=package-install
Categories=System;
Path=
Terminal=false
StartupNotify=false
" > $HOME/Desktop/App-Installer.desktop
chmod +x $HOME/Desktop/App-Installer.desktop
cp $HOME/Desktop/App-Installer.desktop $PREFIX/share/applications

#Start script
cat <<'EOF' > start
#!/data/data/com.termux/files/usr/bin/bash

# Kill open X11 processes
kill -9 $(pgrep -f "termux.x11") 2>/dev/null

# Enable PulseAudio over Network
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1

# Prepare termux-x11 session
export XDG_RUNTIME_DIR=${TMPDIR}
termux-x11 :1.0 >/dev/null &

# Wait a bit until termux-x11 gets started.
sleep 3

# Launch Termux X11 main activity
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
sleep 1

# Set audio server
export PULSE_SERVER=127.0.0.1

#MESA_NO_ERROR=1 MESA_GL_VERSION_OVERRIDE=4.3COMPAT MESA_GLES_VERSION_OVERRIDE=3.2 virgl_test_server_android & > /dev/null 2>&1

MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink ZINK_DESCRIPTORS=lazy virgl_test_server_android --use-egl-surfaceless & 

# Run XFCE4 Desktop
env DISPLAY=:1.0 GALLIUM_DRIVER=virpipe XDG_SESSION_TYPE=x11 dbus-launch --exit-with-session xfce4-session & > /dev/null 2>&1

exit 0
EOF

chmod +x start
mv start $PREFIX/bin

#Shutdown Utility
cat <<'EOF' > $PREFIX/bin/kill_termux_x11
#!/bin/bash

# Check if Apt, dpkg, or Nala is running in Termux or Proot
if pgrep -f 'apt|apt-get|dpkg|nala'; then
  zenity --info --text="Software is currently installing in Termux or Proot. Please wait for these processes to finish before continuing."
  exit 1
fi

# Get the process IDs of Termux-X11 and XFCE sessions
termux_x11_pid=$(pgrep -f /system/bin/app_process.*com.termux.x11.Loader)
xfce_pid=$(pgrep -f "xfce4-session")

# Add debug output
echo "Termux-X11 PID: $termux_x11_pid"
echo "XFCE PID: $xfce_pid"

# Check if the process IDs exist
if [ -n "$termux_x11_pid" ] && [ -n "$xfce_pid" ]; then
  # Kill the processes
  kill -9 "$termux_x11_pid" "$xfce_pid"
  zenity --info --text="Termux-X11 and XFCE sessions closed."
else
  zenity --info --text="Termux-X11 or XFCE session not found."
fi

info_output=$(termux-info)
pid=$(echo "$info_output" | grep -o 'TERMUX_APP_PID=[0-9]\+' | awk -F= '{print $2}')
kill "$pid"

exit 0


EOF

chmod +x $PREFIX/bin/kill_termux_x11

#Create kill_termux_x11.desktop
echo "[Desktop Entry]
Version=1.0
Type=Application
Name=Kill Termux X11
Comment=
Exec=kill_termux_x11
Icon=system-shutdown
Categories=System;
Path=
StartupNotify=false
" > $HOME/Desktop/kill_termux_x11.desktop
chmod +x $HOME/Desktop/kill_termux_x11.desktop
mv $HOME/Desktop/kill_termux_x11.desktop $PREFIX/share/applications