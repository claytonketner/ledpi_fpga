TARGET?=clayton@192.168.86.160
DIR=ledpi_bx/
REMOTE_DIR=~/$(DIR)

.PHONY: all
all: push build verify upload

.PHONY: push
push:
	rsync -rt $(DIR) $(TARGET):$(REMOTE_DIR)

.PHONY: init
init: push
	ssh -t $(TARGET) 'cd $(REMOTE_DIR) && make $@'

.PHONY: build
build:
	ssh -t $(TARGET) 'cd $(REMOTE_DIR) && make $@'

.PHONY: verify
verify:
	ssh -t $(TARGET) 'cd $(REMOTE_DIR) && make $@'

.PHONY: upload
upload:
	ssh -t $(TARGET) 'cd $(REMOTE_DIR) && make $@'
