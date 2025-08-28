#!/usr/bin/env bash
# arch-a43sj-full-setup.sh
# Fully automated post-install for ASUS A43SJ (Intel i3 + GeForce GT 520M 1GB)
# - XFCE + LightDM
# - Bumblebee (nouveau by default), optional nvidia-390xx via AUR
# - firmware (Wi-Fi/Bluetooth/USB3) and essentials
# - ACPI Fn+F2 wireless toggle (acpid + XFCE fallback)
# - fstrim.timer enabled
# - power tweaks (tlp, powertop)
# - usbutils installed
#
# Run as root (sudo). Example:
#   sudo ./arch-a43sj-full-setup.sh
#
set -euo pipefail
export LANG=C

log(){ echo -e "\n==> $*"; }

# -------------------------
# Configuration (env overrides)
# -------------------------
# USE_NVIDIA = "nouveau" (default) or "proprietary"
USE_NVIDIA="${USE_NVIDIA:-nouveau}"

# Detect non-root user who will use desktop
TARGET_USER="${SUDO_USER:-$(whoami)}"
if [[ "$EUID" -eq 0 && -z "${SUDO_USER:-}" ]]; then
  # Running as root directly — try to find a non-root user with a home
  TARGET_USER="$(logname 2>/dev/null || echo "")"
fi
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
  echo "ERROR: Could not detect non-root target user. Run script with sudo from the non-root account."
  exit 1
fi
USER_HOME="$(eval echo ~"$TARGET_USER")"

log "Target user: $TARGET_USER (home: $USER_HOME)"
log "Driver preference: $USE_NVIDIA"

# -------------------------
# 1) System update & required base packages
# -------------------------
log "Updating system and installing base packages..."
pacman -Syu --noconfirm

pacman -S --noconfirm --needed \
  base-devel linux-headers linux-firmware \
  git wget curl nano vim unzip \
  pciutils usbutils lshw rsync htop

# -------------------------
# 2) Desktop & display manager
# -------------------------
log "Installing XFCE desktop and LightDM..."
pacman -S --noconfirm --needed xfce4 xfce4-goodies lightdm lightdm-gtk-greeter network-manager-applet
systemctl enable lightdm.service

# -------------------------
# 3) Networking & Bluetooth
# -------------------------
log "Installing networking and Bluetooth stack..."
pacman -S --noconfirm --needed networkmanager wireless_tools wpa_supplicant bluez bluez-utils
systemctl enable --now NetworkManager.service
systemctl enable --now bluetooth.service || true

# -------------------------
# 4) Audio, webcam, input
# -------------------------
log "Installing audio, webcam and input drivers..."
pacman -S --noconfirm --needed alsa-utils pulseaudio pavucontrol
pacman -S --noconfirm --needed v4l-utils           # webcam (uvcvideo auto-loaded)
pacman -S --noconfirm --needed xf86-input-libinput xf86-input-synaptics

# -------------------------
# 5) Power & maintenance
# -------------------------
log "Installing power management and maintenance tools..."
pacman -S --noconfirm --needed tlp powertop acpi acpid
systemctl enable --now tlp.service
systemctl enable --now acpid.service
systemctl enable --now fstrim.timer || true   # enable trim (if supported)

# -------------------------
# 6) Graphics stack + Bumblebee
# -------------------------
log "Installing graphics stack (Intel + Bumblebee)."

# Intel + mesa for iGPU
pacman -S --noconfirm --needed mesa xf86-video-intel mesa-utils

# Install Bumblebee components (Optimus support) and bbswitch
pacman -S --noconfirm --needed bumblebee bbswitch primus virtualgl lib32-primus

# Add the target user to the bumblebee group
if ! getent group bumblebee >/dev/null; then
  groupadd -r bumblebee || true
fi
usermod -aG bumblebee "$TARGET_USER" || true
systemctl enable --now bumblebeed.service || true

# NVIDIA driver choice
if [[ "$USE_NVIDIA" == "proprietary" ]]; then
  log "User requested proprietary NVIDIA 390xx install (AUR). Building from AUR..."
  # Ensure base-devel exists (installed earlier)
  TEMP_AUR="/tmp/aur-nvidia-390xx-$$"
  mkdir -p "$TEMP_AUR"
  pushd "$TEMP_AUR" >/dev/null

  # Build nvidia-390xx-utils
  if ! pacman -Qi nvidia-390xx-utils &>/dev/null; then
    git clone https://aur.archlinux.org/nvidia-390xx-utils.git
    cd nvidia-390xx-utils
    makepkg -si --noconfirm
    cd ..
  fi

  # Build nvidia-390xx-dkms (or nvidia-390xx)
  if ! pacman -Qi nvidia-390xx-dkms &>/dev/null && ! pacman -Qi nvidia-390xx &>/dev/null; then
    git clone https://aur.archlinux.org/nvidia-390xx-dkms.git
    cd nvidia-390xx-dkms
    makepkg -si --noconfirm
    cd ..
  fi

  popd >/dev/null
  rm -rf "$TEMP_AUR"
  log "Proprietary nvidia-390xx packages attempted to install (check output above)."
  # Adjust Bumblebee to use nvidia if installed
  if pacman -Qi nvidia-390xx-dkms &>/dev/null || pacman -Qi nvidia-390xx &>/dev/null; then
    sed -i 's/^Driver=.*/Driver=nvidia/' /etc/bumblebee/bumblebee.conf || true
    sed -i 's/^KernelDriver=.*/KernelDriver=nvidia/' /etc/bumblebee/bumblebee.conf || true
    sed -i 's/^LibraryPath=.*/LibraryPath=\/usr\/lib\/nvidia\/:\/usr\//lib\/32-nvidia/' /etc/bumblebee/bumblebee.conf || true
    log "Bumblebee configured to use NVIDIA driver."
  else
    log "Failed to detect proprietary NVIDIA installed; continuing with nouveau."
  fi
