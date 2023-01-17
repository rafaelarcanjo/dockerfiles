#!/bin/bash
#
# Copyright 2010-2015 René Moser
# http://github.com/git-ftp/git-ftp
#
# Git-ftp is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Git-ftp is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Git-ftp.  If not, see <http://www.gnu.org/licenses/>.

# ------------------------------------------------------------
# Setup Environment
# ------------------------------------------------------------

# General config
readonly DEFAULT_PROTOCOL="ftp"
readonly REMOTE_LCK_FILE="$(basename "$0").lck"
readonly SYSTEM="$(uname)"
readonly VERSION='1.6.0'

# ------------------------------------------------------------
# Defaults
# ------------------------------------------------------------
URL=""
REMOTE_PROTOCOL=""
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PASSWD=""
REMOTE_BASE_URL=""
REMOTE_BASE_URL_DISPLAY=""
REMOTE_ROOT=""
REMOTE_PATH=""
REMOTE_CACERT=""
REMOTE_DELETE_CMD="-*DELE "
REMOTE_CMD_OPTIONS=("-s")
LFTP_OPTIONS=""
ACTION=""
LOG_CACHE=""
ERROR_LOG=""
BRANCH=""
CURRENT_BRANCH=""
SCOPE=""
KEYCHAIN_USER=""
KEYCHAIN_HOST=""
DEPLOYED_SHA1_FILE=".git-ftp.log"
DEPLOYED_SHA1=""
PREV_DEPLOYED_SHA1=""
LOCAL_SHA1=""
SYNCROOT=""
SNAPSHOT_DIR=""
CURL_PROTOCOL=""
CURL_PUBLIC_KEY=""
CURL_PRIVATE_KEY=""
CURL_PROXY=""
LFTP_PROTOCOL=""
LFTP_COMMAND_SETTINGS=""
TMP_DIR=""
TMP_CURL_UPLOAD_FILE=""
TMP_CURL_DELETE_FILE=""
TMP_GITFTP_UPLOAD=""
TMP_GITFTP_DELETE=""
TMP_GITFTP_INCLUDE=""
declare -a CURL_ARGS
declare -a GIT_SUBMODULES
declare -i VERBOSE=0
declare -i IGNORE_DEPLOYED=0
declare -i DOWNLOAD_CHANGED_ONLY=0
declare -i DRY_RUN=0
declare -i FORCE=0
declare -i ENABLE_REMOTE_LCK=0
declare -i ACTIVE_MODE=0
declare -i USE_KEYCHAIN=0
declare -i EXECUTE_HOOKS=1
declare -i ENABLE_POST_HOOK_ERRORS=0
declare -i AUTO_INIT=0
declare -i INSECURE=0
declare -i CURL_DISABLE_EPSV=0
declare -i NO_COMMIT=0

# ------------------------------------------------------------
# Constant Exit Error Codes
# ------------------------------------------------------------
readonly ERROR_USAGE=2
readonly ERROR_MISSING_ARGUMENTS=3
readonly ERROR_UPLOAD=4
readonly ERROR_DOWNLOAD=5
readonly ERROR_UNKNOWN_PROTOCOL=6
readonly ERROR_REMOTE_LOCKED=7
readonly ERROR_GIT=8
readonly ERROR_HOOK=9
readonly ERROR_FILESYSTEM=10

# ------------------------------------------------------------
# Functions
# ------------------------------------------------------------

