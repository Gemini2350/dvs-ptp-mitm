#!/bin/bash
#
# Build "DVS PTP MITM.app" as a self-contained bundle.
#
# It compiles the AppleScript launcher and copies the control-panel script, the
# default config, and (if already built) the ptp-mitm binary INTO the bundle's
# Resources folder. Bundling everything keeps the app working under macOS App
# Translocation, where a downloaded app runs from a randomized read-only path
# and cannot see files sitting next to it.
#
set -euo pipefail
cd "$(dirname "$0")"

APP="DVS PTP MITM.app"
RES="$APP/Contents/Resources"

rm -rf "$APP"
osacompile -o "$APP" app-src.applescript

cp dvs-ptp-mitm.command "$RES/"
cp ptp-mitm.conf        "$RES/"
chmod +x "$RES/dvs-ptp-mitm.command"

# Include the compiled binary if it exists (release builds); a plain source
# checkout won't have it, and the control panel will compile it on first use.
if [ -f ptp-mitm ]; then
	cp ptp-mitm "$RES/"
	chmod +x "$RES/ptp-mitm"
fi

# Re-sign (ad-hoc) AFTER adding resources. osacompile signs the freshly built
# app, but copying files into Resources invalidates that seal, and macOS reports
# a bundle with a broken signature as "damaged" when it was downloaded. Signing
# again re-seals the added files so the app opens (via right-click -> Open).
codesign --force --deep --sign - "$APP"
codesign --verify --strict "$APP" && echo "signature OK"

echo "Built $APP"
