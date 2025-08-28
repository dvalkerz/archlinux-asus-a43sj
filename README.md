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
git clone https://github.com/dvalkerz/archlinux-asus-a43sj.git
```
### 3. Go to the repo folder
```bash
cd YOUR-REPO
```
### 4. Make the Script Executable
```bash
chmod +x install.sh
```
### 5. Run the Script
```bash
sudo ./install.sh
```

### Using curl
```bash
curl -sL https://raw.githubusercontent.com/dvalkerz/archlinux-asus-a43sj/main/install.sh | bash
```

### Using wget
```bash
wget -qO- https://raw.githubusercontent.com/dvalkerz/archlinux-asus-a43sj/main/install.sh | bash
```

