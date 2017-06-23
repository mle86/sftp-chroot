#!/bin/sh
# 
# This file is the installation script for the sftp-chroot project – https://github.com/mle86/sftp-chroot/

cd "$(dirname -- "$0")"

MOUNT_TO='/jail'

autofs_cfg='jails.autofs'
autofs_dest='/etc/auto.master.d/'
jailmount_script='autofs-sftp-jails.sh'
jailmount_dest='/etc/'
sshd_append='sshd_config.add'
sshd_appendto='/etc/ssh/sshd_config'
new_group='sftp'


################################################################################

ansi_failure='[1;31m'
ansi_highlight='[1m'
ansi_reset='[0m'
ansi_info='[1;35m'
#ansi_success='[1;32m'

# fail [exitStatus=1] errorMessage
#  Exits the script with an error message and an optional exit status.
fail () {
	local status=1
	if [ -n "$2" ]; then
		status="$1"
		shift
	fi
	echo "$ansi_failure ""$@""$ansi_reset"  >&2
	exit $status
}

# info infoMessage
#  Prints an informational message on stderr.
info () {
	echo "$ansi_info ""$@""$ansi_reset"
}

# ask prompt [defaultInput=n]
#  Asks the user for a choice, showing the $prompt and waiting for input.
#  Defaults to $defaultInput in case of empty input.
#  Exits with status 1 in case of EOF (Ctrl-D).
ask () {
	local prompt="$1"
	local default="${2:-n}"

	ANSWER=
	read -p "$ansi_highlight $prompt >$ansi_reset " ANSWER  || fail  # eof, exit with newline
	[ -n "$ANSWER" ] || ANSWER="$default"

	true
}

is_yes () { [ "$ANSWER" = "y" ] || [ "$ANSWER" = "Y" ] || [ "$ANSWER" = "j" ] || [ "$ANSWER" = "J" ] || [ "$ANSWER" = "yes" ]; }

################################################################################


[ "$(id -u)" = "0" ] || fail 1 "This installation script can only be run by root."


ask "Install autofs? [Y/n]" 'y'
if is_yes; then
	apt-get update && apt-get -y install autofs
fi

ask "Copy $autofs_cfg to $autofs_dest? [Y/n]" 'y'
if is_yes; then
	mkdir -vp -- "$autofs_dest"
	cp -vi -- "$autofs_cfg" "$autofs_dest"
fi

ask "Copy $jailmount_script to $jailmount_dest? [Y/n]" 'y'
if is_yes; then
	cp -vi -- "$jailmount_script" "$jailmount_dest"
fi

ask "Create user group $new_group? [Y/n]" 'y'
if is_yes; then
	groupadd --force --system -- "$new_group"
	if ! grp="$(getent group -- "$new_group")"; then
		fail "group not found: $new_group"
	else
		info "group entry: $grp"
	fi
fi

ask "Append $sshd_append to $sshd_appendto? [Y/n]" 'y'
if is_yes; then
	[ -s "$sshd_appendto" ] || fail 2 "$sshd_appendto does not exist or is empty!"
	cat -- "$sshd_append" >> "$sshd_appendto"

	info "If your sshd_config contains an 'AllowGroups' directive,"
	info "don't forget to add the '$new_group' group to it!"
fi

ask "Prepare empty $MOUNT_TO base dir? [Y/n]" 'y'
if is_yes; then
	mkdir -vp -- "$MOUNT_TO"
	chmod -v 0700 -- "$MOUNT_TO"
fi

ask "Reload automount and sshd? [Y/n]" 'y'
if is_yes; then
	/etc/init.d/autofs reload
	/etc/init.d/ssh reload
fi

