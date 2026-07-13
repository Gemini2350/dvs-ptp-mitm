CC?=gcc
DVSDIR?=/Library/Application\ Support/Audinate/DanteVirtualSoundcard

h: help
help:
	@cat README.md

b: build
build: ptp-mitm.c
	$(CC) -o ptp-mitm ptp-mitm.c

c: clean
clean:
	$(RM) ptp-mitm

# Install the man-in-the-middle wrapper.
#
# Safety: the original "ptp" is only backed up to "ptp-original" if that backup
# does NOT already exist. Without this guard, running install twice would copy
# the wrapper over the real original and destroy it permanently.
install: ptp-mitm
	@if [ ! -f "$(DVSDIR)/ptp-original" ]; then \
		echo "Backing up original ptp -> ptp-original"; \
		install -b -o root -g admin "$(DVSDIR)/ptp" "$(DVSDIR)/ptp-original"; \
	else \
		echo "ptp-original already exists, keeping it (wrapper likely already installed)"; \
	fi
	$(RM) "$(DVSDIR)/ptp"
	install -o root -g admin ptp-mitm "$(DVSDIR)/ptp"
	@if [ ! -f "$(DVSDIR)/ptp-mitm.conf" ]; then \
		echo "Installing default config ptp-mitm.conf"; \
		install -o root -g admin -m 644 ptp-mitm.conf "$(DVSDIR)/ptp-mitm.conf"; \
	else \
		echo "Keeping existing ptp-mitm.conf"; \
	fi
	@echo "Done. Restart the Dante Virtual Soundcard for changes to take effect."

uninstall: $(DVSDIR)/ptp-original
	$(RM) "$(DVSDIR)/ptp"
	mv "$(DVSDIR)/ptp-original" "$(DVSDIR)/ptp"
	@echo "Restored original ptp. (Config ptp-mitm.conf left in place; delete it manually if desired.)"

# Report whether the wrapper is currently installed and which options are set.
status:
	@if [ -f "$(DVSDIR)/ptp-original" ]; then \
		echo "MITM wrapper: INSTALLED (backup ptp-original present)"; \
	else \
		echo "MITM wrapper: not installed"; \
	fi
	@if [ -f "$(DVSDIR)/ptp-mitm.conf" ]; then \
		echo "Config ($(DVSDIR)/ptp-mitm.conf):"; \
		sed 's/^/    /' "$(DVSDIR)/ptp-mitm.conf"; \
	else \
		echo "No config file -> compiled defaults apply"; \
	fi

dir:
	@echo $(DVSDIR)
