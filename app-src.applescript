-- Source for "DVS PTP MITM.app".
-- Rebuild the app with:   ./build-app.sh   (or see that script)
--
-- The app is a self-contained, Terminal-free launcher. The control-panel
-- script, the prebuilt binary, and the default config all live INSIDE this
-- bundle (Contents/Resources), so it keeps working even when macOS runs a
-- downloaded app from a randomized, read-only location (App Translocation).

on run
	set scriptPath to POSIX path of (path to resource "dvs-ptp-mitm.command")
	do shell script "/bin/bash " & quoted form of scriptPath
end run
