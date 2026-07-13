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

# --- privileged actions (single password prompt each) --------------------

do_activate() {
	ensure_built
	# Everything privileged runs in one admin shell = one password prompt.
	local script
	script="set -e; cd \"$DIR\"; \
		if [ ! -f \"$DVSDIR/ptp-original\" ]; then cp \"$DVSDIR/ptp\" \"$DVSDIR/ptp-original\"; fi; \
		cp ptp-mitm \"$DVSDIR/ptp\"; chown root:admin \"$DVSDIR/ptp\"; chmod 755 \"$DVSDIR/ptp\"; \
		if [ ! -f \"$CONF\" ]; then cp ptp-mitm.conf \"$CONF\"; chmod 644 \"$CONF\"; fi; \
		$RESTART_PTP"
	osa "do shell script \"$script\" with administrator privileges" >/dev/null
	info "MITM wrapper activated and PTP service restarted."
}

do_deactivate() {
	if ! is_installed; then
		info "Wrapper is not installed -- nothing to deactivate."
		return
	fi
	local script
	script="set -e; mv \"$DVSDIR/ptp-original\" \"$DVSDIR/ptp\"; chown root:admin \"$DVSDIR/ptp\"; \
		$RESTART_PTP"
	osa "do shell script \"$script\" with administrator privileges" >/dev/null
	info "Original ptp restored and PTP service restarted."
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
	local body restart=""
	body="# DVS PTP MITM configuration (written by dvs-ptp-mitm.command)\nleader = $new_leader\nptpv2 = $new_ptpv2\n"
	# If the wrapper is active, restart the PTP service so the new options apply.
	is_installed && restart="; $RESTART_PTP"
	osa "do shell script \"printf '$body' > '$CONF'; chmod 644 '$CONF'$restart\" with administrator privileges" >/dev/null
	if is_installed; then
		info "Options saved (leader=$new_leader, ptpv2=$new_ptpv2) and PTP service restarted."
	else
		info "Options saved (leader=$new_leader, ptpv2=$new_ptpv2). They apply once you activate the wrapper."
	fi
}

show_status() {
	local state="not installed"
	is_installed && state="INSTALLED"
	info "Wrapper: $state\nleader = $(conf_get leader)\nptpv2 = $(conf_get ptpv2)\n\nConfig: $CONF"
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
