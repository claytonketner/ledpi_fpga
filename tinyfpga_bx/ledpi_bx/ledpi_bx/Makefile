# This is the Makefile that contains commands to run on the Raspberry Pi

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

.PHONY: build
build:
	$(WITH_VENV) apio build

.PHONY: verify
verify:
	$(WITH_VENV) apio verify

.PHONY: upload
upload:
	$(WITH_VENV) apio upload
