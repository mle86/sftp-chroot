# sftp-chroot

This project aims to provide a working solution
for homedir-chrooted SFTP
using the openssh-server's **internal-sftp** subsystem
and **automount**(8).


## Project page

See
[**mle86.github.io/sftp-chroot**](https://mle86.github.io/sftp-chroot/)
for more information!


## Installation

Run the `install.sh` script as root.

It will install autofs,  
copy `autofs-sftp-jails.sh` to `/etc/`,  
copy `jails.autofs` to `/etc/auto.master.d/`,  
create a new `sftp` user group,  
and append `sshd_config.add` to `/etc/ssh/sshd_config`.

Every operation will ask for manual confirmation ("`y`") first.

