PREFIX ?= /usr/local
DESTDIR ?=
BIN := flow-omarchy omarchy-dictation-flow-omarchy omarchy-install-dictation-flow-omarchy omarchy-remove-dictation-flow-omarchy

.PHONY: install uninstall check

install:
	install -Dm755 -t $(DESTDIR)$(PREFIX)/bin $(addprefix bin/,$(BIN))
	mkdir -p $(DESTDIR)$(PREFIX)/share
	cp -r share/flow-omarchy $(DESTDIR)$(PREFIX)/share/
	install -Dm644 LICENSE $(DESTDIR)$(PREFIX)/share/licenses/flow-omarchy/LICENSE

uninstall:
	rm -f $(addprefix $(DESTDIR)$(PREFIX)/bin/,$(BIN))
	rm -rf $(DESTDIR)$(PREFIX)/share/flow-omarchy $(DESTDIR)$(PREFIX)/share/licenses/flow-omarchy

check:
	bash -n bin/flow-omarchy
	test/run.sh
