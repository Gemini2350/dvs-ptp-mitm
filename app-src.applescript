-- Source for "DVS PTP MITM.app".
-- Rebuild the app with:   osacompile -o "DVS PTP MITM.app" app-src.applescript
--
-- The app is a thin, Terminal-free launcher: it runs the dvs-ptp-mitm.command
-- sitting next to it, which drives everything through native dialogs.

on run
	set appPosix to POSIX path of (path to me)
	set parentDir to do shell script "cd " & quoted form of appPosix & "/.. && pwd"
	set cmd to parentDir & "/dvs-ptp-mitm.command"
	if (do shell script "test -f " & quoted form of cmd & " && echo yes || echo no") is "no" then
		display dialog "Could not find dvs-ptp-mitm.command next to this app. Keep the app inside the dvs-ptp-mitm folder." buttons {"OK"} default button "OK" with title "DVS PTP MITM"
		return
	end if
	do shell script "/bin/bash " & quoted form of cmd
end run
