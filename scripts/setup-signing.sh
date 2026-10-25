#!/bin/zsh
# One-time setup of the two release credentials. Run this from Terminal; it asks for the
# Mac login password once (keychain trust and key access), which no automation can supply.
#
#   1. Self-signed code signing certificate "HoverClick Dev" in the login keychain, trusted for
#      code signing for this user only. Files in .signing/ (ignored by git).
#   2. Sparkle EdDSA key pair in the login keychain, account com.gergoterek.HoverClick.
#
# Backups of both secrets are written to ~/Documents/HoverClick secrets/. Move that folder
# into a password manager or an encrypted disk; it is the only copy outside this machine.
# Nothing here needs sudo.
set -euo pipefail
source "${0:A:h}/release-config.sh"

LOGIN_KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
BACKUP_DIR="$HOME/Documents/HoverClick secrets"
P12_PASSWORD="hoverclick"
CERT_PEM="$SIGNING_DIR/cert.pem"
KEY_PEM="$SIGNING_DIR/key.pem"
P12="$SIGNING_DIR/identity.p12"
OPENSSL_CNF="$SIGNING_DIR/openssl.cnf"
PUBLIC_KEY_FILE="$SIGNING_DIR/sparkle-public-key.txt"
GENERATE_KEYS="$SPARKLE_TOOLS_DIR/generate_keys"

step() { echo "==> $*"; }

/bin/mkdir -p "$SIGNING_DIR" "$BACKUP_DIR"
/bin/chmod 700 "$SIGNING_DIR" "$BACKUP_DIR"

identity_usable() {
  /usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -qF "\"$SIGNING_IDENTITY\"" || return 1
  local probe_dir probe
  probe_dir=$(/usr/bin/mktemp -d)
  probe="$probe_dir/probe"
  printf '#!/bin/sh\ntrue\n' > "$probe"
  /bin/chmod +x "$probe"
  local ok=0
  /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$probe" >/dev/null 2>&1 && ok=1
  /bin/rm -rf "$probe_dir"
  [[ $ok == 1 ]]
}

# ---- 1. code signing certificate --------------------------------------------------------

if identity_usable; then
  step "'$SIGNING_IDENTITY' is already usable for signing"
else
  if [[ ! -f "$P12" ]]; then
    step "creating the self-signed certificate files in $SIGNING_DIR"
    /bin/cat > "$OPENSSL_CNF" <<'CNF'
[req]
distinguished_name = dn
x509_extensions = v3_code
prompt = no
[dn]
CN = HoverClick Dev
O = HoverClick local development
[v3_code]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
CNF
    /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
      -config "$OPENSSL_CNF" -keyout "$KEY_PEM" -out "$CERT_PEM" 2>/dev/null
    /usr/bin/openssl pkcs12 -export -inkey "$KEY_PEM" -in "$CERT_PEM" \
      -name "$SIGNING_IDENTITY" -passout "pass:$P12_PASSWORD" -out "$P12"
    /bin/chmod 600 "$KEY_PEM" "$P12"
  fi

  step "importing the certificate and key into the login keychain"
  /usr/bin/security import "$P12" -k "$LOGIN_KEYCHAIN" -P "$P12_PASSWORD" \
    -T /usr/bin/codesign -T /usr/bin/security >/dev/null 2>&1 || echo "    (already imported)"

  step "marking it trusted for code signing (macOS asks for your login password)"
  /usr/bin/security add-trusted-cert -r trustRoot -p codeSign -k "$LOGIN_KEYCHAIN" "$CERT_PEM"

  step "allowing codesign to use the key without a dialog on every build"
  printf "    Mac login password (nothing is shown as you type): "
  read -rs KEYCHAIN_PASSWORD
  printf "\n"
  if /usr/bin/security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
       -k "$KEYCHAIN_PASSWORD" "$LOGIN_KEYCHAIN" >/dev/null 2>&1; then
    echo "    done"
  else
    echo "    could not set the partition list; click Always Allow if a keychain dialog appears" >&2
  fi
  unset KEYCHAIN_PASSWORD

  identity_usable || { echo "'$SIGNING_IDENTITY' is still not usable. Open Keychain Access, My Certificates, double-click it, set Code Signing to Always Trust, rerun." >&2; exit 1; }
  step "'$SIGNING_IDENTITY' is ready"
fi

if [[ -f "$P12" ]]; then
  /bin/cp "$P12" "$BACKUP_DIR/HoverClick-Dev-identity.p12"
  /bin/cp "$CERT_PEM" "$BACKUP_DIR/HoverClick-Dev-cert.pem"
  printf '%s\n' "$P12_PASSWORD" > "$BACKUP_DIR/HoverClick-Dev-identity-p12-password.txt"
fi

# ---- 2. Sparkle EdDSA key pair ------------------------------------------------------------

[[ -x "$GENERATE_KEYS" ]] || { echo "Missing $GENERATE_KEYS. Run: make -C '$PROJECT_DIR' prepare-sparkle" >&2; exit 1; }

if "$GENERATE_KEYS" --account "$SPARKLE_ACCOUNT" -p >/dev/null 2>&1; then
  step "Sparkle key for account $SPARKLE_ACCOUNT already exists in the keychain"
else
  step "generating the Sparkle EdDSA key pair (account $SPARKLE_ACCOUNT)"
  "$GENERATE_KEYS" --account "$SPARKLE_ACCOUNT" >/dev/null
fi

public_key=$("$GENERATE_KEYS" --account "$SPARKLE_ACCOUNT" -p)
printf '%s\n' "$public_key" > "$PUBLIC_KEY_FILE"
step "Sparkle public key: $public_key"

step "exporting the Sparkle private key backup"
/bin/rm -f "$BACKUP_DIR/HoverClick-sparkle-eddsa-private-key.txt"
"$GENERATE_KEYS" --account "$SPARKLE_ACCOUNT" -x "$BACKUP_DIR/HoverClick-sparkle-eddsa-private-key.txt" >/dev/null
/bin/chmod 600 "$BACKUP_DIR"/*

echo
echo "Backups written to: $BACKUP_DIR"
/bin/ls -l "$BACKUP_DIR"
echo
echo "Next: the release script reads the public key from $PUBLIC_KEY_FILE."
