# T2Kali_ISOBuilder
A bash automation script to build custom "Rolling" Kali Linux Live ISOs with **mandatory support for Apple T2 Macs** (MacBooks 2018-2020) and flexibility for custom repositories and desktop variants.

## Features

  * **Mandatory T2 Support:** Automatically configures the AdityaGarg8 T2 repository, installs `linux-t2` kernel/drivers, and applies APT pinning to prevent kernel overwrites.
  * **Rolling Release:** Uses generic repository aliases (`testing`) so the build config doesn't break when Debian/Kali codenames change.
  * **Variant Selection:** Choose from XFCE (default), Purple, GNOME, KDE, i3, etc.
  * **Custom Repositories:** Easily inject third-party repos (like Floorp, VS Code, etc.) via command-line flags.

## Prerequisites

  * **OS:** A Debian-based system (Kali Linux is highly recommended to avoid dependency issues).
  * **Storage:** At least **25GB** of free disk space.

## Installation

1.  Save the script to your computer (e.g., `t2_kali-builder.sh.sh`).
2.  Make the script executable:

<!-- end list -->

```bash
chmod +x t2_kali-builder.sh.sh
```

## Usage

Run the script with `sudo`. You can run it interactively or use flags for automation.

```bash
sudo ./t2_kali-builder.sh.sh [OPTIONS]
```

### Options

| Flag | Description |
| :--- | :--- |
| `-v, --variant <name>` | Sets the Desktop Environment (e.g., `xfce`, `purple`, `gnome`, `kde`). |
| `-r, --repo "LINE|URL"` | Adds a custom repository. **Must be quoted.**<br>Format: `"DEB_REPO_LINE|GPG_KEY_URL"` |
| `-h, --help` | Displays the help menu. |

-----

## Examples

### 1\. Basic Interactive Mode

This will install T2 drivers and prompt you to select a desktop environment from a menu.

```bash
sudo ./t2_kali-builder.sh.sh
```

### 2\. Build Standard Kali (XFCE) with T2 Support

```bash
sudo ./t2_kali-builder.sh.sh --variant xfce
```

### 3\. The "Full Package" (T2 + Floorp Browser)

This command builds the ISO with T2 drivers AND adds the Floorp browser repository + Key.

**Note:** The script automatically detects "floorp" in the URL and adds the package to the install list.

```bash
sudo ./t2_kali-builder.sh.sh \
  --variant xfce \
  --repo "deb [signed-by=/etc/apt/trusted.gpg.d/custom-1.gpg] https://ppa.ablaze.one/ ./|https://ppa.ablaze.one/KEY.gpg"
```

*Important: Enclose the `--repo` argument in quotes so the `|` character doesn't break the command.*

## Troubleshooting

  * **Build Fails?** Check the `live-build.log` file created in the directory. Common issues are network timeouts or running out of disk space.
  * **Kernel Issues?** The script automatically creates an APT Pinning file (`99-t2-repo`) in the ISO. If you boot and WiFi/Keyboard don't work, ensure you didn't manually update the kernel to a standard non-T2 version post-install.
  * **"Permission Denied"?** Ensure you are running with `sudo`.
