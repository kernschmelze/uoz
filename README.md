# uoz
# "Ubuntu on ZFS"
An interactive ZFS on Root Builder for Ubuntu

Usage:

1. Start Ubuntu Server Live. Wait until the login screen appears
2. Switch to a console. The normal way to do so is ctrl-alt-F{1..6}
3. $ sudo su -
4. On Ubuntu Server: \# curl https://raw.githubusercontent.com/kernschmelze/uoz/refs/heads/main/uoz.pl -O uoz.pl 
5. On Ubuntu Desktop: \# wget https://raw.githubusercontent.com/kernschmelze/uoz/refs/heads/main/uoz.pl -O uoz.pl
6. \# perl uoz.pl
8. Follow the dialogs
9. After it got installed, you have to reboot
10. The first boot it is usually necessary to 'zpool import -f <yourpool>'
11. Now do the postconfiguration... this part of the interactive installer is still TBD
