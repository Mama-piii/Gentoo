Hello, and welcome to my GitHub!
Before using this script, please note that it was made for personal use only. It's not designed for anyone else, so I won’t be responsible for any issues that may happen.

This script installs a base Gentoo system with:

systemd

systemd-boot

gentoo-kernel-bin

root (/) on Btrfs

a make.conf customized for my own setup on an Acer Aspire 3 15" with an AMD Ryzen 5 5500U

Before running the script, make sure to partition your drive and adjust the script to match your disk.

The post-installation script performs the following actions:

Installs Flatpak and Gentoolkit

Removes temporary files

Installs GNOME and GDM

Adds a user to the plugdev group

Enables GDM

Installs and enables PipeWire

The installed applications are: nano, screen, pciutils, curl, wget, fastfetch, libreoffice-fresh-fr, dev-vcs/git, dev-lang/python, dev-util/htop

Finally, it updates the system and reboots :)

How to use
1. Clone this repo  
   `git clone https://github.com/Mama-piii/Gentoo.git`
2. Make the script executable  
   `chmod +x gentoo_install_systemd.sh`
3. Run the script as root  
   `sudo ./gentoo_install_systemd.sh`

You can still report bugs — I might reply. Maybe.


PS: Change the root password at line 127
