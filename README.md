# t2_kali-builder

**t2_kali-builder** is a fully interactive, wizard-driven tool for building custom Kali Linux Live ISOs for Apple T2 Macs (MacBooks 2018-2020).

It removes the complexity of command-line flags and configuration files. You simply run the script, and it asks you questions to build your perfect ISO.

## Features
* **Zero Config:** No complex flags or text file editing required.
* **Mandatory T2 Setup:** Automatically enforces T2 Kernels, Drivers, and APT Pinning hooks.
* **Repo Wizard:** Prompts you to paste in URLS for custom tools (like Floorp, VS Code, etc) and handles the GPG keys automatically.
* **Variant Menu:** Simple selection menu for XFCE, Purple, GNOME, KDE, and more.

## Prerequisites
* **OS:** A Kali System / Live Enviroment.
* **Space:** ~25GB of free disk space.
* **Privileges:** Root access (`sudo`).

## Installation

1.  Download or create the script `t2_kali-builder.sh`.
2.  Make it executable:
    ```bash
    chmod +x t2_kali-builder.sh
    ```

## Usage

Simply run the script with sudo. There are no arguments needed.

```bash
sudo ./t2_kali-builder.sh
```

## Troubleshooting

Build Fails: Check the live-build.log in the directory.

Repo Errors: If your custom repo fails (404), ensure you typed the deb line correctly. For flat repos (like Floorp), ensure you end the URL with ./.

T2 Drivers: The script hard-codes a priority pin at /etc/apt/preferences.d/99-t2-repo to ensure the T2 kernel is always preferred.
