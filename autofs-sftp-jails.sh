#!/bin/sh
# 
# This file is part of the sftp-chroot project – https://github.com/mle86/sftp-chroot/
# 
# This autofs script will allow any local user's homedir to be mounted
# under /jail with a mountpoint named like the user, e.g.
# /jail/xyz      → fake empty directory (root:root 0755)
# /jail/xyz/~xyz → /~xyz
# 
# The base directory /jail will only be accessible for root.
# All mountpoints under /jail are therefore only usable as chroot base directories.
# 
# Exit codes:
#  - 0  Success. Has printed one autofs(5) map entry.
#  - 1  Argument was not a valid username.
#  - 2  User exists, but has no homedir entry.
#  - 3  User's homedir does not exist (or is not a directory).
#  - 4  User's homedir contains a symlink component.
#  - 5  User's homedir contains a non-directory component (?!).
#  - 6  User's homedir has too many components.
#  - 7  User homedir component could not be resolved.
#  - 8  User's homedir contains forbidden characters.


## Initialization:  ############################################################

set -e  # die on errors

username="$1"

PROGNAME="$0($username)"

MOUNT_TO=/jail  # duplicated in auto.master.d/jails.autofs


## Helper functions:  ##########################################################

# fail [exitStatus=1] errorMessage
#  Exits the script with an error message and an optional exit status.
fail () {
	local status=1
	if [ -n "$2" ]; then
		status="$1"
		shift
	fi

	printf '%s: %s\n' "${PROGNAME:-$0}" "$*"  >&2
	exit $status
}

# user_homedir username
#  Retrieves and prints a user's homedir.
#  Exits with an error message and a non-zero status if
#   "getent passwd $username" did not succeed, or
#   the resulting passwd line did not contain a homedir part, or
#   the homedir does not exist or is not actually a directory.
#  The result is therefore guaranteed to be an existing directory.
user_homedir () {
	local username="$1"

	local uent=
	uent="$(getent passwd -- "$username")"  || fail 1 "user not found"

	local homedir="$(printf '%s' "$uent" | cut -d':' -f6)"
	[ -n "$homedir" ]  || fail 2 "no homedir entry"
	[ -d "$homedir" ]  || fail 3 "homedir not found: $homedir"

	printf '%s\n' "$homedir"
}

# remove_trailing_slashes string
#  Removes any trailing slashes in the string, if there are any,
#  and prints the result.
remove_trailing_slashes () {
	printf '%s' "$1" | sed 's:/*$::'
}

# homedir_name_check homedir
#  Checks its argument for dangerous characters.
homedir_name_check () {
	local homedir="$1"
	case "$homedir" in
		*':'*)		fail 8 "homedir with colon rejected: $homedir" ;;
		*'*'*)		fail 8 "homedir with asterisk rejected: $homedir" ;;
		*'`'*)		fail 8 "homedir with backtick rejected: $homedir" ;;
		*'"'*|*"'"*)	fail 8 "homedir with quote rejected: $homedir" ;;
		*"\\")		fail 8 "homedir with backslash rejected: $homedir" ;;
	esac
	true
}

# homedir_symlink_check homedir
#  Checks that its argument's path components do not contain any symlinks
#  and are all existing, real directories.
homedir_symlink_check () {
	local homedir="$(remove_trailing_slashes "$1")"
		# trailing slash has to go, or the -L test will RESOLVE the symlink instead of recognizing it!
	local n_max=50
	local stopdir='/'

	local testdir="$homedir"
	while [ -n "$testdir" ] && [ "$testdir" != "$stopdir" ]; do
		[ ! -L "$testdir" ]  || fail 4 "homedir component is a symlink: $testdir"
		[   -d "$testdir" ]  || fail 5 "homedir component is not a directory: $testdir"

		[ $n_max -gt 0 ]  || fail 6 "too many homedir components: $homedir"
		n_max=$((n_max - 1))

		# go to next-higher path component:
		testdir="$(dirname -- "$testdir")"  || fail 7 "could not resolve component: $homedir"
	done
	true
}


## Integrity checks:  ##########################################################

homedir="$(user_homedir "$username")"
# Now we know that the user exists and has an existing homedir.

# Make sure that the homedir does not contain any dangerous characters.
# In theory, they should not be a real problem,
# but we'd have to escape them in our final output.
# Since special characters in homedir names are really uncommon,
# we'll just reject them altogether:
homedir_name_check "$homedir"

# None of the homedir components can be a symlink!
# Otherwise the main account could remove the sub account's homedir
# and replace it with a symlink to, say, /root/secrets/.
# No matter what modes /root/ has -- as long as the sub account
# could enter secrets/ itself, they can read all files there.
# To prevent this, we check all path components:
homedir_symlink_check "$homedir"


## Prepare the environment:  ###################################################

# The /jail directory has to belong to root (or internal-sftp won't chroot).
# Restrictive modes are essential, or local users might access the jail mountpoints,
# circumventing the /home/$BASE_USER modes.
chmod -- 0700      "$MOUNT_TO"
chown -- root:root "$MOUNT_TO"


## Perform the mount:  #########################################################

# Finally tell autofs to bind-mount /jail/$username/$homedir to the real $homedir.
# 
# Because /jail/$username does not actually exist (yet),
# autofs will temporarily create it (root:root 0755)
# and all the other path components of $homedir, including home/.
# 
# But if we were to emit a "/" mount too (expanding to /jail/$username),
# it would have to contain an empty $homedir mount point!

# "key" is the relative mountpoint directory. Our base directory is /jail,
#  so the key is the requested directory name therein -- the username.
# "location" is the device/directory/network resource to mount.
#  The ":" prefix indicates a local device/directory.
#          key  [options]     location
printf -- '"/%s" -fstype=bind ":%s"\n'  "$homedir" "$homedir"

