APP      := Paperlike
BUILD    := .build/release
DIST     := dist
BUNDLE   := $(DIST)/$(APP).app

.PHONY: build test app run install clean

build:
	swift build -c release

test:
	swift test

## Assemble a plain .app bundle from the SwiftPM binary and ad-hoc sign it.
app: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp $(BUILD)/$(APP) $(BUNDLE)/Contents/MacOS/$(APP)
	cp Support/Info.plist $(BUNDLE)/Contents/Info.plist
	printf 'APPL????' > $(BUNDLE)/Contents/PkgInfo
	codesign --force --sign - $(BUNDLE)
	du -sh $(BUNDLE)

run: app
	open $(BUNDLE)

install: app
	rm -rf /Applications/$(APP).app
	cp -R $(BUNDLE) /Applications/$(APP).app
	open /Applications/$(APP).app

clean:
	rm -rf .build $(DIST)
