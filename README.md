# ASUS A43SJ Arch Linux Post-Install Script

This repository contains a fully automated **post-install setup script** for the ASUS A43SJ laptop running Arch Linux.  
It configures **XFCE + LightDM**, NVIDIA Optimus (Bumblebee), drivers, SSD care, power tweaks, and more.

---

## Features

✅ XFCE + LightDM (lightweight desktop)  
✅ NVIDIA Optimus: Bumblebee (default = `nouveau` for stability)  
➡️ Optional NVIDIA legacy `390xx` driver via AUR  
✅ All firmware (Wi-Fi, Bluetooth, USB 3.0)  
✅ ACPI Fn+F2 wireless toggle (with XFCE fallback keybinding)  
✅ SSD care (`fstrim.timer` enabled)  
✅ Power optimizations: **TLP + Powertop**  
✅ USB 3.0 support (`xhci_hcd` built-in, plus `usbutils` for visibility)  

---

## Usage

### 1. Install Git
After finishing your Arch base install:
```bash
sudo pacman -S --needed git
```
### 2. Clone This Repo
```bash
git clone https://github.com/dvalkerz/install-script-archlinux-asus-a43sj.git
```
### 3. Go to the repo folder
```bash
cd YOUR-REPO
```
### 4. Make the Script Executable
```bash
chmod +x asus-a43sj-setup.sh
```
### 5. Run the Script
```bash
sudo ./asus-a43sj-setup.sh
```

### Using curl
```bash
curl -sL https://raw.githubusercontent.com/dvalkerz/install-script-archlinux-asus-a43sj/main/asus-a43sj-arch-setup.sh | bash
```