else
  log "Using open-source nouveau for NVIDIA GPU (recommended for stability)."
  pacman -S --noconfirm --needed xf86-video-nouveau
  sed -i 's/^Driver=.*/Driver=nouveau/' /etc/bumblebee/bumblebee.conf || true
fi

# -------------------------
# 7) USB 3.0 visibility
# -------------------------
log "Installing USB tools (usbutils) - USB 3.0 controller handled by kernel (xhci_hcd)."
pacman -S --noconfirm --needed usbutils

# -------------------------
# 8) ACPI Fn+F2 wireless toggle
# -------------------------
log "Configuring ACPI wireless toggle (Fn+F2) and XFCE fallback."

mkdir -p /etc/acpi/events /etc/acpi/actions

cat >/etc/acpi/events/asus-wireless-toggle <<'EOF'
# Generic Asus wireless toggle (catch asus/hotkey events)
event=asus.*
action=/etc/acpi/actions/asus-wireless-toggle.sh
EOF

cat >/etc/acpi/actions/asus-wireless-toggle.sh <<'EOF'
#!/usr/bin/env bash
# Toggle Wi-Fi and Bluetooth via rfkill
set -e
# If wifi soft blocked, unblock both; otherwise block both
if rfkill list wifi | grep -q "Soft blocked: yes"; then
  rfkill unblock wifi || true
  rfkill unblock bluetooth || true
else
  rfkill block wifi || true
  rfkill block bluetooth || true
fi
EOF

chmod +x /etc/acpi/actions/asus-wireless-toggle.sh
systemctl restart acpid.service || true

# XFCE fallback using xbindkeys for XF86WLAN (user session)
log "Setting up XFCE fallback toggle (xbindkeys) for user $TARGET_USER."

pacman -S --noconfirm --needed xbindkeys

# Create script in user's local bin
mkdir -p "$USER_HOME/.local/bin"
cat >"$USER_HOME/.local/bin/wlan-toggle.sh" <<'EOF'
#!/usr/bin/env bash
if rfkill list wifi | grep -q "Soft blocked: yes"; then
  rfkill unblock wifi; rfkill unblock bluetooth
else
  rfkill block wifi; rfkill block bluetooth
fi
EOF
chmod +x "$USER_HOME/.local/bin/wlan-toggle.sh"
chown -R "$TARGET_USER":"$TARGET_USER" "$USER_HOME/.local"

# Create xbindkeys configuration in user's home
cat >"$USER_HOME/.xbindkeysrc" <<'EOF'
# Toggle wireless with XF86WLAN
"~/.local/bin/wlan-toggle.sh"
  XF86WLAN
EOF
chown "$USER_HOME/.xbindkeysrc" "$TARGET_USER":"$TARGET_USER" || true

# Autostart xbindkeys in XFCE session
mkdir -p "$USER_HOME/.config/autostart"
cat >"$USER_HOME/.config/autostart/xbindkeys.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=XBindKeys
Exec=xbindkeys
X-GNOME-Autostart-enabled=true
NoDisplay=false
EOF
chown -R "$TARGET_USER":"$TARGET_USER" "$USER_HOME/.config/autostart"

# -------------------------
# 9) fstrim timer note (enable already above), ensure it's running
# -------------------------
log "Ensuring fstrim.timer is enabled..."
systemctl enable --now fstrim.timer || true

# -------------------------
# 10) Final utilities & cleanup
# -------------------------
log "Installing extra helpful utilities..."
pacman -S --noconfirm --needed gvfs gvfs-smb ntfs-3g p7zip

log "Setup complete for ASUS A43SJ."
echo
echo "Summary / next steps:"
echo " - Reboot your system: sudo reboot"
echo " - Test Bumblebee (optirun/primusrun): optirun glxgears || primusrun glxgears"
echo " - Test wireless toggle: press Fn+F2 (ACPI) or press XF86WLAN key after login (xbindkeys)"
echo " - Check webcam with: ls /dev/video* and 'cheese' (install if you want: pacman -S cheese)"
echo
echo "Notes:"
echo " - Nouveau is recommended for stability. If you used USE_NVIDIA=proprietary, the script attempted to build legacy nvidia-390xx via AUR."
echo " - If X fails after proprietary NVIDIA install, switch to nouveau: sudo pacman -S xf86-video-nouveau && sudo rm /etc/X11/xorg.conf"
echo
log "All done. Reboot to apply changes."
