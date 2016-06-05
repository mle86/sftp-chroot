#!/bin/sh
# 
# This autofs script will allow any local user's homedir to be mounted
# under /jail with a mountpoint named like the user, e.g.
# /jail/xyz      → fake empty directory (root:root 0755)
# /jail/xyz/~xyz → /~xyz
# 
# The base directory /jail will only be accessible for root.
# All mountpoints under /jail are therefore only usable as chroot base directories.


## Initialization:  ############################################################

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

	echo "${PROGNAME:-$0}: ""$@"  >&2
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

	local homedir="$(echo "$uent" | cut -d':' -f6)"
	[ -n "$homedir" ]  || fail 2 "no homedir entry"
	[ -d "$homedir" ]  || fail 3 "homedir not found: $homedir"

	echo "$homedir"
}

# remove_trailing_slashes string
#  Removes any trailing slashes in the string, if there are any,
#  and prints the result.
remove_trailing_slashes () {
	echo "$1" | sed 's:/*$::'
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
chmod 0700      $MOUNT_TO
chown root:root $MOUNT_TO


## Perform the mount:  #########################################################

# Finally tell autofs to bind-mount /jail/$username/$homedir to the real $homedir.
# 
# Because /jail/$username does not actually exist (yet),
# autofs will temporarily create it (root:root 0755)
# and all the other path components of $homedir, including home/.
# 
# But if we were to emit a "/" mount too (expanding to /jail/$username),
# it would have to contain an empty $homedir mount point!

echo "-fstype=bind  \"/$homedir\" \":$homedir\""

