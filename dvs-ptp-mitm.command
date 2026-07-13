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

# Compile ptp-mitm if the binary is missing or older than the source.
ensure_built() {
	if [ ! -f ptp-mitm ] || [ ptp-mitm.c -nt ptp-mitm ]; then
		local cc
		cc=$(command -v cc || command -v clang || command -v gcc || true)
		if [ -z "$cc" ]; then
			info "No C compiler found. Please run 'xcode-select --install' first, then try again."
			exit 1
		fi
		"$cc" -o ptp-mitm ptp-mitm.c
	fi
}

# --- privileged actions (single password prompt each) --------------------

do_activate() {
	ensure_built
	# Everything privileged runs in one admin shell = one password prompt.
	local script
	script="set -e; cd \"$DIR\"; \
		if [ ! -f \"$DVSDIR/ptp-original\" ]; then cp \"$DVSDIR/ptp\" \"$DVSDIR/ptp-original\"; fi; \
		cp ptp-mitm \"$DVSDIR/ptp\"; chown root:admin \"$DVSDIR/ptp\"; chmod 755 \"$DVSDIR/ptp\"; \
		if [ ! -f \"$CONF\" ]; then cp ptp-mitm.conf \"$CONF\"; chmod 644 \"$CONF\"; fi"
	osa "do shell script \"$script\" with administrator privileges" >/dev/null
	info "MITM wrapper activated. Restart the Dante Virtual Soundcard for changes to take effect."
}

do_deactivate() {
	if ! is_installed; then
		info "Wrapper is not installed -- nothing to deactivate."
		return
	fi
	local script
	script="set -e; mv \"$DVSDIR/ptp-original\" \"$DVSDIR/ptp\"; chown root:admin \"$DVSDIR/ptp\""
	osa "do shell script \"$script\" with administrator privileges" >/dev/null
	info "Original ptp restored. Restart the Dante Virtual Soundcard for changes to take effect."
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
	local body
	body="# DVS PTP MITM configuration (written by dvs-ptp-mitm.command)\nleader = $new_leader\nptpv2 = $new_ptpv2\n"
	osa "do shell script \"printf '$body' > '$CONF'; chmod 644 '$CONF'\" with administrator privileges" >/dev/null
	info "Options saved (leader=$new_leader, ptpv2=$new_ptpv2). Restart the Dante Virtual Soundcard to apply."
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
