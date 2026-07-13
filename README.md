Enables PTPv2 on Dante Virtual Soundcard


                              /[-])//  ___
                         __ --\ `_/~--|  / \
                       /_-/~~--~~ /~~~\\_\ /\
                       |  |___|===|_-- | \ \ \
     _/~~~~~~~~|~~\,   ---|---\___/----|  \/\-\
     ~\________|__/   / // \__ |  ||  / | |   | |
              ,~-|~~~~~\--, | \|--|/~|||  |   | |
              [3-|____---~~ _--'==;/ _,   |   |_|
                          /   /\__|_/  \  \__/--/
                         /---/_\  -___/ |  /,--|
                         /  /\/~--|   | |  \///
                        /  / |-__ \    |/
                       |--/ /      |-- | \
                      \^~~\\/\      \   \/- _
                       \    |  \     |~~\~~| \
                        \    \  \     \   \  | \
                          \    \ |     \   \    \
                           |~~|\/\|     \   \   |
                          |   |/         \_--_- |\
                          |  /            /   |/\/
                           ~~             /  /
                                         |__/


               ==== DVS PTPv2 Unlock =====


## What it does

DVS's `ptp` service can do more than the app normally enables. This wrapper
takes the place of the `ptp` binary, then calls the real one with the **same
arguments except for the options you turn on**:

- **PTPv2 support** — adds `-y2=-2` and mirrors the `-m1=` interface to `-m2=`.
- **Leader mode** — drops the `-s` (slave-only) flag so DVS can become the PTP
  leader / grandmaster.

Both options are read at **runtime** from a small config file
(`dvs-ptpv2-unlock.conf`), so once installed you can change them at any time —
**no editing source, no recompiling, no reinstalling.**


## Easiest way (macOS): download and double-click

1. Download the latest **`dvs-ptpv2-unlock-macos.zip`** from the
   [Releases](../../releases) page and unzip it. It contains a **prebuilt
   universal binary**, so you need **no compiler and no Terminal**.
2. Double-click **`DVS PTPv2 Unlock.app`**. A small menu opens where you can:
   - **Activate** / **Deactivate** the wrapper,
   - **Edit options** (tick PTPv2 and/or leader mode),
   - **Show status** — shows both the desired config and the **live effective
     state** (whether PTPv2 / leader are actually active in the running PTP
     service right now, read from the running process).
3. Enter your password once when macOS asks. The app applies the change and
   **restarts the PTP service for you** — no manual DVS restart needed.

> First launch: because the app isn't from the App Store, macOS may block it.
> Right-click **`DVS PTPv2 Unlock.app`** → **Open** → **Open**. You only do this once.

`dvs-ptpv2-unlock.command` is the same control panel without the app wrapper —
double-click it directly if you prefer. If you run it from a plain `git clone`
(no prebuilt binary), it compiles the binary for you, which needs the Command
Line Tools (`xcode-select --install`).


## Turning options on/off after install

Use the control panel's **Edit options** (it applies the change and restarts the
PTP service for you). Or edit `dvs-ptpv2-unlock.conf` inside the DVS folder by hand and
restart DVS yourself. Values accept `1/0`, `true/false`, `yes/no`, `on/off`:

```
leader = 1
ptpv2  = 1
```


## Command-line install (Makefile)

    Targets:

	h|help		shows this help
	b|build		compiles dvs-ptpv2-unlock
	c|clean		removes the built binary
	status		shows if the wrapper is installed and current options
	dir		echoes the DVS directory

    The following targets require sudo:

	install		installs the PTP wrapper (and default config)
	uninstall	restores the original ptp

Steps:

1. Open **Terminal** (`Applications > Utilities`) and `cd` into this folder.
2. `make build` — compiles `dvs-ptpv2-unlock`.
3. `sudo make install` — backs up the original `ptp` to `ptp-original`, puts the
   wrapper in its place, and installs a default `dvs-ptpv2-unlock.conf`.
   The backup step is **skipped if `ptp-original` already exists**, so running
   install twice can never overwrite the real original.
4. Edit `dvs-ptpv2-unlock.conf` (see above) and restart DVS.
5. `sudo make uninstall` — restores the original `ptp`.
6. `make status` — check what's currently installed/configured.

> **Note:** a DVS **update** replaces the `ptp` binary with Audinate's original,
> silently reverting the wrapper. Re-run the control panel / `make install`
> after updating DVS.


## Windows: download and double-click

1. Download the latest **`dvs-ptpv2-unlock-windows.zip`** from the
   [Releases](../../releases) page and unzip it. It contains a **prebuilt
   `dvs-ptpv2-unlock.exe`**, so you need no compiler.
2. Double-click **`DVS PTPv2 Unlock.cmd`**. Windows asks for administrator rights
   (UAC) once, then a menu opens where you can **Activate** / **Deactivate** the
   wrapper, **Edit options** (PTPv2 / leader), and **Show status** (desired
   config plus the **live effective state** read from the running PTP process).
3. Each change is applied and the **Dante Virtual Soundcard service is restarted
   for you** — no manual restart needed.

> The `.cmd` just launches `dvs-ptpv2-unlock.ps1` with the execution policy bypassed
> for that one run; nothing is changed permanently on your system.

### Manual Windows build (optional)

If you'd rather build it yourself and have no compiler, the mingw installer
works: https://github.com/Vuniverse0/mingwInstaller/releases/

Compile (in the folder with `dvs-ptpv2-unlock.c`):

`gcc -DWIN32 -o dvs-ptpv2-unlock.exe dvs-ptpv2-unlock.c`

Then, in `C:\Program Files\Audinate\Dante Virtual Soundcard`, rename `ptp.exe`
to `ptp-original.exe`, put `dvs-ptpv2-unlock.exe` in its place as `ptp.exe`, and create a
`dvs-ptpv2-unlock.conf` next to it with your `leader` / `ptpv2` settings.


## Manual installation (either OS)

In the DVS application folder
(macOS `/Library/Application Support/Audinate/DanteVirtualSoundcard`,
Windows `C:\Program Files\Audinate\Dante Virtual Soundcard`): rename the original
`ptp` to `ptp-original`, copy the compiled `dvs-ptpv2-unlock` in its place as `ptp`, and
drop a `dvs-ptpv2-unlock.conf` alongside it.


## Compile-time defaults (optional)

The config file is the normal way to set options. If you want a binary that
behaves a certain way even **without** a config file, uncomment the defaults at
the top of `dvs-ptpv2-unlock.c`:

```
// #define DEFAULT_ALLOW_LEADER 1
// #define DEFAULT_ENABLE_PTPV2 1
```
