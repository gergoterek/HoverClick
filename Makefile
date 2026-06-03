PROJECT_DIR := /Users/gergoterek/Movies/OBS/GPT/HoverClick
APP_NAME := HoverClick
BUNDLE_ID := com.gergoterek.HoverClick
SIGNING_IDENTITY := Apple Development: rizsutt@gmail.com (MVQ5PX4679)

SRC := $(PROJECT_DIR)/HoverClick.mm
PLIST := $(PROJECT_DIR)/Info.plist
APP := $(PROJECT_DIR)/$(APP_NAME).app
CONTENTS := $(APP)/Contents
MACOS := $(CONTENTS)/MacOS
BINARY := $(MACOS)/$(APP_NAME)

.PHONY: app clean verify run check-signing dirs

app: check-signing clean dirs
	/usr/bin/clang++ -std=c++17 -fobjc-arc -mmacosx-version-min=12.0 \
		-framework Cocoa \
		-framework ApplicationServices \
		-framework ServiceManagement \
		$(SRC) -o $(BINARY)
	/bin/cp $(PLIST) $(CONTENTS)/Info.plist
	/usr/bin/codesign --force --sign "$(SIGNING_IDENTITY)" --options runtime --timestamp=none $(APP)

check-signing:
	@/usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -F '"$(SIGNING_IDENTITY)"' >/dev/null || { \
		echo "Required stable signing identity not found: $(SIGNING_IDENTITY)"; \
		echo "Available code signing identities:"; \
		/usr/bin/security find-identity -v -p codesigning; \
		exit 1; \
	}

dirs:
	/bin/mkdir -p $(MACOS)

clean:
	/bin/rm -rf $(APP)

verify:
	$(PROJECT_DIR)/scripts/verify-app.sh

run:
	$(PROJECT_DIR)/scripts/run-app.sh
