# These are commands that typically run on the Raspberry Pi
# Or non-typically they can be run for testing

VENV_DIR=venv
VENV_ACTIVATE=$(VENV_DIR)/bin/activate
WITH_VENV=. $(VENV_ACTIVATE) &&

$(VENV_ACTIVATE): requirements.txt
	virtualenv $(VENV_DIR)
	$(WITH_VENV) pip install -r requirements.txt

.PHONY: init
init: $(VENV_ACTIVATE)
	$(WITH_VENV) apio install system scons iverilog yosys ice40
	$(WITH_VENV) apio drivers --serial-enable

# Getting simulation to work on OSX is a bit of a bitch. gtkwave can be installed
# via homebrew, but that alone leaves you with a broken cli tool. Instead, follow
# this guide: https://ughe.github.io/2018/11/06/gtkwave-osx
.PHONY: sim
sim:
	$(WITH_VENV) apio sim

.PHONY: build
build:
	$(WITH_VENV) apio build

.PHONY: verify
verify:
	$(WITH_VENV) apio verify

.PHONY: upload
upload:
	$(WITH_VENV) apio upload
