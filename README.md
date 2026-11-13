# Extension Hub

**Pterodactyl Panel Extension Manager**  
Version: `v1.0` · Made by **Ziro** · Powered by **NexyonCloud**

Extension Hub is a Bash-based VPS CLI for managing the Blueprint installation workflow for a Pterodactyl Panel.

## Features

- Colored terminal interface and ASCII banner
- Blueprint file/configuration detection
- Blueprint installation using the official GitHub latest-release ZIP
- Blueprint update and reinstall workflows
- Backup of selected panel files/directories before supported changes
- Blueprint and Pterodactyl/Laravel version information
- Direct CLI commands for Blueprint status, install, update, version, and info

> **Important:** This is an early v1.0 utility. Test on a staging server first and keep an independent full panel backup. The installer currently targets Debian/Ubuntu systems using `apt`. It runs Blueprint's own `blueprint.sh` setup script. Review the script before running it as root.

## Requirements

- Debian/Ubuntu VPS
- Pterodactyl Panel installed
- Root/sudo access
- Internet access
- A valid Pterodactyl panel directory (default: `/var/www/pterodactyl`)

## Install from GitHub

Replace `YOUR_GITHUB_USERNAME` with your GitHub username after uploading this repository:

```bash
git clone https://github.com/YOUR_GITHUB_USERNAME/extension-hub.git
cd extension-hub
chmod +x extension-hub.sh
sudo install -m 755 extension-hub.sh /usr/local/bin/extension-hub
sudo extension-hub
```

Or run it without installing globally:

```bash
sudo bash ./extension-hub.sh
```

## Set a custom Pterodactyl directory

```bash
sudo PTERODACTYL_DIRECTORY=/path/to/pterodactyl extension-hub
```

The script also prompts for the panel directory during Blueprint installation.

## Commands

```bash
sudo extension-hub
sudo extension-hub help

sudo extension-hub blueprint status
sudo extension-hub blueprint install
sudo extension-hub blueprint update
sudo extension-hub blueprint info
sudo extension-hub blueprint version
```

## Main menu

```text
[01] Blueprint
[02] Themes
[03] Extensions
[04] Zerix Theme (Coming Soon)
[00] Exit
```

Themes and Extensions are menu placeholders in v1.0 and do not claim to install anything yet. Zerix Theme is marked Coming Soon.

## Backups and logs

- Backups: `/var/lib/extension-hub/backups/`
- Log: `/var/log/extension-hub.log`

The Blueprint backup is a targeted backup of selected panel paths, not a complete server backup. Maintain your own full backup.

## Safety notes

- Read `extension-hub.sh` before executing it with root privileges.
- The script downloads Blueprint from the official `BlueprintFramework/framework` GitHub latest-release URL.
- The script may install Node.js 22 and Yarn and run `yarn install` in the panel directory.
- The script preserves an existing `.blueprintrc` rather than overwriting it.
- Automatic Blueprint uninstall is intentionally disabled because deleting files without a release-specific supported uninstall procedure can damage panel customizations.
- Reinstall/update operations can change panel files. Review the backup and command output.

## License

MIT. See [LICENSE](LICENSE).
