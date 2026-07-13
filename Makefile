CC?=gcc
DVSDIR?=/Library/Application\ Support/Audinate/DanteVirtualSoundcard

h: help
help:
	@cat README.md

b: build
build: dvs-ptpv2-unlock.c
	$(CC) -o dvs-ptpv2-unlock dvs-ptpv2-unlock.c

c: clean
clean:
	$(RM) dvs-ptpv2-unlock

# Install the PTP wrapper.
#
# Safety: the original "ptp" is only backed up to "ptp-original" if that backup
# does NOT already exist. Without this guard, running install twice would copy
# the wrapper over the real original and destroy it permanently.
install: dvs-ptpv2-unlock
	@if [ ! -f "$(DVSDIR)/ptp-original" ]; then \
		echo "Backing up original ptp -> ptp-original"; \
		install -b -o root -g admin "$(DVSDIR)/ptp" "$(DVSDIR)/ptp-original"; \
	else \
		echo "ptp-original already exists, keeping it (wrapper likely already installed)"; \
	fi
	$(RM) "$(DVSDIR)/ptp"
	install -o root -g admin dvs-ptpv2-unlock "$(DVSDIR)/ptp"
	@if [ ! -f "$(DVSDIR)/dvs-ptpv2-unlock.conf" ]; then \
		echo "Installing default config dvs-ptpv2-unlock.conf"; \
		install -o root -g admin -m 644 dvs-ptpv2-unlock.conf "$(DVSDIR)/dvs-ptpv2-unlock.conf"; \
	else \
		echo "Keeping existing dvs-ptpv2-unlock.conf"; \
	fi
	@echo "Done. Restart the Dante Virtual Soundcard for changes to take effect."

uninstall: $(DVSDIR)/ptp-original
	$(RM) "$(DVSDIR)/ptp"
	mv "$(DVSDIR)/ptp-original" "$(DVSDIR)/ptp"
	@echo "Restored original ptp. (Config dvs-ptpv2-unlock.conf left in place; delete it manually if desired.)"

# Report whether the wrapper is currently installed and which options are set.
status:
	@if [ -f "$(DVSDIR)/ptp-original" ]; then \
		echo "PTP wrapper: INSTALLED (backup ptp-original present)"; \
	else \
		echo "PTP wrapper: not installed"; \
	fi
	@if [ -f "$(DVSDIR)/dvs-ptpv2-unlock.conf" ]; then \
		echo "Config ($(DVSDIR)/dvs-ptpv2-unlock.conf):"; \
		sed 's/^/    /' "$(DVSDIR)/dvs-ptpv2-unlock.conf"; \
	else \
		echo "No config file -> compiled defaults apply"; \
	fi

dir:
	@echo $(DVSDIR)