usage_long()
{
local pager=$(git config --get core.pager)
${GIT_PAGER:-${pager:-${PAGER:-less -FRSX}}} << EOF
USAGE
	git-ftp <action> [<options>] [<url>]


DESCRIPTION
	git-ftp does FTP the Git way.

	It uses Git to determine which local files have changed since the last
	deployment to the remote server and saves you time and bandwidth by
	uploading only those files.

	It keeps track of the deployed state by uploading the SHA1 of the last
	deployed commit in a log file.

ACTIONS
	. init
		Does an initial upload of the latest version of all non-ignored
		git-tracked files to the remote server and creates .git-ftp.log
		file containing the SHA1 of the latest commit.

	. catchup
		Updates the commit id stored on the server.

	. push
		Uploads git-tracked files which have changed since last upload.

	. download (EXPERIMENTAL)
		Downloads changes from the remote host into your working tree.
		WARNING: It can delete local untracked files that are not
		listed in your .git-ftp-ignore file.

	. pull (EXPERIMENTAL)
		Downloads changes from the remote server into a separate commit
		and merges them into your current branch.

	. snapshot (EXPERIMENTAL)
		Downloads files into a new Git repository. Takes an additional
		optional argument as local destination directory. Example:
		\`git-ftp snapshot ftp://example.com/public_html projects/example\`

	. show
		Downloads last uploaded SHA1 from log and hooks \`git show\`.

	. log
		Downloads last uploaded SHA1 from log and hooks \`git log\`.

	. add-scope
		Add a scope (e.g. dev, production, testing).

	. remove-scope
		Completely remove a scope.

	. help
		Shows this help screen.


URL
	. FTP (default)		host.example.com[:<port>][/<remote path>]
	. FTP			ftp://host.example.com[:<port>][/<remote path>]
	. SFTP			sftp://host.example.com[:<port>][/<remote path>]
	. FTPS			ftps://host.example.com[:<port>][/<remote path>]
	. FTPES			ftpes://host.example.com[:<port>][/<remote path>]


OPTIONS
	-h, --help		Shows this help screen.
	-u, --user		FTP login name.
	-p, --passwd		FTP password.
	-P, --ask-passwd	Ask for FTP password interactively.
	-k, --keychain		FTP password from KeyChain (Mac OS X only).
	-b, --branch		Git branch to push
	-s, --scope		Using a scope (e.g. dev, production, testing).
	-D, --dry-run		Dry run: Does not upload anything.
	-a, --all		Uploads all files, ignores deployed SHA1 hash.
	-c, --commit		Sets SHA1 hash of last deployed commit by option.
	-A, --active		Use FTP active mode.
	-l, --lock		Enable/Disable remote locking.
	-f, --force		Force, does not ask questions.
	-n, --silent		Silent mode.
	-v, --verbose		Verbose mode.
	-vv			Very verbose or debug mode.
	--remote-root		Specifies remote root directory
	--syncroot		Specifies a local directory to sync from as if it were the git project root path.
	--key			SSH private key file name for SFTP.
	--pubkey		SSH public key file name. Used with --key option.
	--insecure		Don't verify server's certificate.
	--cacert		Specify a <file> as CA certificate store. Useful when a server has got a self-signed certificate.
	--no-commit		Perform the merge at the and of pull but do not autocommit, to have the chance to inspect and further tweak the merge result before committing.
	--changed-only		Download or pull only files changed since the deployed commit while ignoring all other files.
	--no-verify		Bypass the pre-ftp-push hook.
	--enable-post-errors	Fails if post-ftp-push hook raises an error
	--disable-epsv		Tell curl to disable the use of the EPSV command when doing passive FTP transfers. Curl will normally always first attempt to use EPSV before PASV, but with this option, it will not try using EPSV.
	--auto-init		Automatically run init action when running push action
	--version		Prints version.
	-x, --proxy		Use the specified proxy.


EXAMPLES
	. git-ftp push -u john ftp://ftp.example.com:4445/public_ftp -p -v
	. git-ftp push -p -u john -v ftp.example.com:4445:/public_ftp
	. git-ftp push -p -u john ftp.example.com --branch prod
	. git-ftp add-scope production ftp://user:secr3t@ftp.example.com:4445/public_ftp
	. git-ftp push --scope production
	. git-ftp remove-scope production


SET DEFAULTS
	. git config git-ftp.user john
	. git config git-ftp.url ftp.example.com
	. git config git-ftp.password secr3t
	. git config git-ftp.remote-root "~/www/"
	. git config git-ftp.branch prod
	. git config git-ftp.syncroot path/dir
	. git config git-ftp.cacert path/cacert
	. git config git-ftp.deployedsha1file mySHA1File
	. git config git-ftp.insecure 1
	. git config git-ftp.keychain user@example.com


SET SCOPE DEFAULTS
	e.g. your scope is 'testing'
	. git config git-ftp.testing.url ftp.example.local


VERSION
	$VERSION
EOF
exit 0
}

usage() {
	echo "git-ftp <action> [<options>] [<url>]"
	exit "$ERROR_USAGE"
}

cache_git_submodules() {
	GIT_SUBMODULES="$(git submodule status -- "$SYNCROOT" 2>/dev/null | grep -v '^-' | awk '{print $2}')"
}

is_submodule() {
	echo "${GIT_SUBMODULES[@]}" | grep -Fxq -- "$1"
}

boolean() {
	case "$1" in
		"true")
			echo "1"
			;;
		"false")
			echo "0"
			;;
		*)
			echo $1
			;;
	esac
}

ask_for_passwd() {
	echo -n "Password: "
	stty -echo > /dev/null 2>&1
	read REMOTE_PASSWD
	stty echo > /dev/null 2>&1
	echo ""
}

get_keychain_password () {
	if [ "$SYSTEM" = "Darwin" ]; then
		# Split user and host if necessary
		if echo "$KEYCHAIN_USER" | grep -q '@'; then
			KEYCHAIN_HOST=$(echo "$KEYCHAIN_USER" | cut -d '@' -f2)
			KEYCHAIN_USER=$(echo "$KEYCHAIN_USER" | cut -d '@' -f1)
		else
			[ -z "$KEYCHAIN_USER" ] && KEYCHAIN_USER="$REMOTE_USER"
			[ -z "$KEYCHAIN_HOST" ] && KEYCHAIN_HOST="$REMOTE_HOST"
		fi

		[ -z "$KEYCHAIN_USER" ] && print_error_and_die "Missing keychain account." "$ERROR_MISSING_ARGUMENTS"
		
		local KEYCHAIN_ARGS=(-a "$KEYCHAIN_USER")
		[ -n "$KEYCHAIN_HOST" ] && KEYCHAIN_ARGS+=(-s "$KEYCHAIN_HOST")

		write_log "Read password from keychain."

		local pass
		if pass="$(security find-internet-password "${KEYCHAIN_ARGS[@]}" -g 2>&1 > /dev/null)"; then
			without_prefix="${pass#password: \"}"
			REMOTE_PASSWD="${without_prefix%\"}"
		else
			print_error_and_die "Password not found in keychain for account '$KEYCHAIN_USER @ $KEYCHAIN_HOST'." "$ERROR_MISSING_ARGUMENTS"
		fi
	else
		write_log "Ignoring -k on non-Darwin systems."
	fi
}

# Checks if last command was successful
#
# $1 - error message
# $2 - error code to produce
#
check_exit_status() {
	check_exit_status_not_equals $? 0 "$1" "$2"
}

# Checks if exit status equals a given value. If false sends exit command.
#
# $1 - status code to check
# $2 - code to test against
# $3 - error message
# $4 - error code to produce
#
check_exit_status_equals() {
	if [ $1 -eq $2 ]; then
		print_error_and_die "$3, exiting..." "$4"
	fi
}

# Checks if exit status not equals a given value
#
# $1 - status code to check
# $2 - code to test against
# $3 - error message
# $4 - error code to produce
#
check_exit_status_not_equals() {
	if [ $1 -ne $2 ]; then
		print_error_and_die "$3, exiting..." "$4"
	fi
}

# Checks if a given curl exit code was successful and if not exits with a nice error message (in some cases)
#
# $1 - exit code to check
# $2 - message: a custom message that is put in front of the error message
# $3 - error code: code to exit with if $1 is bad
#
check_curl_exit_status() {
	case $1 in
		0) ;;
		9) print_error_and_die "$2 Access to resource denied. This usually means that the file or directory does not exist. Wrong path? exiting..." "$3" ;;
		67) print_error_and_die "$2 Can't access remote '$REMOTE_BASE_URL_DISPLAY'. Failed to log in. Correct user and password? exiting..." "$3" ;;
		78) print_error_and_die "$2 The resource does not exist. exiting..." "$3" ;;
		*) print_error_and_die "$2 Can't access remote '$REMOTE_BASE_URL_DISPLAY'. Network down? Wrong URL? exiting..." "$3" ;;
	esac
}

get_config() {
	# try .git-ftp-config
	[ -n "$SCOPE" ] && [ -f '.git-ftp-config' ] && OUT="$(git config -f '.git-ftp-config' --get "git-ftp.$SCOPE.$1")"
	if [ $? -eq 0 ];
	then
		echo "$OUT"
		return 0
	fi
	[ -f '.git-ftp-config' ] && OUT="$(git config -f '.git-ftp-config' --get "git-ftp.$1")"
	if [ $? -eq 0 ];
	then
		echo "$OUT"
		return 0
	fi
	[ -n "$SCOPE" ] && OUT="$(git config --get "git-ftp.$SCOPE.$1")"
	if [ $? -eq 0 ];
	then
		echo "$OUT"
		return 0
	fi
	OUT="$(git config --get "git-ftp.$1")"
	if [ $? -eq 0 ];
	then
		echo "$OUT"
		return 0
	fi
	[ -n "$2" ] && OUT="$2"
	echo "$OUT"
}

set_deployed_sha1_file() {
	DEPLOYED_SHA1_FILE="$(get_config deployedsha1file "$DEPLOYED_SHA1_FILE")"
}

# Simple log func
write_log() {
	if [ $VERBOSE -eq 1 ]; then
		echo "$(date): $1"
	else
		if [ -n "$LOG_CACHE" ]; then
			LOG_CACHE="$LOG_CACHE\n$(date): $1"
		else
			LOG_CACHE="$(date): $1"
		fi
	fi
}

write_error_log() {
	write_log "$1"
	if [ -n "$ERROR_LOG" ]; then
		ERROR_LOG="$ERROR_LOG\n: $1"
	else
		ERROR_LOG="$1"
	fi
}

print_error_log() {
	if [ -n "$ERROR_LOG" ]; then
		echo "Error log:"
		echo "$ERROR_LOG"
	fi
}

# Simple error printer
print_error_and_die() {
	if [ $VERBOSE -eq 0 ]; then
		echo "fatal: $1" >&2
	else
		write_log "fatal: $1"
	fi
	cleanup
	exit "$2"
}

# Simple info printer
print_info() {
	if [ $VERBOSE -eq 0 ]; then
		echo "$1"
	else
		write_log "$1"
	fi
}

cleanup() {
	rm -rf "$TMP_DIR"
}

set_default_curl_options() {
	OIFS="$IFS"
	IFS=" "
	CURL_ARGS=("${REMOTE_CMD_OPTIONS[@]}")
	IFS="$OIFS"
	
    CURL_ARGS+=(--globoff)

    # Change by Rafael Silva rafael.silva@alfasoft.pt
    if [ -n "$PASSPHRASE" ]; then
        CURL_ARGS+=(--pass "$PASSPHRASE")		
    elif [ -n "$(get_config passphrase)" ]; then
		PASSPHRASE=$(get_config passphrase)
		CURL_ARGS+=(--pass $(get_config passphrase))
	fi

	if [ -n "$CURL_PROXY" ]; then
		CURL_ARGS+=(--proxy "$CURL_PROXY")
	fi
	if [ -z "$REMOTE_USER" ]; then
		CURL_ARGS+=(--netrc)
	fi
	CURL_ARGS+=(-#)
	if [ $ACTIVE_MODE -eq 1 ]; then
		CURL_ARGS+=(-P "-")
	else
		if [ $CURL_DISABLE_EPSV -eq 1 ]; then
			CURL_ARGS+=(--disable-epsv)
		fi
	fi
}

upload_file() {
	local SRC_FILE="$1"
	local DEST_FILE="$2"
	if [ -z "$DEST_FILE" ]; then
		DEST_FILE="${SRC_FILE#$SYNCROOT}"
	fi

	set_default_curl_options
	CURL_ARGS+=(-T "$SRC_FILE")
	CURL_ARGS+=(--ftp-create-dirs)
	CURL_ARGS+=("$REMOTE_BASE_URL/${REMOTE_PATH}${DEST_FILE}")
	curl "${CURL_ARGS[@]}"
}

upload_file_buffered() {
	local SRC_FILE="$1"
	local DEST_FILE="${SRC_FILE#$SYNCROOT}"
	local ENC_DEST_FILE="${DEST_FILE//#/%23}"
	# Rafael Silva - Replace space
	local ENC_DEST_FILE="${DEST_FILE// /%20}"
	echo "-T \"./$SRC_FILE\"
url = \"$REMOTE_BASE_URL/${REMOTE_PATH}${ENC_DEST_FILE}\"" >> "$TMP_CURL_UPLOAD_FILE"
}

fire_upload_buffer() {
	if [ ! -f "$TMP_CURL_UPLOAD_FILE" ]; then
		return 0
	fi
	print_info "Uploading ..."
	set_default_curl_options
	CURL_ARGS+=(--ftp-create-dirs)
	CURL_ARGS+=(-K "$TMP_CURL_UPLOAD_FILE")
	curl "${CURL_ARGS[@]}"
	check_exit_status "Could not upload files." "$ERROR_UPLOAD"
}

delete_file() {
	local FILENAME="$1"
	set_default_curl_options
	CURL_ARGS+=(-Q "${REMOTE_DELETE_CMD}${REMOTE_PATH}${FILENAME}")
	CURL_ARGS+=("$REMOTE_BASE_URL")
	if [ "${REMOTE_CMD_OPTIONS[0]}" = "-v" ]; then
		curl "${CURL_ARGS[@]}"
	else
		curl "${CURL_ARGS[@]}" > /dev/null 2>&1
	fi
	if [ $? -ne 0 ]; then
		write_log "WARNING: Could not delete ${REMOTE_PATH}${FILENAME}, continuing..."
	fi
}

delete_file_buffered() {
	echo "-Q \"${REMOTE_DELETE_CMD}${REMOTE_PATH}${1}\"" >> "$TMP_CURL_DELETE_FILE"
}

fire_delete_buffer() {
	if [ ! -f "$TMP_CURL_DELETE_FILE" ]; then
		return 0
	fi
	print_info "Deleting ..."
	set_default_curl_options
	CURL_ARGS+=(-K "$TMP_CURL_DELETE_FILE")
	if [ "${REMOTE_CMD_OPTIONS[0]}" = "-v" ]; then
		curl "${CURL_ARGS[@]}"
	else
		curl "${CURL_ARGS[@]}" > /dev/null 2>&1
	fi
	if [ $? -ne 0 ]; then
		write_log "WARNING: Some files and/or directories could not be deleted."
	fi
}

get_file_content() {
	local SRC_FILE="$1"
	set_default_curl_options
	CURL_ARGS+=("$REMOTE_BASE_URL/${REMOTE_PATH}${SRC_FILE}")
	curl "${CURL_ARGS[@]}"
}

set_local_sha1() {
	LOCAL_SHA1=$(git log -n 1 --pretty=format:%H)
}

upload_local_sha1() {
	write_log "Uploading commit log to $REMOTE_BASE_URL_DISPLAY/${REMOTE_PATH}$DEPLOYED_SHA1_FILE."
	if [ $DRY_RUN -ne 1 ]; then
		echo "$LOCAL_SHA1" | upload_file - "$DEPLOYED_SHA1_FILE"
		check_curl_exit_status $? "Could not upload." "$ERROR_UPLOAD"
	fi
	print_info "Last deployment changed from $DEPLOYED_SHA1 to $LOCAL_SHA1.";
	PREV_DEPLOYED_SHA1="$DEPLOYED_SHA1"
	DEPLOYED_SHA1="$LOCAL_SHA1"
}

pre_push_hook() {
	local hooks_dir="$(git config core.hooksPath)"
	if [ -z "$hooks_dir" ];then
		hooks_dir=".git/hooks"
	fi
	local hook="$hooks_dir/pre-ftp-push"

	if [ "$EXECUTE_HOOKS" -eq 1 -a -e "$hook" ]; then
		local scope="${SCOPE:-$REMOTE_HOST}"
		local url="$REMOTE_BASE_URL_DISPLAY/$REMOTE_PATH"
		write_log "Trigger pre-ftp-push hook with: $scope, $url, $LOCAL_SHA1, $DEPLOYED_SHA1"
		print_status | $hook "$scope" "$url" "$LOCAL_SHA1" "$DEPLOYED_SHA1" || exit "$ERROR_HOOK"
	fi
}

post_push_hook() {
	local hooks_dir="$(git config core.hooksPath)"
	if [ -z "$hooks_dir" ];then
		hooks_dir=".git/hooks"
	fi
	local hook="$hooks_dir/post-ftp-push"

	if [ -e "$hook" ]; then
		local scope="${SCOPE:-$REMOTE_HOST}"
		local url="$REMOTE_BASE_URL_DISPLAY/$REMOTE_PATH"
		write_log "Trigger post-ftp-push hook with: $scope, $url, $LOCAL_SHA1, $PREV_DEPLOYED_SHA1"
		$hook "$scope" "$url" "$LOCAL_SHA1" "$PREV_DEPLOYED_SHA1" || [ "$ENABLE_POST_HOOK_ERRORS" -eq 0 ] || exit "$ERROR_HOOK"
	fi
}

print_status() {
	while IFS= read -r -d '' FILE_NAME; do
		printf 'A %s\0' "$FILE_NAME"
	done < "$TMP_GITFTP_UPLOAD"
	while IFS= read -r -d '' FILE_NAME; do
		printf 'D %s\0' "$FILE_NAME"
	done < "$TMP_GITFTP_DELETE"
}

remote_lock() {
	[ $ENABLE_REMOTE_LCK -ne 1 ] && return
	[ $FORCE -ne 1 ] && check_remote_lock

	local LCK_MESSAGE="${USER}@$(hostname --fqdn) on $(date --utc --rfc-2822)"

	write_log "Remote locking $LCK_MESSAGE."
	if [ $DRY_RUN -ne 1 ]; then
		echo "${LOCAL_SHA1}\n${LCK_MESSAGE}" | upload_file - "$REMOTE_LCK_FILE"
		check_exit_status "Could not upload remote lock file." "$ERROR_UPLOAD"
	fi
}

release_remote_lock() {
	[ $ENABLE_REMOTE_LCK -ne 1 ] && return;
	write_log "Releasing remote lock."
	delete_file "$REMOTE_LCK_FILE"
}

set_remote_host() {
	[ -z "$URL" ] && URL="$(get_config url)"
	REMOTE_HOST=$(expr "$URL" : ".*://\([[:alpha:]0-9\.:-]*\).*")
	[ -z "$REMOTE_HOST" ] && REMOTE_HOST=$(expr "$URL" : "\([[:alpha:]0-9\.:-]*\).*")
	[ -z "$REMOTE_HOST" ] && print_error_and_die "Remote host not set." "$ERROR_MISSING_ARGUMENTS"
}

set_remote_protocol() {
	# Split protocol from url
	REMOTE_PROTOCOL="$(get_protocol_of_url "$URL")"
	CURL_PROTOCOL="$REMOTE_PROTOCOL"

	# Protocol found?
	if [ ! -z "$REMOTE_PROTOCOL" ]; then
		REMOTE_PATH=$(echo "$URL" | cut -d '/' -f 4-)
		handle_remote_protocol_options
		return
	fi

	# Check if a unknown protocol is set, handle it or use default protocol
	local UNKNOWN_PROTOCOL=$(expr "$URL" : "\(.*:[/]*\).*")
	if [ -z "$UNKNOWN_PROTOCOL" ]; then
		write_log "Protocol not set, using default protocol $DEFAULT_PROTOCOL://."
		REMOTE_PROTOCOL="$DEFAULT_PROTOCOL"
		CURL_PROTOCOL="$REMOTE_PROTOCOL"
		echo "$URL" | egrep -q "/" && REMOTE_PATH=$(echo "$URL" | cut -d '/' -f 2-)
		handle_remote_protocol_options
		return
	fi
	print_error_and_die "Protocol unknown '$UNKNOWN_PROTOCOL'." "$ERROR_UNKNOWN_PROTOCOL"
}

set_remote_path() {
	# Check remote root directory
	[ -z "$REMOTE_ROOT" ] && REMOTE_ROOT="$(get_config remote-root)"
	if [ ! -z "$REMOTE_ROOT" ]; then
		! echo "$REMOTE_ROOT" | egrep -q "/$" && REMOTE_ROOT="$REMOTE_ROOT/"
		REMOTE_PATH="$REMOTE_ROOT$REMOTE_PATH"
	fi

	# Add trailing slash if missing
	if [ ! -z "$REMOTE_PATH" ] && ! echo "$REMOTE_PATH" | egrep -q "/$"; then
		write_log "Added missing trailing / in path."
		REMOTE_PATH="$REMOTE_PATH/"
	fi
}

set_deployed_sha1_failable() {
	# Return if commit is set by user interaction using --commit
	if [ -n "$DEPLOYED_SHA1" ]; then
		return
	fi
	# Get the last commit (SHA) we deployed if not ignored or not found
	write_log "Retrieving last commit from $REMOTE_BASE_URL_DISPLAY/$REMOTE_PATH."
	DEPLOYED_SHA1="$(get_file_content "$DEPLOYED_SHA1_FILE")"
}

set_deployed_sha1() {
	set_deployed_sha1_failable
	check_curl_exit_status $? "Could not get last commit. Use 'git ftp init' for the initial push." "$ERROR_DOWNLOAD"
	write_log "Last deployed SHA1 for $REMOTE_HOST/$REMOTE_PATH is $DEPLOYED_SHA1."
}

set_deployed_sha1_for_push() {
	if [ "$AUTO_INIT" = 1 ]; then
		set_deployed_sha1_failable
		if [ "$DEPLOYED_SHA1" = "" ]; then
			check_remote_access
			write_log "Uploading all files since no commit was found at $REMOTE_BASE_URL_DISPLAY/$REMOTE_PATH."
			IGNORE_DEPLOYED=1
		fi
	else
		set_deployed_sha1
	fi
}

set_changed_files() {
	set_tmp
	# Get raw list of files
	if [ $IGNORE_DEPLOYED -ne 0 ]; then
		write_log "Taking all files.";
		list_all_files
	else
		list_changed_files
	fi
	add_include_files
	filter_ignore_files "$TMP_GITFTP_UPLOAD" "$TMP_GITFTP_DELETE"
	if [ -s "$TMP_GITFTP_UPLOAD" ] || [ -s "$TMP_GITFTP_DELETE" ]; then
		write_log "Having files to sync.";
	else
		write_log "No files to sync. All changed files ignored.";
	fi
}

list_all_files() {
	git ls-files -z -- "${SYNCROOT:-.}" > "$TMP_GITFTP_UPLOAD"
	touch "$TMP_GITFTP_DELETE"
}

list_changed_files() {
	git diff --name-only --no-renames --diff-filter=AM -z "$DEPLOYED_SHA1" -- "$SYNCROOT" 2>/dev/null > "$TMP_GITFTP_UPLOAD"
	git diff --name-only --no-renames --diff-filter=D  -z "$DEPLOYED_SHA1" -- "$SYNCROOT" 2>/dev/null > "$TMP_GITFTP_DELETE"
	local git_diff_status=$?
	if [ "$git_diff_status" -ne 0 ]; then
		if [ $FORCE -eq 1 ]; then
			print_info "Unknown SHA1 object, could not determine changed files, taking all files."
			list_all_files
			return
		fi
		print_info "Unknown SHA1 object, make sure you are deploying the right branch and it is up-to-date."
		#echo -n "Do you want to ignore and upload all files again? [y/N]: "
		ANSWER_STATE='n'
		if [ "$ANSWER_STATE" != "y" ] && [ "$ANSWER_STATE" != "Y" ]; then
			print_info "Aborting..."
			cleanup
			test "$ANSWER_STATE" == "" && exit "$ERROR_USAGE"
			exit 1
		fi
		write_log "Taking all files.";
		list_all_files
	elif [ "$LOCAL_SHA1" == "$DEPLOYED_SHA1" ]; then
		print_info "No changed files for $REMOTE_HOST/$REMOTE_PATH. Everything up-to-date."
		cleanup
		unset_branch
		exit 0
	elif [ ! -s "$TMP_GITFTP_UPLOAD" -a ! -s "$TMP_GITFTP_DELETE" ]; then
		write_log "No changed files, but different commit ID. Changed files ignored or commit amended.";
	fi
}

add_include_files() {
	[ -f '.git-ftp-include' ] || return
	local tmp_include_sources="$TMP_DIR/include_sources_tmp"
	grep -v '^#.*$\|^\s*$' '.git-ftp-include' | tr -d '\r' > "$TMP_GITFTP_INCLUDE"
	grep '^!' "$TMP_GITFTP_INCLUDE" | sed 's/^!//' | while read TARGET; do
		add_include_file "$TARGET"
	done
	local AGAINST="${DEPLOYED_SHA1:-"$(git hash-object -t tree /dev/null)"}"
	grep ':' "$TMP_GITFTP_INCLUDE" | while read LINE; do
		local TARGET="${LINE%%:*}"
		local SOURCE="${LINE#*:}"
		if echo "$SOURCE" | grep -q '^/'; then
			SOURCE="${SOURCE#/}"
		elif [ -n "$SYNCROOT" ]; then
			SOURCE="$SYNCROOT/$SOURCE"
		fi
		if ! git diff --quiet "$AGAINST" -- "$SOURCE"; then
			add_include_file "$TARGET"
		fi
	done
	rm -f "$tmp_include_sources"
	rm -f "$TMP_GITFTP_INCLUDE"
}

add_include_file() {
	local TARGET="${1}"
	if [ -e "$TARGET" ]; then
		if [ -d "$TARGET" ]; then
			write_log "Including all files in $TARGET for upload."
			find "$TARGET" -type f -print0 >> "$TMP_GITFTP_UPLOAD"
		elif [ -f "$TARGET" ]; then
			write_log "Including $TARGET for upload."
			printf '%s\0' "$TARGET" >> "$TMP_GITFTP_UPLOAD"
		fi
	else
		if echo "$TARGET" | grep -v '/$'; then
			write_log "Including $TARGET for deletion."
			printf '%s\0' "$TARGET" >> "$TMP_GITFTP_DELETE"
		else
			write_log "Deletion of directory $TARGET is not supported."
		fi
	fi
}

filter_ignore_files() {
	[ -f '.git-ftp-ignore' ] || return
	local patterns="$TMP_DIR/ignore_tmp"
	grep -v '^#.*$\|^\s*$' '.git-ftp-ignore' | tr -d '\r' > "$patterns"
	filter_file "$patterns" "$1"
	filter_file "$patterns" "$2"
	rm -f "$patterns"
}

filter_file() {
	glob_filter "$1" < "$2" > "$TMP_DIR/filtered_tmp"
	mv "$TMP_DIR/filtered_tmp" "$2"
}

# Original implementation http://stackoverflow.com/a/27718468/3377535
glob_filter() {
	local patterns="$1"
	while IFS= read -r -d '' filename; do
		local hasmatch=0
		while IFS= read -r pattern; do
			case $filename in ($pattern) hasmatch=1; break ;; esac
		done < "$patterns"
		test $hasmatch = 1 || printf '%s\0' "$filename"
	done
}

handle_file_sync() {
	if [ ! -s "$TMP_GITFTP_UPLOAD" ] && [ ! -s "$TMP_GITFTP_DELETE" ]; then
		print_info "There are no files to sync."
		return
	fi
	sort -z -u -o "$TMP_GITFTP_UPLOAD" "$TMP_GITFTP_UPLOAD"
	sort -z -u -o "$TMP_GITFTP_DELETE" "$TMP_GITFTP_DELETE"
	# Calculate total file count
	local DONE_ITEMS=0
	local TOTAL_ITEMS=$(cat "$TMP_GITFTP_UPLOAD" "$TMP_GITFTP_DELETE" | tr -d -c '\0' | wc -c)
	TOTAL_ITEMS=$((TOTAL_ITEMS+0)) # trims whitespaces produced by wc
	print_info "$TOTAL_ITEMS file$([ $TOTAL_ITEMS -ne 1 ] && echo 's') to sync:"

	while IFS= read -r -d '' FILE_NAME; do
		(( DONE_ITEMS++ ))
		print_info "[$DONE_ITEMS of $TOTAL_ITEMS] Buffered for upload '$FILE_NAME'."
		if is_submodule "$FILE_NAME"; then
			handle_submodule_sync "${FILE_NAME#$SYNCROOT}"
		elif [ $DRY_RUN -ne 1 ]; then
			upload_file_buffered "$FILE_NAME"
		fi
	done < "$TMP_GITFTP_UPLOAD"
	fire_upload_buffer

	while IFS= read -r -d '' FILE_NAME; do
		(( DONE_ITEMS++ ))
		print_info "[$DONE_ITEMS of $TOTAL_ITEMS] Buffered for delete '$FILE_NAME'."
		if [ $DRY_RUN -ne 1 ]; then
			local file="${FILE_NAME#$SYNCROOT}"
			delete_file_buffered "$file"
		fi
	done < "$TMP_GITFTP_DELETE"
	fire_delete_buffer
}

handle_submodule_sync() {
	print_info "Handling submodule sync for $1."

	# Changed by Rafael Silva
	if [ -n "$PASSPHRASE" ]; then
        ARG_PASSPHRASE="--passphrase ${PASSPHRASE}"
    elif [ -n "$(get_config passphrase)" ]; then
		PASSPHRASE=$(get_config passphrase)
		ARG_PASSPHRASE="--passphrase ${PASSPHRASE}"
	fi

	set_submodule_args
	(
		cd "${SYNCROOT}$1" && "$0" "$ACTION" "${args[@]}" --auto-init --submodule $ARG_PASSPHRASE "$REMOTE_PROTOCOL://$REMOTE_HOST/${REMOTE_PATH}$1"
	)

	local EXIT_CODE=$?

	# Pushing failed. Submodule may not be initialized
	if [ "$EXIT_CODE" -eq "$ERROR_DOWNLOAD" ] && [ "$ACTION" == "push" ]; then
		print_info "Could not push $1, trying to init..."
		(
			cd "${SYNCROOT}$1" && "$0" init "${args[@]}" "$REMOTE_PROTOCOL://$REMOTE_HOST/${REMOTE_PATH}$1"
		)
		check_exit_status "Failed to sync submodules." "$ERROR_UPLOAD"
	elif [ $EXIT_CODE -ne 0 ]; then
		print_error_and_die "Failed to sync submodules." "$ERROR_UPLOAD"
	fi
}

submodule_catchup() {
	[ -z "$GIT_SUBMODULES" ] && return
	set_submodule_args
	url="$(git config git-ftp.url)"
	print_info "Submodules are $GIT_SUBMODULES"
	for submodule in "${GIT_SUBMODULES[@]}"
	do
		print_info "Catching up submodule $submodule."
		cd "${SYNCROOT}$submodule" && "$0" "$ACTION" "${args[@]}" "$REMOTE_PROTOCOL://$REMOTE_HOST/${REMOTE_PATH}$submodule"
	done
}

set_submodule_args() {
	args=(--user "$REMOTE_USER")
	[ -n "$REMOTE_PASSWD" ] && args+=(--passwd "$REMOTE_PASSWD")
	[ -n "$CURL_PRIVATE_KEY" ] && args+=(--key "$CURL_PRIVATE_KEY")
	[ -n "$CURL_PUBLIC_KEY" ] && args+=(--pubkey "$CURL_PUBLIC_KEY")	

	# Do not ask any questions for submodules
	args+=(--force)

	if [ $ACTIVE_MODE -eq 1 ]; then
		args+=(--active)
	else
		if [ $CURL_DISABLE_EPSV -eq 1 ]; then
			args+=(--disable-epsv)
		fi
	fi

	[ $INSECURE -eq 1 ] && args+=(--insecure)
	[ $IGNORE_DEPLOYED -eq 1 ] && args+=(--all)

	if [ $VERBOSE -eq 1 ]; then
		args+=(--verbose)
	elif [ $VERBOSE -eq -1 ]; then
		args+=(--silent)
	fi

	[ $DRY_RUN -eq 1 ] && args+=(--dry-run)
}

handle_remote_protocol_options() {
	if [ "$REMOTE_PROTOCOL" = "sftp" ]; then
		set_sftp_config

		if [ -n "$CURL_PRIVATE_KEY" ]; then
			write_log "Using ssh private key file $CURL_PRIVATE_KEY"
			REMOTE_CMD_OPTIONS+=("--key" "$CURL_PRIVATE_KEY")
		fi
		if [ -n "$CURL_PUBLIC_KEY" ]; then
			write_log "Using ssh public key file $CURL_PUBLIC_KEY"
			REMOTE_CMD_OPTIONS+=("--pubkey" "$CURL_PUBLIC_KEY")
		elif [ -f "${CURL_PRIVATE_KEY}.pub" -a -r "${CURL_PRIVATE_KEY}.pub" ]; then
			write_log "Automatically using ssh public key file ${CURL_PRIVATE_KEY}.pub"
			REMOTE_CMD_OPTIONS+=("--pubkey" "${CURL_PRIVATE_KEY}.pub")
		fi

		# SFTP uses a different remove command and uses absolute paths
		REMOTE_DELETE_CMD="rm /"
	fi

	# Check for using cacert
	if [ "$REMOTE_PROTOCOL" = "ftpes" -o "$REMOTE_PROTOCOL" = "ftps" ] && \
	[ -n "$REMOTE_CACERT" -a -r "$REMOTE_CACERT" ]; then
		REMOTE_CMD_OPTIONS+=("--cacert" "$REMOTE_CACERT")
	fi

	# Options for curl if using FTPES
	if [ "$REMOTE_PROTOCOL" = "ftpes" ]; then
		CURL_PROTOCOL="ftp"
		REMOTE_CMD_OPTIONS+=("--ssl")
	fi

	# Require users' explicit consent for insecure connections
	[ $INSECURE -eq 1 ] && REMOTE_CMD_OPTIONS+=("-k")
}

handle_lftp_settings() {
	LFTP_PROTOCOL="$REMOTE_PROTOCOL"
	# Options for lftp if using FTPES
	if [ "$REMOTE_PROTOCOL" = "ftpes" ]; then
		LFTP_PROTOCOL="ftp"
		LFTP_COMMAND_SETTINGS+="set ftp:ssl-force true && "
		LFTP_COMMAND_SETTINGS+="set ftp:ssl-protect-data true && "
		LFTP_COMMAND_SETTINGS+="set ftp:ssl-protect-list true && "
	fi

	[ $INSECURE -eq 1 ] && LFTP_COMMAND_SETTINGS+="set ssl:verify-certificate no && "
	LFTP_COMMAND_SETTINGS+="set ftp:list-options -a &&"
}

init_new_repository() {
	[ -z "$URL" ] && print_error_and_die "Error: give a URL to snapshot." "$ERROR_USAGE"

	# Use the last part of the URL as destination directory by default
	[ -z "$SNAPSHOT_DIR" ] && SNAPSHOT_DIR="$(basename "$URL")"

	DEPLOYED_SHA1="$(get_file_content "$DEPLOYED_SHA1_FILE")"
	if [ "$DEPLOYED_SHA1" != "" ]; then
		print_error_and_die "Commit found at $URL/$DEPLOYED_SHA1_FILE.

The remote directory is managed by another Git repository already. If you want
to start using a new repository, then delete $DEPLOYED_SHA1_FILE first. The old
repository will not be able to deploy to this remote any more. Aborting." "$ERROR_USAGE"
	fi

	# Make sure the destination directory exists
	mkdir -p "$SNAPSHOT_DIR" || print_error_and_die "Error creating directory '$SNAPSHOT_DIR'. Aborting." "$ERROR_FILESYSTEM"

	if [ "$(ls -A "$SNAPSHOT_DIR")" ]; then
		print_error_and_die "Error: The destination directory '$SNAPSHOT_DIR' is not empty. Aborting." "$ERROR_FILESYSTEM"
	fi

	cd "$SNAPSHOT_DIR" || print_error_and_die "Error entering '$SNAPSHOT_DIR'. Aborting." "$ERROR_FILESYSTEM"
	info="$(git init)" || print_error_and_die "Error initialising Git repository." "$ERROR_GIT"
	print_info "$info"
}

commit_snapshot() {
	git add . > /dev/null || print_error_and_die "Git: error adding changed files" "$ERROR_GIT"
	git commit -m "Download $URL with git-ftp" -q  > /dev/null || print_error_and_die "Git: error committing the changes" "$ERROR_GIT"
}

handle_action() {
	case "$ACTION" in
		init)
			action_init
			;;
		push)
			action_push
			;;
		catchup)
			action_catchup
			;;
		show)
			action_show
			;;
		log)
			action_log
			;;
		download)
			action_download
			;;
		pull)
			action_pull
			;;
		snapshot)
			action_snapshot
			;;
		add-scope)
			action_add_scope
			;;
		remove-scope)
			action_remove_scope
			;;
		*)
			print_error_and_die "Action unknown." "$ERROR_MISSING_ARGUMENTS"
			;;
	esac
}

set_remote_user() {
	[ -z $REMOTE_USER ] && REMOTE_USER="$(get_config user)"
}

set_remote_cacert() {
	[ -z $REMOTE_CACERT ] && REMOTE_CACERT="$(get_config cacert)"
}

set_remote_password() {
	KEYCHAIN_USER="$(get_config keychain)"
	[ -z "$KEYCHAIN_USER" ] || USE_KEYCHAIN=1
	[ -z "$REMOTE_PASSWD" ] && [ $USE_KEYCHAIN -eq 1 ] && get_keychain_password "$KEYCHAIN_USER"
	[ -z "$REMOTE_PASSWD" ] && REMOTE_PASSWD="$(get_config password)"
}

set_branch() {
	: "${BRANCH:=$(get_config branch)}"
	if [ -n "$BRANCH" ]; then
		set_current_branch
		write_log "Checkout on branch $BRANCH"
		git checkout "$BRANCH" > /dev/null 2>&1 || print_error_and_die "'$BRANCH' is not a valid branch! Exiting..." "ERROR_GIT"
	fi
}

unset_branch() {
	if [ -n "$CURRENT_BRANCH" ]; then
		write_log "Checkout on branch $CURRENT_BRANCH"
		git checkout "$CURRENT_BRANCH" > /dev/null 2>&1
	fi
}

set_syncroot() {
	[ -z "$SYNCROOT" ] && SYNCROOT="$(get_config syncroot)"
	[ -z "$SYNCROOT" ] && SYNCROOT="."
	if [ "$SYNCROOT" ]; then
		[ -d "$SYNCROOT" ] || print_error_and_die "'$SYNCROOT' is not a directory! Exiting..." "$ERROR_GIT"
		SYNCROOT="$(echo "$SYNCROOT" | sed 's#/*$##')/"
	fi
	write_log "Syncroot is '$SYNCROOT'."
}

set_sftp_config() {
	[ -z "$CURL_PRIVATE_KEY" ] && CURL_PRIVATE_KEY="$(get_config key)"
	[ -z "$CURL_PUBLIC_KEY" ] && CURL_PUBLIC_KEY="$(get_config pubkey)"
}

set_tmp() {
	if command -v mktemp > /dev/null 2>&1; then
		TMP_DIR="$(mktemp -d -t git-ftp-XXXXXX)"
	else
		TMP_DIR="$(pwd)/.git/git-ftp-tmp"
		mkdir -p "$TMP_DIR"
	fi
	TMP_CURL_UPLOAD_FILE="$TMP_DIR/curl_upload_list"
	TMP_CURL_DELETE_FILE="$TMP_DIR/curl_delete_list"
	TMP_GITFTP_UPLOAD="$TMP_DIR/upload_tmp"
	TMP_GITFTP_DELETE="$TMP_DIR/delete_tmp"
	TMP_GITFTP_INCLUDE="$TMP_DIR/include_tmp"
}

set_remotes() {
	set_remote_host
	write_log "Host is '$REMOTE_HOST'."

	set_remote_user
	write_log "User is '$REMOTE_USER'."

	set_remote_password
	if [ -z "$REMOTE_PASSWD" ]; then
		write_log "No password is set."
	else
		write_log "Password is set."
	fi

	local REMOTE_LOGIN=''
	local DISPLAY_LOGIN=''
	if [ ! -z "$REMOTE_USER" ]; then
		local ENC_USER="$(urlencode "$REMOTE_USER")"
		local ENC_PASSWD="$(urlencode "$REMOTE_PASSWD")"
		REMOTE_LOGIN="$ENC_USER":"$ENC_PASSWD"@
		DISPLAY_LOGIN="$ENC_USER":'***'@
	fi

	set_remote_cacert
	write_log "CACert is '$REMOTE_CACERT'."

	set_insecure
	write_log "Insecure is '$INSECURE'."
	
	set_curl_disable_epsv
	[ $CURL_DISABLE_EPSV -eq 1 ] && write_log "Disable EPSV is '$CURL_DISABLE_EPSV'."

	set_curl_proxy
	write_log "Proxy is '$CURL_PROXY'."

	set_remote_protocol
	set_remote_path
	write_log "Path is '$REMOTE_PATH'."

	REMOTE_BASE_URL="$CURL_PROTOCOL://$REMOTE_LOGIN$REMOTE_HOST"
	REMOTE_BASE_URL_DISPLAY="$REMOTE_PROTOCOL://$DISPLAY_LOGIN$REMOTE_HOST"

	set_deployed_sha1_file
	write_log "The remote sha1 is saved in file '$DEPLOYED_SHA1_FILE'."
}

# Original implementation http://stackoverflow.com/a/10660730/3377535
urlencode() {
	local string="${1}"
	local strlen=${#string}
	local keepset='[-_.~a-zA-Z0-9]'
	[ $# -gt 1 ] && keepset="${2}"
	local encoded=""
	for (( pos=0 ; pos<strlen ; pos++ )); do
		c=${string:$pos:1}
		case "$c" in
			$keepset ) o="${c}" ;;
			* ) printf -v o '%%%02x' "'$c"
		esac
		encoded+="${o}"
	done
	echo "${encoded}"
}

set_insecure() {
	local config="$(get_config insecure)"
	[ -n "$config" ] && INSECURE="$(boolean $config)"
}

set_curl_disable_epsv() {
	local config="$(get_config disable-epsv)"
	[ -n "$config" ] && CURL_DISABLE_EPSV="$(boolean $config)"
}

set_curl_proxy() {
	[ -z "$CURL_PROXY" ] && CURL_PROXY="$(get_config proxy)"
	[ -z "$CURL_PROXY" ] && CURL_PROXY="$(git config --get http.proxy)"
}

set_merge_args() {
	local config="$(get_config no-commit)"
	[ -n "$config" ] && NO_COMMIT=1
	
	if [ $NO_COMMIT -eq 1 ]; then
		MERGE_ARGS="$MERGE_ARGS --no-commit --no-ff"
	fi
}

get_protocol_of_url() {
	echo "$1" | tr '[:upper:]' '[:lower:]' | egrep '^(ftp|sftp|ftps|ftpes)://' | cut -d ':' -f 1
}

download_remote_updates () {
	write_log "Mirroring ${REMOTE_HOST}/${REMOTE_PATH}"
	local mirror_options=''
	if [ "$DRY_RUN" = 1 ]; then
		mirror_options="$mirror_options --dry-run"
	fi
	if [ "$VERBOSE" -gt 0 ]; then
		mirror_options="$mirror_options -v"
	fi

	delete="--delete"
	include=""
	ignoreall=""
	# Mirror only the files from the diff between the FTP commit and the current branch/commit
	if [ "$DOWNLOAD_CHANGED_ONLY" -eq 1 ] && [ -n "$CURRENT_BRANCH" ]; then
		delete=""
		ignoreall=" --exclude '.*' --exclude '.*/'"
		include="$(git diff "$CURRENT_BRANCH" --name-only | sed 's/^\(.*\)$/ --include "\1"/' | tr -d '\r\n')"
		filenames="$(git diff $CURRENT_BRANCH --name-only | sed 's/^/\t/')"
		write_log "Only pulling diff files:$'\n'$filenames"
	fi

	ignore=""
	if [ -f '.git-ftp-ignore' ]; then
		ignore="$(grep -v '^#' .git-ftp-ignore | awk 'NF' | sed 's/^\(.*\)$/--exclude-glob "\1" /' | tr -d '\r\n') "
	fi
	ignore+="--exclude=^\.git/ --exclude=^\.git-ftp\.log --exclude=^\.git-ftp-ignore"

	handle_lftp_settings
	
	local lftp_cd=""
	[ -n $REMOTE_PATH ] && lftp_cd="cd ${REMOTE_PATH} &&"
	local lftp_action="mirror $mirror_options $delete $ignoreall $include $ignore . $SYNCROOT &&"
	local lftp_exit="wait all && exit"
	
	lftp_command="$LFTP_COMMAND_SETTINGS $lftp_cd $lftp_action $lftp_exit"
	out="$(lftp $LFTP_OPTIONS -e "$lftp_command" -u "${REMOTE_USER},${REMOTE_PASSWD}" "${LFTP_PROTOCOL}://${REMOTE_HOST}/" 2>&1)"
	print_info "$out"
}

set_scope() {
	[ -z "$SCOPE" ] && print_error_and_die "Missing scope argument." "$ERROR_MISSING_ARGUMENTS"
	[ -z "$URL" ] && print_error_and_die "Missing URL." "$ERROR_MISSING_ARGUMENTS"

	# URI without credentials
	if ! echo "$URL" | grep -q '@'; then
		git config "git-ftp.$SCOPE.url" "$URL"
		return
	fi

	# set url
	local protocol=$(get_protocol_of_url "$URL")
	local path="${URL##*@}"
	git config "git-ftp.$SCOPE.url" "${protocol}://${path}"

	# strip protocol
	local credentials=${URL#${protocol}://}
	# cut at last '@' occurrence
	local credentials=${credentials%${URL##*@}}
	# strip trailing '@'
	local credentials=${credentials%?}

	local colons=${credentials//[^:]/}
	case ${#colons} in
		0)
			# assume only username
			git config "git-ftp.$SCOPE.user" "${credentials}"
			;;
		1)
			# credentials have both username and password
			git config "git-ftp.$SCOPE.user" "${credentials%:*}"
			git config "git-ftp.$SCOPE.password" "${credentials#*:}"
			;;
		*)
			# we can't know where to cut with multiple ':'
			print_info "Warning, multiple ':' characters detected, only URL was set in scope."
			print_info "Use --user and --passwd options to set login and password respectively."
	esac
}

remove_scope() {
	[ -z "$SCOPE" ] && print_error_and_die "Missing scope argument." "$ERROR_MISSING_ARGUMENTS"

	git config --remove-section "git-ftp.$SCOPE" &>/dev/null

	[ $? -ne 0 ] && print_error_and_die "Cannot find scope $SCOPE." "$ERROR_GIT"
	print_info "Successfully removed scope $SCOPE."
}

set_current_branch() {
	local current="$( (git symbolic-ref HEAD 2> /dev/null || git rev-parse HEAD 2> /dev/null) | sed "s#^refs/heads/##")"
	if [ "$?" -ne "0" ]; then
		set_local_sha1
		current="$LOCAL_SHA1"
	fi
	write_log "currently on branch $current"
	CURRENT_BRANCH="$current"
}

fetch_remote() {
	download_remote_updates
	[ $DRY_RUN -ne 1 ] || return
	git add --all
	git commit -m '[git-ftp] remotely untracked modifications' -m "`git diff HEAD --name-status`" | grep -v '^#'
	set_local_sha1
	upload_local_sha1
}

handle_fetch() {
	local old_sha1=$DEPLOYED_SHA1
	git checkout $DEPLOYED_SHA1 2> /dev/null
	# If .gitignore changes between commits, untracked file can remain.
	# These files are preserved in a stash record.
	local stash=$(git stash -u)
	remote_lock
	fetch_remote
	release_remote_lock
	[ "$stash" != 'No local changes to save' ] && git stash pop
	git checkout "$CURRENT_BRANCH" 2> /dev/null
	if [ $DRY_RUN -ne 1 ] && [ $old_sha1 != $LOCAL_SHA1 ]; then
		print_info "From $REMOTE_HOST/$REMOTE_PATH"
		print_info "   $old_sha1..$LOCAL_SHA1"
	fi
}

# ------------------------------------------------------------
# Actions
# ------------------------------------------------------------
action_init() {
	check_git_version
	check_is_git_project
	check_is_dirty_repository
	set_branch
	set_remotes
	check_curl_access
	check_remote_access
	check_deployed_sha1
	set_local_sha1
	set_changed_files
	pre_push_hook
	remote_lock
	handle_file_sync
	upload_local_sha1
	release_remote_lock
	post_push_hook
	unset_branch
}

action_push() {
	check_git_version
	check_is_git_project
	check_is_dirty_repository
	set_branch
	set_remotes
	check_curl_access
	set_deployed_sha1_for_push
	set_local_sha1
	set_changed_files
	pre_push_hook
	remote_lock
	handle_file_sync
	upload_local_sha1
	release_remote_lock
	post_push_hook
	unset_branch
}

action_catchup() {
	check_is_git_project
	check_is_dirty_repository
	set_branch
	set_remotes
	check_curl_access
	set_local_sha1
	upload_local_sha1
	submodule_catchup
	unset_branch
}

action_show() {
	set_remotes
	check_curl_access
	DEPLOYED_SHA1="$(get_file_content "$DEPLOYED_SHA1_FILE")"
	check_exit_status "Could not get uploaded log file" "$ERROR_DOWNLOAD"
	git show "$DEPLOYED_SHA1"
}

action_log() {
	set_remotes
	check_curl_access
	DEPLOYED_SHA1="$(get_file_content "$DEPLOYED_SHA1_FILE")"
	check_exit_status "Could not get uploaded log file" "$ERROR_DOWNLOAD"
	git log "$DEPLOYED_SHA1"
}

action_download() {
	check_lftp_available
	check_is_git_project
	check_is_dirty_repository
	check_for_untracked_files
	set_remotes
	check_curl_access
	remote_lock
	download_remote_updates
	release_remote_lock
}

action_pull() {
	check_lftp_available
	check_is_git_project
	check_is_dirty_repository
	set_current_branch
	set_remotes
	check_curl_access
	set_deployed_sha1
	handle_fetch
	set_merge_args
	git merge $MERGE_ARGS $LOCAL_SHA1
}

action_snapshot() {
	check_lftp_available
	set_remotes
	check_curl_access
	init_new_repository
	download_remote_updates
	commit_snapshot
	action_catchup
}

action_add_scope() {
	check_is_git_project
	set_scope
}

action_remove_scope() {
	check_is_git_project
	remove_scope
}
# ------------------------------------------------------------
# Checks
# ------------------------------------------------------------
check_curl_access() {
	write_log "Check if curl is functional."
	command -v curl >/dev/null 2>&1
	check_exit_status "curl is not available" "$ERROR_DOWNLOAD"

	local curl_protocol="$REMOTE_PROTOCOL"
	# The ftpes protocol is FTP + SSL
	if [ "$curl_protocol" == "ftpes" ]; then
		curl_protocol="ftp"
		curl --version | grep "^Features: " | grep -qw "SSL"
		check_exit_status "Protocol '$REMOTE_PROTOCOL' not supported by curl" "$ERROR_DOWNLOAD"
	fi
	curl --version | grep "^Protocols: " | grep -qw "$curl_protocol"
	check_exit_status "Protocol '$REMOTE_PROTOCOL' not supported by curl" "$ERROR_DOWNLOAD"
}
check_remote_access() {
	write_log "Check if $REMOTE_BASE_URL_DISPLAY is accessible."
	set_default_curl_options
	CURL_ARGS+=(--ftp-create-dirs)
	CURL_ARGS+=("$REMOTE_BASE_URL/$REMOTE_PATH")

	curl "${CURL_ARGS[@]}" > /dev/null
	
	local EXIT_CODE=$?
	if [ "$REMOTE_PROTOCOL" == "sftp" ] && [ $EXIT_CODE -eq 78 ]; then
		write_log "Create $REMOTE_PATH"
		
		# Changed by Rafael Silva
		if [ -z "$ENABLE_SUBMODULE" ]; then
			curl "${CURL_ARGS[@]}" -Q "MKDIR $REMOTE_PATH" > /dev/null
		else
			curl "${CURL_ARGS[@]}.." -Q "-MKDIR $(echo "$REMOTE_PATH" | sed 's|~/||g')" > /dev/null
		fi

		EXIT_CODE=$?
	fi

	check_curl_exit_status "$EXIT_CODE" "" "$ERROR_UPLOAD"
}

check_deployed_sha1() {
	write_log "Check if $REMOTE_BASE_URL_DISPLAY/$REMOTE_PATH is clean."
	DEPLOYED_SHA1="$(get_file_content "$DEPLOYED_SHA1_FILE")"
	if [ "$DEPLOYED_SHA1" != "" ]; then
		print_error_and_die "Commit found, use 'git ftp push' to sync. Exiting..." "$ERROR_USAGE"
	fi
	# Make sure if sync all files if no sha1 was found
	IGNORE_DEPLOYED=1
}

check_git_version() {
	local GIT_VERSION="$(git --version | cut -d ' ' -f 3)"
	local MAJOR="$(echo "$GIT_VERSION" | cut -d '.' -f 1)"
	local MINOR="$(echo "$GIT_VERSION" | cut -d '.' -f 2)"
	if [ "$MAJOR" -lt 2 ] && [ "$MINOR" -lt 7 ]; then
		print_error_and_die "Git is too old, 1.7.0 or higher supported only." "$ERROR_GIT"
	fi
}

check_remote_lock() {
	write_log "Checking remote lock."
	local LCK_CONTENT="$(get_file_content "$REMOTE_LCK_FILE" 2>/dev/null)"
	if [ -n "$LCK_CONTENT" ]; then
		local LCK_SHA1=$(echo "$LCK_CONTENT" | head -n 1)
		write_log "Remote lock sha1 $LCK_SHA1."
		write_log "Local sha1 $LOCAL_SHA1."
		if [ "$LCK_SHA1" != "$LOCAL_SHA1" ]; then
			local LCK_USER=$(echo "$LCK_CONTENT" | tail -n 1)
			print_error_and_die "Remote locked by $LCK_USER." "$ERROR_REMOTE_LOCKED"
		fi
	fi
}

check_is_git_project() {
	local git_project_dir="$(git rev-parse --show-toplevel 2>/dev/null)"
	[ -z "$git_project_dir" ] &&  print_error_and_die "Not a Git project? Exiting..." "$ERROR_GIT"
	cd "$git_project_dir"
}

check_is_dirty_repository() {
	[ "$(git status -uno --porcelain | wc -l)" -ne 0 ] && print_error_and_die "Dirty repository: Having uncommitted changes. Exiting..." "$ERROR_GIT"
}

check_for_untracked_files() {
	[ $(git status --porcelain | wc -l) -ne 0 ] && print_error_and_die "Dirty repository: Having untracked files. Exiting..." $ERROR_GIT
}

check_lftp_available() {
	command -v lftp > /dev/null || print_error_and_die "lftp not found. This operation requires lftp installed." $ERROR_GIT
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
main() {
	set_syncroot
	cache_git_submodules
	handle_action
	cleanup
	print_error_log
	exit 0
}

write_log "git-ftp version $VERSION running on $(uname -a)"

# 2 args are needed: action and url
if [ $# = 0 ]; then
	usage;
fi

while test $# != 0
do
	case "$1" in
		init|push|catchup|show|download|pull|add-scope|remove-scope|log|snapshot)
			ACTION="$1"
			# catch scope
			if [ "$1" == "add-scope" ] || [ "$1" == "remove-scope" ]; then
				SCOPE="$2"
				if ! echo "$SCOPE" | grep -q '^[-0-9a-zA-Z_/]*$' ; then
					print_error_and_die "Invalid scope name. Only these characters are allowed: 0-9 a-z A-Z - _ /" "$ERROR_USAGE"
				fi
				shift
			fi
			;;
		-h|--h|--he|--hel|--help|help)
			usage_long
			;;
		-u|--user*)
			case "$#,$1" in
				*,*=*)
					REMOTE_USER=$(expr "z$1" : 'z-[^=]*=\(.*\)')
					;;
				1,*)
					REMOTE_USER="$USER"
					;;
				*)
					if ! echo "$2" | egrep -q '^-'; then
						REMOTE_USER="$2"
						shift
					else
						REMOTE_USER="$USER"
					fi
					;;
			esac
			;;
		-s|--scope*)
			case "$#,$1" in
				*,*=*)
					SCOPE=$(expr "z$1" : 'z-[^=]*=\(.*\)')
					;;
				1,*)
					check_is_git_project && SCOPE="$(git rev-parse --abbrev-ref HEAD)"
					;;
				*)
					if ! echo "$2" | egrep -q '^-'; then
						SCOPE="$2"
						shift
					else
						check_is_git_project && SCOPE="$(git rev-parse --abbrev-ref HEAD)"
					fi
					;;
			esac
			if ! echo "$SCOPE" | grep -q '^[-0-9a-zA-Z_/]*$' ; then
				print_error_and_die "Invalid scope name '${SCOPE}'." "$ERROR_USAGE"
			fi
			write_log "Using scope $SCOPE if available"
			;;
		-b|--branch*)
			case "$#,$1" in
				*,*=*)
					BRANCH=$(expr 'z$1' : 'z-[^=]*=\(.*\)')
					;;
				1,*)
					print_error_and_die "Too few arguments for option --branch." "$ERROR_MISSING_ARGUMENTS"
					;;
				*)
					if ! echo "$2" | egrep -q '^-'; then
						BRANCH="$2"
						shift
					else
						print_error_and_die "Too few arguments for option --branch." "$ERROR_MISSING_ARGUMENTS"
					fi
					;;
			esac
			;;
		--syncroot*)
			case "$#,$1" in
				*,*=*)
					SYNCROOT="$(expr "z$1" : 'z-[^=]*=\(.*\)')"
					;;
				1,*)
					print_error_and_die "Too few arguments for option --syncroot." "$ERROR_MISSING_ARGUMENTS"
					;;
				*)
					if ! echo "$2" | egrep -q '^-'; then
						SYNCROOT="$2"
						shift
					else
						print_error_and_die "Too few arguments for option --syncroot." "$ERROR_MISSING_ARGUMENTS"
					fi
					;;
			esac
			write_log "Using syncroot $SYNCROOT if exists."
			;;
		-c|--commit*)
			case "$#,$1" in
				*,*=*)
					DEPLOYED_SHA1=$(expr "z$1" : 'z-[^=]*=\(.*\)')
					;;
				1,*)
					print_error_and_die "Too few arguments for option -c." "$ERROR_MISSING_ARGUMENTS"
					;;
				*)
					if ! echo "$2" | egrep -q '^-'; then
						DEPLOYED_SHA1="$2"
						shift
					else
						print_error_and_die "Too few arguments for option -c." "$ERROR_MISSING_ARGUMENTS"
					fi
					;;
			esac
			write_log "Using commit $DEPLOYED_SHA1 as deployed."
			;;
		-p|--passwd*)
			case "$#,$1" in
				*,*=*)
					REMOTE_PASSWD=$(expr "z$1" : 'z-[^=]*=\(.*\)')
					;;
				1,*)
					print_error_and_die "Too few arguments for option -p." "$ERROR_MISSING_ARGUMENTS"
					;;
				*)
					if ! echo "$2" | egrep -q '^-'; then
						REMOTE_PASSWD="$2"
						shift
					else
						print_error_and_die "Too few arguments for option -p. Maybe the manual will help: https://github.com/git-ftp/git-ftp/blob/master/man/git-ftp.1.md#passwords" "$ERROR_MISSING_ARGUMENTS"
					fi
					;;
			esac
			;;
		--passphrase)
			PASSPHRASE="$2"
			shift
			;;
		-P|--ask-passwd)
			ask_for_passwd
			;;
		-k|--keychain*)
			USE_KEYCHAIN=1
			write_log "Enabled keychain."
			case "$#,$1" in
				*,*=*)
					KEYCHAIN_USER=$(expr "z$1" : 'z-[^=]*=\(.*\)')
					;;
				1,*)
					# Nothing is handed over, this is okay
					;;
				*)
					if ! echo "$2" | egrep -q '^-'; then
						KEYCHAIN_USER="$2"
						shift
					fi
					;;
			esac
			;;
		-a|--all)
			IGNORE_DEPLOYED=1
			;;
		-l|--lock)
			if [ $ENABLE_REMOTE_LCK -ne 1 ]; then
				write_log "Enabling remote locking feature."
				ENABLE_REMOTE_LCK=1
			else
				write_log "Disabling remote locking feature."
				ENABLE_REMOTE_LCK=0
			fi
			;;
		-D|--dry-run)
			DRY_RUN=1
			write_log "Running dry, won't do anything."
			;;
		-n|--silent)
			VERBOSE=-1
			REMOTE_CMD_OPTIONS=("-s")
			;;
		-v|--verbose)
			VERBOSE=1
			[ -n "$LOG_CACHE" ] && echo -e "$LOG_CACHE"
			REMOTE_CMD_OPTIONS=()
			;;
		-vv)
			VERBOSE=1
			[ -n "$LOG_CACHE" ] && echo -e "$LOG_CACHE"
			REMOTE_CMD_OPTIONS=("-v")
			LFTP_OPTIONS="-d"
			;;
		-f|--force)
			FORCE=1
			write_log "Forced mode enabled."
			;;
		--version|version)
			echo "git-ftp version $VERSION"
			exit 0
			;;
		--insecure)
			INSECURE=1
			write_log "Insecure SSL/TLS connection allowed"
			;;
		--cacert*)
			case "$#,$1" in
				*,*=*)
					REMOTE_CACERT=$(expr "z$1" : 'z-[^=]*=\(.*\)')
					;;
				1,*)
					print error_and_die "Too few arguments for option --cacert" "$ERROR_MISSING_ARGUMENTS"
					;;
				*)
					if ! echo "$2" | egrep -q '^-'; then
						REMOTE_CACERT="$2"
						shift
					else
						print_error_and_die "Too few arguments for option --cacert" "$ERROR_MISSING_ARGUMENTS"
					fi
					;;
			esac
			;;
		--key)
			case "$#,$1" in
				*,*=*)
					CURL_PRIVATE_KEY=$(expr "z$1" : 'z-[^=]*=\(.*\)')
					;;
				1,*)
					print_error_and_die "Too few arguments for option --key." "$ERROR_MISSING_ARGUMENTS"
					;;
				*)
					if ! echo "$2" | egrep -q '^-'; then
						CURL_PRIVATE_KEY="$2"
						shift
					else
						print_error_and_die "Too few arguments for option --key." "$ERROR_MISSING_ARGUMENTS"
					fi
					;;
			esac
			;;
		--pubkey)
			case "$#,$1" in
				*,*=*)
					CURL_PUBLIC_KEY=$(expr "z$1" : 'z-[^=]*=\(.*\)')
					;;
				1,*)
					print_error_and_die "Too few arguments for option --pubkey." "$ERROR_MISSING_ARGUMENTS"
					;;
				*)
					if ! echo "$2" | egrep -q '^-'; then
						CURL_PUBLIC_KEY="$2"
						shift
					else
						print_error_and_die "Too few arguments for option --pubkey." "$ERROR_MISSING_ARGUMENTS"
					fi
					;;
			esac
			;;
		-A|--active)
			ACTIVE_MODE=1
			write_log "Using active mode."
			;;
		--no-commit)
			NO_COMMIT=1
			write_log "Adding --no-commit to merge arguments"
			;;
		--changed-only)
			DOWNLOAD_CHANGED_ONLY=1
			write_log "Downloading only changed files."
			;;
		--disable-epsv)
			if [ $ACTIVE_MODE -eq 0 ]; then
				CURL_DISABLE_EPSV=1
				write_log "Disabling EPSV."
			fi
			;;
		--remote-root)
			REMOTE_ROOT="$2"
			shift
			;;
		--no-verify)
			EXECUTE_HOOKS=0
			shift
			;;
		--enable-post-errors)
			ENABLE_POST_HOOK_ERRORS=1
			shift
			;;
		--auto-init)
			if [ $AUTO_INIT -eq 0 ]; then
				AUTO_INIT=1
				write_log "Auto init if needed."
			fi
			;;
		--submodule)
			ENABLE_SUBMODULE=1
			;;
		-x|--proxy*)
			case "$#,$1" in
				*,*=*)
					CURL_PROXY=$(expr "z$1" : 'z-[^=]*=\(.*\)')
					;;
				1,*)
					print_error_and_die "Too few arguments for option --proxy." "$ERROR_MISSING_ARGUMENTS"
					;;
				*)
					if ! echo "$2" | egrep -q '^-'; then
						CURL_PROXY="$2"
						shift
					else
						print_error_and_die "Too few arguments for option --proxy." "$ERROR_MISSING_ARGUMENTS"
					fi
					;;
			esac
			;;
		*)
			# Pass thru anything that may be meant for fetch.
			if [ -n "$1" ]; then
				if [ -z "$URL" ]; then
					URL="$1"
				elif [ "$ACTION" == "snapshot" -a -z "$SNAPSHOT_DIR" ]; then
					SNAPSHOT_DIR="$1"
				else
					print_error_and_die "Unrecognised option: $1" "$ERROR_MISSING_ARGUMENTS"
				fi
			fi
			;;
	esac
	shift
done
main
