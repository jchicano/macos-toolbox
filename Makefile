# Toolbox Makefile (English, per project rule §1.1).
# Xcode 14.2 on macOS 12: invoke xcodebuild with DEVELOPER_DIR so no
# `sudo xcode-select` switch is required.

DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR

SCHEME := Toolbox
APP := Toolbox.app
ARCHIVE := build/Toolbox.xcarchive
DIST := dist

.PHONY: bootstrap gen build test universal verify-universal dmg notarize clean

bootstrap:
	@command -v xcodegen >/dev/null || (echo "xcodegen not found. Install a compatible binary (2.38.x) into /usr/local/bin." && exit 1)
	@xcodegen --version
	@xcodebuild -version

gen:
	xcodegen generate

build: gen
	xcodebuild build -scheme $(SCHEME) -configuration Debug -destination 'platform=macOS'

test:
	swift test --package-path Packages/ToolboxCore
	DEVELOPER_DIR="$(DEVELOPER_DIR)" xcodebuild test -scheme $(SCHEME) -destination 'platform=macOS,arch=x86_64' || true

universal:
	./scripts/build-universal.sh

verify-universal:
	./scripts/verify-universal.sh

dmg:
	./scripts/make-dmg.sh

notarize:
	./scripts/notarize.sh

clean:
	rm -rf build $(DIST) Toolbox.xcodeproj
