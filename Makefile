PREFIX ?= /usr/local

install:
	install -d $(PREFIX)/bin
	install -m 755 depbot-gen $(PREFIX)/bin/depbot-gen

uninstall:
	rm -f $(PREFIX)/bin/depbot-gen

test:
	bash tests/test-depbot-gen.sh

.PHONY: install uninstall test
