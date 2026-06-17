PROJECT_DIR := /Users/gergoterek/Movies/OBS/GPT/HoverClick
APP_NAME := HoverClick
BUNDLE_ID := com.gergoterek.HoverClick
SIGNING_IDENTITY := Apple Development: rizsutt@gmail.com (MVQ5PX4679)
SPARKLE_VERSION := 2.9.3
SPARKLE_ARCHIVE_SHA256 := 74a07da821f92b79310009954c0e15f350173374a3abe39095b4fc5096916be6
SPARKLE_URL := https://github.com/sparkle-project/Sparkle/releases/download/$(SPARKLE_VERSION)/Sparkle-$(SPARKLE_VERSION).tar.xz
SPARKLE_CACHE := $(PROJECT_DIR)/tmp/sparkle/Sparkle-$(SPARKLE_VERSION)
SPARKLE_ARCHIVE := $(SPARKLE_CACHE)/Sparkle-$(SPARKLE_VERSION).tar.xz
SPARKLE_EXTRACTED := $(SPARKLE_CACHE)/extracted
SPARKLE_FRAMEWORK_SOURCE := $(SPARKLE_EXTRACTED)/Sparkle.framework

SRC := $(PROJECT_DIR)/HoverClick.mm
PLIST := $(PROJECT_DIR)/Info.plist
APP := $(PROJECT_DIR)/$(APP_NAME).app
CONTENTS := $(APP)/Contents
MACOS := $(CONTENTS)/MacOS
BINARY := $(MACOS)/$(APP_NAME)
FRAMEWORKS := $(CONTENTS)/Frameworks
SPARKLE_FRAMEWORK_DEST := $(FRAMEWORKS)/Sparkle.framework

.PHONY: app clean verify run check-signing prepare-sparkle dirs

app: check-signing prepare-sparkle clean dirs
	/usr/bin/clang++ -std=c++17 -fobjc-arc -mmacosx-version-min=12.0 \
		-F$(SPARKLE_EXTRACTED) \
		-framework Cocoa \
		-framework ApplicationServices \
		-framework ServiceManagement \
		-framework Sparkle \
		-Wl,-rpath,@loader_path/../Frameworks \
		$(SRC) -o $(BINARY)
	/bin/cp $(PLIST) $(CONTENTS)/Info.plist
	/usr/bin/ditto $(SPARKLE_FRAMEWORK_SOURCE) $(SPARKLE_FRAMEWORK_DEST)
	/usr/bin/codesign --force --sign "$(SIGNING_IDENTITY)" --options runtime --timestamp=none $(SPARKLE_FRAMEWORK_DEST)/Versions/B/XPCServices/Downloader.xpc
	/usr/bin/codesign --force --sign "$(SIGNING_IDENTITY)" --options runtime --timestamp=none $(SPARKLE_FRAMEWORK_DEST)/Versions/B/XPCServices/Installer.xpc
	/usr/bin/codesign --force --sign "$(SIGNING_IDENTITY)" --options runtime --timestamp=none $(SPARKLE_FRAMEWORK_DEST)/Versions/B/Updater.app
	/usr/bin/codesign --force --sign "$(SIGNING_IDENTITY)" --options runtime --timestamp=none $(SPARKLE_FRAMEWORK_DEST)/Versions/B/Autoupdate
	/usr/bin/codesign --force --sign "$(SIGNING_IDENTITY)" --options runtime --timestamp=none $(SPARKLE_FRAMEWORK_DEST)/Versions/B
	/usr/bin/codesign --force --sign "$(SIGNING_IDENTITY)" --options runtime --timestamp=none $(APP)

check-signing:
	@/usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -F '"$(SIGNING_IDENTITY)"' >/dev/null || { \
		echo "Required stable signing identity not found: $(SIGNING_IDENTITY)"; \
		echo "Available code signing identities:"; \
		/usr/bin/security find-identity -v -p codesigning; \
		exit 1; \
	}

prepare-sparkle:
	/bin/mkdir -p $(SPARKLE_CACHE)
	@if [ -f "$(SPARKLE_ARCHIVE)" ]; then \
		actual=$$(/usr/bin/shasum -a 256 "$(SPARKLE_ARCHIVE)" | /usr/bin/awk '{print $$1}'); \
		if [ "$$actual" != "$(SPARKLE_ARCHIVE_SHA256)" ]; then \
			echo "Removing Sparkle archive with unexpected SHA-256: $$actual"; \
			/bin/rm -f "$(SPARKLE_ARCHIVE)"; \
		fi; \
	fi
	@if [ ! -f "$(SPARKLE_ARCHIVE)" ]; then \
		/usr/bin/curl -fL --retry 3 --retry-delay 2 -o "$(SPARKLE_ARCHIVE)" "$(SPARKLE_URL)"; \
	fi
	@printf '%s  %s\n' "$(SPARKLE_ARCHIVE_SHA256)" "$(SPARKLE_ARCHIVE)" | /usr/bin/shasum -a 256 -c -
	/bin/rm -rf $(SPARKLE_EXTRACTED)
	/bin/mkdir -p $(SPARKLE_EXTRACTED)
	/usr/bin/tar -xJf $(SPARKLE_ARCHIVE) -C $(SPARKLE_EXTRACTED) ./Sparkle.framework ./LICENSE ./INSTALL ./CHANGELOG ./bin/generate_keys ./bin/sign_update ./bin/generate_appcast
	@test -d "$(SPARKLE_FRAMEWORK_SOURCE)" || { echo "Missing extracted Sparkle.framework"; exit 1; }

dirs:
	/bin/mkdir -p $(MACOS) $(FRAMEWORKS)

clean:
	/bin/rm -rf $(APP)

verify:
	$(PROJECT_DIR)/scripts/verify-app.sh

run:
	$(PROJECT_DIR)/scripts/run-app.sh
