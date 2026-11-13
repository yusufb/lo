# Swift Testing's macro plugin lives in a subfolder that SwiftPM does not search
# when only the Command Line Tools are installed (no Xcode), so pass it explicitly.
TESTING_PLUGINS := /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
PREFIX ?= $(HOME)/.local
SWIFTPM_FLAGS ?=

.PHONY: build test install

build:
	swift build -c release $(SWIFTPM_FLAGS)

test:
	swift test $(SWIFTPM_FLAGS) -Xswiftc -plugin-path -Xswiftc $(TESTING_PLUGINS)

install: build
	install -d $(PREFIX)/bin
	install -m 755 .build/release/lo $(PREFIX)/bin/lo
