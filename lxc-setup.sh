#!/bin/bash
set -euo pipefail

# ----------------------------------------
# Script to set up LXC environment and golden container
# ----------------------------------------

# 1. Install required packages
echo "Installing LXC and arch-install-scripts..."
sudo pacman -Syu --noconfirm lxc arch-install-scripts

# 2. Enable LXC bridge
echo "Configuring LXC bridge..."
echo 'USE_LXC_BRIDGE="true"' | sudo tee /etc/default/lxc-net

# 3. Add default ID mapping for containers
echo "Configuring /etc/lxc/default.conf..."
sudo mkdir -p /etc/lxc
sudo tee /etc/lxc/default.conf > /dev/null <<'EOF'
lxc.idmap = u 0 100000 65536
lxc.idmap = g 0 100000 65536
EOF

# 4. Create hooks directory
echo "Creating LXC hooks directory..."
sudo mkdir -p /usr/share/lxc/hooks

# 5. Create pre-start hook (placeholder)
PRE_START_HOOK="/usr/share/lxc/hooks/x11-pre-start"
sudo tee -a "$PRE_START_HOOK" > /dev/null <<'EOF'
#!/bin/bash
# TODO: Add your pre-start code here
# set -x  # echo commands
# set -e  # exit on first error

# echo "Hook started" >> /tmp/lxc-x11-hook.log
# whoami >> /tmp/lxc-x11-hook.log
# env >> /tmp/lxc-x11-hook.log

if [ -n "$LXC_ROOTFS_PATH" ] && [ -S /tmp/.X11-unix/X0 ]; then
        # echo 'command triggered' >> /tmp/lxc-x11-hook.log
        # echo "${LXC_ROOTFS_MOUNT}/${LXC_NAME}/root/.Xauthority" >> /tmp/lxc-x11-hook.log
    cp /home/${SUDO_USER}/.Xauthority ${LXC_ROOTFS_PATH}//root/.Xauthority
    chown 100000:100000 ${LXC_ROOTFS_PATH}/root/.Xauthority
fi

EOF
sudo chmod +x "$PRE_START_HOOK"

# 6. Create post-stop hook (placeholder)
POST_STOP_HOOK="/usr/share/lxc/hooks/x11-post-stop"
sudo tee "$POST_STOP_HOOK" > /dev/null <<'EOF'
#!/bin/bash
# TODO: Add your post-stop code here
if [ -n "$LXC_ROOTFS_PATH" ]; then
    rm -f ${LXC_ROOTFS_PATH}/root/.Xauthority
fi
EOF
sudo chmod +x "$POST_STOP_HOOK"

# 7. Create golden container image
echo "Creating golden container image..."
sudo lxc-create -n goldein-image -t download -- --dist kali --release current --arch amd64

# 8. Apply custom configs to golden image
GOLDEN_CONFIG="/var/lib/lxc/goldein-image/config"
echo "Adding custom configs to golden image..."
sudo tee -a "$GOLDEN_CONFIG" > /dev/null <<'EOF'
# TODO: Add your custom container configs here

# custom configs by me? 
lxc.mount.entry = tmpfs tmp tmpfs defaults
## for xorg
lxc.mount.entry = /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry = /dev/snd dev/snd none bind,optional,create=dir
lxc.mount.entry = /tmp/.X11-unix tmp/.X11-unix none bind,optional,create=dir,ro
lxc.mount.entry = /dev/video0 dev/video0 none bind,optional,create=file
lxc.environment = DISPLAY=:0
lxc.environment = XAUTHORITY=/root/.Xauthority

# Copy Xauthority file on start instead of bind mounting
lxc.hook.pre-start = /usr/share/lxc/hooks/x11-pre-start
lxc.hook.post-stop = /usr/share/lxc/hooks/x11-post-stop

EOF


# 8. Apply custom configs to golden image
x11_CONFIG="/var/lib/lxc/goldein-image/rootfs/usr/bin/x11setup"
echo "Adding custom script for x11 to golden image..."
sudo tee "$x11_CONFIG" > /dev/null <<'EOF'
#!/bin/bash
if [ -n "$DISPLAY" ]; then
    xauth add :0 . $(xauth list | awk '{print $3}' | tail -1) 2>/dev/null
fi
EOF

echo "Setup complete!"
