#!/bin/zsh
# Shared release configuration. Sourced by the build, verify, setup and release scripts.
# Every path is derived from this file's location, so the scripts work from any checkout.

RELEASE_CONFIG_DIR="${${(%):-%N}:A:h}"
PROJECT_DIR="${RELEASE_CONFIG_DIR:h}"

APP_NAME="HoverClick"
BUNDLE_ID="com.gergoterek.HoverClick"
APP_PATH="$PROJECT_DIR/$APP_NAME.app"

# Self-signed local certificate (docs/DECISIONS.md, 2026-09-14). scripts/setup-signing.sh creates it.
# A stable identity keeps the Accessibility grant across updates; an ad hoc signature does not.
SIGNING_IDENTITY="HoverClick Dev"
SIGNING_DIR="$PROJECT_DIR/.signing"

SPARKLE_VERSION="2.9.3"
SPARKLE_TOOLS_DIR="$PROJECT_DIR/tmp/sparkle/Sparkle-$SPARKLE_VERSION/extracted/bin"
SPARKLE_ACCOUNT="$BUNDLE_ID"

GITHUB_REPO="gergoterek/HoverClick"
RELEASE_DOWNLOAD_BASE="https://github.com/$GITHUB_REPO/releases/download"
# The appcast is attached to every GitHub Release; "latest" always resolves to the newest one.
SPARKLE_FEED_URL="https://github.com/$GITHUB_REPO/releases/latest/download/appcast.xml"
