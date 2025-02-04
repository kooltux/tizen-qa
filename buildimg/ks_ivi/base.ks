# -*-mic2-options-*- -f raw --fstab=uuid --copy-kernel --compress-disk-image=bz2 --generate-bmap -*-mic2-options-*-

# 
# Do not Edit! Generated by:
# kickstarter.py
# 

lang en_US.UTF-8
keyboard fr
timezone --utc Europe/Paris
part /boot --size 64 --ondisk sda --fstype=ext4 --label boot --active --align 1024 --fsoption=noatime
part / --size 3748 --ondisk sda --fstype=ext4 --label platform --align 1024 --fsoption=noatime

rootpw tizen 
xconfig --startxonboot
bootloader  --timeout=0  --append="rw vga=current quiet splash rootwait rootfstype=ext4 security=none" --ptable=gpt

desktop --autologinuser=tizen  
user --name tizen  --groups audio,video,weston-launch --password 'tizen'

installerfw_plugins "bootloader"

repo --name=ivi --baseurl=@REPO_URL@/repos/ivi/ia32/packages/ --ssl_verify=no

%packages

@Base System
@IVI Adaptation
@IVI Packaging
@IVI Middleware
@Wayland
@Console Tools
@IVI Applications

# SDX: added QA Tools
@IVI QA Tools

kernel-x86-ivi

#rfkill 

ivi-repos
#release-repos
setup-extlinux
setup-ivi-clone

%end

%include 60_customize.inc.ks

%include 70_qa.inc.ks

%post

# base-general.post

ln -sf /proc/self/mounts /etc/mtab

rm -rf /root/.zypp

#Hack to temporarily disable net-config, which collides with settingsd. Related to TIVI-2569
rm /usr/lib/systemd/system/multi-user.target.wants/net-config.service

# rpm.post
rm -f /var/lib/rpm/__db*
rpmdb --rebuilddb

# Initialize the native application database
pkg_initdb

# Add 'app' user to the weston-launch group
/usr/sbin/groupmod -A app weston-launch

# Temporary work around for bug in filesystem package resulting in the 'app' user home
# directory being only readable by root
chown -R app:app /opt/home/app

# Since weston-launch runs with the "User" label, the app
# home dir must have the same label
chsmack -a User /opt/home/app

# Enable a logind session for 'app' user on seat0 (the default seat for
# graphical sessions)
mkdir -p /usr/lib/systemd/system/graphical.target.wants
ln -s ../user-session-launch@.service /usr/lib/systemd/system/graphical.target.wants/user-session-launch@seat0-5000.service
ln -sf weston.target  /usr/lib/systemd/user/default.target

# Add over-riding environment to enable the web runtime to
# run on an IVI image as a different user then the tizen user
# Some notes on some of the variables:
#  - ELM_THEME is needed in order for the wrt to have visible content
#  - WRT_PROCESS_POOL_DISABLE is a work around for TIVI-2062
cat > /etc/sysconfig/wrt <<EOF
DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/5000/dbus/user_bus_socket
XDG_RUNTIME_DIR=/run/user/5000
ELM_ENGINE=wayland_egl
ECORE_EVAS_ENGINE=wayland_egl
ELM_THEME=tizen-HD-light
WRT_PROCESS_POOL_DISABLE=1
EOF

# Use the same over-rides for the native prelaunch daemon
cp /etc/sysconfig/wrt /etc/sysconfig/launchpad

# Add a rule to ensure the app user has permissions to
# open the graphics device
cat > /etc/udev/rules.d/99-dri.rules <<EOF
SUBSYSTEM=="drm", MODE="0666"
EOF

# Needed to fix TIVI-1629
vconftool set -t int -f db/setting/default_memory/wap 0

# Install and configure the boot-loader, /etc/fstab, and so on
/usr/sbin/setup-ivi-boot

# sdx: set DBUS env inside weston shell (login shell)
#cat >/etc/profile.d/user-dbus.sh <<EOF
#export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID/dbus/user_bus_socket
#EOF

# MBR.post
#/usr/sbin/setup-mbr-ivi

############### sdx@kooltux.org: workaround vmlinuz bad link + create snapshot repo #############

cat >> /etc/zypp/repos.d/ivi-snapshot.repo  << EOF
[ivi-snapshot]
name=ivi-snapshot
enabled=1
autorefresh=0
priority=50
baseurl=@REPO_URL@/repos/ivi/ia32/packages/?ssl_verify=no
type=rpm-md
gpgcheck=0
EOF

##########################################################################
%end

%post --nochroot
# buildname.nochroot 
if [ -n "$IMG_NAME" ]; then
    echo "BUILD_ID=$IMG_NAME" >> $INSTALL_ROOT/etc/tizen-release
    echo "BUILD_ID=$IMG_NAME" >> $INSTALL_ROOT/etc/os-release
fi


%end
