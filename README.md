# sftp-chroot

This project aims to provide a working solution
for home directory-jailed SFTP
using OpenSSH-server's **internal-sftp** subsystem
and **automount**(8).


## Project page

See
[**mle86.github.io/sftp-chroot**](http://mle86.github.io/sftp-chroot/)
for more information
on how this project was built.


## Features

* Simple installation script
* Regular SSH logins are not affected
* `sftp` group members can use SFTP only
* `sftp` group members can only access their own home directories
* Lightweight chroot'ing (without */dev* etc.)
* SFTP `pwd` shows correct path names
* No additional per-user configuration needed


## Limitations

Since this solution uses the *internal-sftp* subsystem,
only SFTP connections are supported,
but SCP or rsync won't work.


## Installation

Run `sudo `[`./install.sh`](install.sh).
This is what it will do:

* `apt-get install autofs`,
* copy [`autofs-sftp-jails.sh`](autofs-sftp-jails.sh) to `/etc/`,
* copy [`jails.autofs`](jails.autofs) to `/etc/auto.master.d/`,
* create a new `sftp` user group,
* append [`sshd_config.add`](sshd_config.add) to `/etc/ssh/sshd_config`.

Every operation will ask for manual confirmation (`y`) first,
so you can skip steps with `n`
or abort the entire installation process at any time with Ctrl-C.


## Author

Maximilian Eul
\<maximilian@eul.cc\>

https://github.com/mle86/

