#!/usr/bin/env bash

echo "=== SASL Diagnostic Script ==="
echo

echo "1. Checking for cyrus-sasl-xoauth2 installation:"
find /nix/store -name "*cyrus-sasl-xoauth2*" -type d 2>/dev/null | head -5

echo
echo "2. Checking XOAUTH2 plugin location:"
find /nix/store -name "libxoauth2.so*" 2>/dev/null | head -5

echo
echo "3. Current SASL_PATH:"
echo "$SASL_PATH"

echo
echo "4. Testing mbsync with explicit SASL_PATH:"
SASL_PATH_TEST=$(find /nix/store -name "*cyrus-sasl-xoauth2*" -type d 2>/dev/null | head -1)/lib/sasl2:$(find /nix/store -name "*cyrus-sasl-2*" -type d 2>/dev/null | head -1)/lib/sasl2
echo "Test SASL_PATH: $SASL_PATH_TEST"

echo
echo "5. Available SASL mechanisms with current mbsync:"
mbsync --help 2>&1 | grep -i sasl || echo "No SASL info in help"

echo
echo "6. Testing connection to Gmail IMAP (will show available mechanisms):"
echo "Running: mbsync gmail"
mbsync gmail 2>&1 | grep -A5 -B5 "available:"

echo
echo "=== End of diagnostics ==="