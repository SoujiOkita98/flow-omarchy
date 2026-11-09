PREFIX ?= /usr/local
DESTDIR ?=

.PHONY: install install-omarchy uninstall check

install:
	install -Dm755 bin/flow-omarchy $(DESTDIR)$(PREFIX)/bin/flow-omarchy
	install -Dm644 share/prompts/cleanup.txt $(DESTDIR)$(PREFIX)/share/flow-omarchy/prompts/cleanup.txt
	install -Dm644 LICENSE $(DESTDIR)$(PREFIX)/share/licenses/flow-omarchy/LICENSE

install-omarchy: install
	for f in omarchy/bin/*; do install -Dm755 "$$f" "$(DESTDIR)$(PREFIX)/bin/$$(basename "$$f")"; done

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/flow-omarchy $(DESTDIR)$(PREFIX)/bin/omarchy-*-flow-omarchy
	rm -rf $(DESTDIR)$(PREFIX)/share/flow-omarchy $(DESTDIR)$(PREFIX)/share/licenses/flow-omarchy

check:
	bash -n bin/flow-omarchy
	test/run.sh
