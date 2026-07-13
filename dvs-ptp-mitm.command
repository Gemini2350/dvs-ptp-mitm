#!/bin/bash
#
# DVS PTP MITM -- one double-click control panel (macOS)
#
# Double-click this file in Finder. It opens a small menu where you can
# activate/deactivate the man-in-the-middle wrapper and toggle its options
# (PTPv2, leader mode) without ever touching the Terminal, a compiler, or
# the config file by hand. Privileged steps ask for your password once via
# the standard macOS dialog.
#
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

DVSDIR="/Library/Application Support/Audinate/DanteVirtualSoundcard"
CONF="$DVSDIR/ptp-mitm.conf"

# --- small helpers -------------------------------------------------------

# Run an AppleScript snippet and return its output.
osa() { osascript -e "$1"; }

# Show a plain informational dialog.
info() {
	osa "display dialog \"$1\" buttons {\"OK\"} default button \"OK\" with title \"DVS PTP MITM\"" >/dev/null 2>&1 || true
}

# Read a boolean key ("1"/"0") from the config file; default 0 if absent.
conf_get() {
	local key="$1"
	if [ -f "$CONF" ]; then
		local v
		v=$(grep -iE "^[[:space:]]*$key[[:space:]]*=" "$CONF" | tail -1 | cut -d= -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
		case "$v" in 1|y|yes|true|on) echo 1 ;; *) echo 0 ;; esac
	else
		echo 0
	fi
}

is_installed() { [ -f "$DVSDIR/ptp-original" ]; }

# Make sure a ptp-mitm binary is available.
# Prefer a prebuilt binary shipped alongside this script (from the GitHub
# release) so no compiler is needed. Only compile from source as a fallback,
# e.g. when running from a plain "git clone".
ensure_built() {
	if [ -f ptp-mitm ]; then
		return					# prebuilt (or previously built) binary present
	fi
	if [ ! -f ptp-mitm.c ]; then
		info "No ptp-mitm binary and no source to build it from. Please download a release."
		exit 1
	fi
	local cc
	cc=$(command -v cc || command -v clang || command -v gcc || true)
	if [ -z "$cc" ]; then
		info "No prebuilt binary found and no C compiler available.\n\nEither download a release (recommended) or run 'xcode-select --install' and try again."
		exit 1
	fi
	"$cc" -arch arm64 -arch x86_64 -o ptp-mitm ptp-mitm.c 2>/dev/null \
		|| "$cc" -o ptp-mitm ptp-mitm.c		# fall back to native-only if universal build fails
}

# Shell snippet (run as root) that restarts the DVS PTP service so changes take
# effect immediately. DVS supervises the ptp process and respawns it, picking up
# the new binary/config. Best-effort: silent if the process is not running.
RESTART_PTP='pkill -f "DanteVirtualSoundcard/ptp" 2>/dev/null || true'

# Run a shell script (passed as $1) as root behind ONE native password prompt.
#
# The script is written to a temp file and executed via
#   do shell script "/bin/bash '<tmp>'" with administrator privileges
# so the AppleScript string contains only a simple path -- never the script's
# own quotes or numbers. (Embedding the shell text directly inside the
# AppleScript string breaks its quoting and triggers osascript syntax errors.)
# Returns the elevated script's exit status; non-zero if the user cancels.
run_admin() {
	local tmp rc
	tmp="$(mktemp -t dvs-ptp-mitm)" || return 1
	printf '%s\n' "$1" > "$tmp"
	osascript -e "do shell script \"/bin/bash '$tmp'\" with administrator privileges" >/dev/null
	rc=$?
	rm -f "$tmp"
	return $rc
}

# --- privileged actions (single password prompt each) --------------------

