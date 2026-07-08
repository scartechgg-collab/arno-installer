ARNO Installer
A premium, modular, production-ready Bash installer for Pterodactyl Panel and Pings.Powered by Arnoplays.

ThemeLicenseBashPterodactyl

🚀 Quick Start
Install Panel
bash <(curl -s https://raw.githubusercontent.com/Arnoplays/arno-installer/main/install.sh)
Then choose option [1] Panel Installation.

Install Wings
bash <(curl -s https://raw.githubusercontent.com/Arnoplays/arno-installer/main/install.sh)
Then choose option [2] Wings Installation.

🎨 Features
✨ Animated splash screen with logo reveal, fade-in, and typing effects
🖥️ Centered, branded UI with Unicode box drawing
🔍 Automatic OS detection (Ubuntu, Debian, Rocky, AlmaLinux)
⚡ System checks (root, RAM, CPU, disk, virtualization, internet)
📦 Panel installation: PHP 8.3, Composer, MariaDB, Redis, Nginx, SSL, cron, queue service
🐳 Wings installation: Docker, Docker Compose plugin, Wings binary, systemd service
🛡️ Firewall configuration (UFW / firewalld)
🔒 Automatic SSL via Let's Encrypt (Certbot)
📝 Comprehensive logging at /var/log/arno-installer.log
🔁 Retry-on-failure for resilient installations
🧩 Modular architecture — every component is in lib/
🎯 Idempotent — safe to re-run
📂 Project Structure
arno-installer/├── install.sh                 # Entry point├── lib/│   ├── colors.sh              # ANSI color definitions│   ├── animations.sh          # Spinners, progress bars, typing│   ├── utilities.sh           # OS detection, logging, helpers│   ├── ui.sh                  # Menus, boxes, splash, status│   ├── database.sh            # MariaDB + Redis│   ├── nginx.sh               # Nginx config│   ├── ssl.sh                 # Certbot SSL│   ├── docker.sh              # Docker engine│   ├── firewall.sh            # UFW / firewalld│   ├── panel.sh               # Panel installation flow│   └── wings.sh               # Wings installation flow├── configs/│   ├── nginx.conf             # HTTP template│   ├── nginx_ssl.conf         # HTTPS template│   ├── pteroq.service         # Queue worker systemd│   ├── wings.service          # Wings daemon systemd│   └── php-fpm.conf           # PHP-FPM pool config├── assets/│   ├── logo.txt               # ASCII logo│   ├── banner.txt             # Banner│   └── spinner.txt            # Spinner frames├── README.md└── LICENSE
🛠️ Requirements
OS: Ubuntu 20.04+, Debian 11+, Rocky Linux 9+, AlmaLinux 9+
Access: Root privileges
RAM: 1GB minimum (2GB+ recommended)
Disk: 10GB minimum
Network: Internet connection
🎨 Theme
Element	Color
Background	Black
Primary	#ff2d2d
Text	White
Secondary text	Gray
📊 Logging
All actions are logged to:

/var/log/arno-installer.log
Includes:

Every executed command
Errors and warnings
Installation duration
Installed packages
Versions
🔧 Development
Run locally:

git clone https://github.com/Arnoplays/arno-installer.gitcd arno-installersudo bash install.sh
Lint with ShellCheck:

shellcheck install.sh lib/*.sh
🤝 Credits
Arnoplays — Original author
Pterodactyl — Game server management panel
Inspired by community Pterodactyl installers, rewritten from scratch
📜 License
MIT License — see LICENSE.
