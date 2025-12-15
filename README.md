# t2_kali-builder

**t2_kali-builder** is a fully interactive, wizard-driven automation tool designed to build custom Kali Linux Live ISOs with **mandatory support for Apple T2 Macs** (MacBooks 2018-2020).

It removes the complexity of command-line flags and manual configuration file editing. You simply run the script, and it asks you questions to build your perfect ISO.

## Features

* **Zero Config:** No complex flags or text file editing required.
* **Mandatory T2 Setup:** Automatically enforces T2 Kernels, Drivers, and APT Pinning hooks so the system works out of the box on Apple hardware.
* **Repo Wizard:** Prompts you to paste in URLs for custom tools (like Floorp, VS Code, etc.) and handles the GPG keys automatically.
* **Variant Menu:** Simple selection menu for XFCE, Purple, GNOME, KDE, and more.
* **Rolling Ready:** Uses generic repository aliases (`testing`) so the build configuration doesn't break when Debian/Kali codenames change.

## Prerequisites

* **Operating System:** A Debian-based system.
    * *Recommendation:* Run this on **Kali Linux** to ensure all build tools are compatible.
* **Disk Space:** At least **25GB** of free disk space.
* **Privileges:** Root access (`sudo`).
* **Internet:** A high-speed, uncapped connection (The build process downloads the entire OS, ~3GB+).

## Installation

1.  Download or save the script as `t2_kali-builder.sh`.
2.  Make the script executable:

```bash
chmod +x t2_kali-builder.sh
```

## Usage

Simply run the script with sudo. There are no arguments or flags needed.

```bash
sudo ./t2_kali-builder.sh
```

---

## Walkthrough

Here is exactly what happens when you run the script:

### 1. Automatic T2 Configuration
The script starts by cloning the official Kali build configs. It automatically:
* Adds the **AdityaGarg8 T2 Repository** (using the `testing` alias for Rolling support).
* Downloads the T2 GPG Keys.
* **Essential Hook:** Creates an APT "Pinning" file. This forces the system to always prefer the T2 kernel over the standard Kali kernel, preventing updates from breaking your WiFi/Keyboard support.

### 2. Custom Repository Wizard
The script will ask:
`Would you like to add any extra repositories? [y/N]`

If you type `y`, you can add custom software.

**Example: Adding the Floorp Browser**
1.  **Enter the full 'deb' line:**
    * *Input:* `deb https://ppa.ablaze.one/ ./`
    * *(Note: For flat repos like Floorp, use `./` at the end. For standard repos, use the distro name like `noble` or `testing`)*.
2.  **Enter the URL to the GPG Key:**
    * *Input:* `https://ppa.ablaze.one/KEY.gpg`
3.  **Enter package names to install:**
    * *Input:* `floorp`

The script automatically creates the source lists, downloads the keys, and adds the package to the install queue.

### 3. Variant Wizard
The script will present a numbered list of available Desktop Environments. You simply type the number of your choice.

**Available Variants:**
* **XFCE:** The standard, lightweight Kali desktop (Recommended for T2 Macs).
* **Purple:** The Defensive Security variant (Includes Arkime, Suricata, etc. - Large ISO).
* **GNOME:** Modern, touch-friendly, heavier resource usage.
* **KDE:** Highly customizable, Windows-like layout.
* **MATE:** Classic Gnome 2 style, very stable.
* **LXDE:** Extremely lightweight.
* **i3:** Tiling window manager (Keyboard focused, minimal GUI).
* **E17:** Enlightenment desktop.

### 4. Build Process
The script launches the official Kali `live-build` process.
* **Duration:** 30 minutes to 2 hours (depending on internet speed and CPU).
* **Output:** When finished, your ISO will be located in the `live-build-config/images/` directory.

---

## Troubleshooting

### 1. Build Fails / "E: Package not found"
* Check the `live-build-config/live-build.log` file created in the directory.
* If a custom package (like `floorp`) fails, verify you entered the **deb line** correctly in the wizard.
* Ensure you have internet access throughout the build.

### 2. Repository 404 Errors
* If you added a custom repo and see 404 errors during the build, you likely used a distribution name (like `noble` or `jammy`) for a repo that doesn't support it. Try using `./` at the end of the deb line instead.

### 3. T2 Drivers / WiFi Not Working
* **During Install:** The ISO built by this script includes the T2 Kernel by default.
* **Post Install:** If you update your system later (`apt full-upgrade`), ensure you **do not select the standard Kali kernel** in the GRUB menu if a new one is installed.
* The script adds a pin at `/etc/apt/preferences.d/99-t2-repo` to prevent the standard kernel from overriding the T2 kernel, but manual user intervention can sometimes bypass this.

### 4. Permission Denied
* Ensure you are running the script with `sudo`.

---

## AI Assistance Disclaimer

This script and documentation were generated with the assistance of an Artificial Intelligence. While the code has been structured to follow best practices for Debian/Kali live-build systems and includes safety checks (such as APT pinning for T2 kernels), it is provided "as is."

**Security Notice:** This script requires root privileges (`sudo`) to function, as it modifies build configurations and installs system dependencies. It is always recommended that you review the script contents manually before executing it on your machine.