do_activate() {
	ensure_built
	# All privileged steps run in one elevated shell = one password prompt.
	run_admin "set -e
cd \"$DIR\"
if [ ! -f \"$DVSDIR/ptp-original\" ]; then cp \"$DVSDIR/ptp\" \"$DVSDIR/ptp-original\"; fi
cp ptp-mitm \"$DVSDIR/ptp\"
chown root:admin \"$DVSDIR/ptp\"
chmod 755 \"$DVSDIR/ptp\"
if [ ! -f \"$CONF\" ]; then cp ptp-mitm.conf \"$CONF\"; chmod 644 \"$CONF\"; fi
$RESTART_PTP" \
		&& info "MITM wrapper activated and PTP service restarted." \
		|| info "Activation was cancelled or failed."
}

do_deactivate() {
	if ! is_installed; then
		info "Wrapper is not installed -- nothing to deactivate."
		return
	fi
	run_admin "set -e
mv \"$DVSDIR/ptp-original\" \"$DVSDIR/ptp\"
chown root:admin \"$DVSDIR/ptp\"
$RESTART_PTP" \
		&& info "Original ptp restored and PTP service restarted." \
		|| info "Deactivation was cancelled or failed."
}

# Present checkboxes for the two options and write the config file.
edit_options() {
	local cur_leader cur_ptpv2 preselect selection
	cur_leader=$(conf_get leader)
	cur_ptpv2=$(conf_get ptpv2)

	# Build the pre-selected list for AppleScript "choose from list".
	local sel=()
	[ "$cur_ptpv2" = "1" ] && sel+=("\"PTPv2 support\"")
	[ "$cur_leader" = "1" ] && sel+=("\"Allow DVS to become leader\"")
	preselect=$(IFS=,; echo "${sel[*]:-}")

	selection=$(osa "set chosen to choose from list {\"PTPv2 support\", \"Allow DVS to become leader\"} \
		with title \"DVS PTP MITM options\" \
		with prompt \"Enable which features?\" \
		default items {${preselect}} \
		with multiple selections allowed and empty selection allowed
		if chosen is false then return \"__CANCEL__\"
		set AppleScript's text item delimiters to \"|\"
		return chosen as text") || return

	[ "$selection" = "__CANCEL__" ] && return

	local new_ptpv2=0 new_leader=0
	case "$selection" in *"PTPv2 support"*) new_ptpv2=1 ;; esac
	case "$selection" in *"Allow DVS to become leader"*) new_leader=1 ;; esac

	# Write the config as root (it lives under /Library).
	# Write the config as root (it lives under /Library), restarting the service
	# only if the wrapper is currently active.
	local restart=""
	is_installed && restart="$RESTART_PTP"
	run_admin "set -e
cat > \"$CONF\" <<'CONFEOF'
# DVS PTP MITM configuration (written by dvs-ptp-mitm.command)
leader = $new_leader
ptpv2  = $new_ptpv2
CONFEOF
chmod 644 \"$CONF\"
$restart" || { info "Saving options was cancelled or failed."; return; }
	if is_installed; then
		info "Options saved (PTPv2 $(yesno "$new_ptpv2"), leader mode $(yesno "$new_leader")) and PTP service restarted."
	else
		info "Options saved (PTPv2 $(yesno "$new_ptpv2"), leader mode $(yesno "$new_leader")). They apply once you activate the wrapper."
	fi
}

# Inspect the currently running PTP process to report the EFFECTIVE state --
# what DVS is actually running right now, independent of the config file. Works
# whether or not the wrapper is installed (matches both ptp and ptp-original).
live_status() {
	local proc
	proc=$(ps -axo command= 2>/dev/null | grep 'DanteVirtualSoundcard/ptp' | grep -v grep | head -1)
	if [ -z "$proc" ]; then
		echo "PTP service not running"
		return
	fi
	local p="disabled" l="disabled"
	case " $proc " in *" -y2"*) p="enabled" ;; esac	# wrapper appends -y2=-2 for PTPv2
	case " $proc " in *" -s "*) l="disabled" ;; *) l="enabled" ;; esac	# DVS passes -s for slave-only
	echo "PTPv2 $p, leader mode $l"
}

# Turn a 0/1 config value into a readable word.
yesno() { if [ "$1" = "1" ]; then echo "enabled"; else echo "disabled"; fi; }

show_status() {
	local state="installed" ; is_installed || state="not installed"
	info "Wrapper: $state\n\nConfigured (desired):\n    PTPv2: $(yesno "$(conf_get ptpv2)")\n    Leader mode: $(yesno "$(conf_get leader)")\n\nLive (what DVS runs now):\n    $(live_status)\n\nConfig file: $CONF"
}

# --- main menu loop ------------------------------------------------------

while true; do
	state="not installed"
	is_installed && state="active"
	choice=$(osa "set c to choose from list \
		{\"Activate wrapper\", \"Deactivate wrapper\", \"Edit options (PTPv2 / leader)\", \"Show status\", \"Quit\"} \
		with title \"DVS PTP MITM  (currently: $state)\" \
		with prompt \"What would you like to do?\" \
		default items {\"Show status\"}
		if c is false then return \"Quit\"
		return item 1 of c") || exit 0

	case "$choice" in
		"Activate wrapper")   do_activate ;;
		"Deactivate wrapper") do_deactivate ;;
		"Edit options"*)      edit_options ;;
		"Show status")        show_status ;;
		"Quit"|"")            exit 0 ;;
	esac
done
