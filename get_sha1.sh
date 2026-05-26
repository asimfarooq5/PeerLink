#!/bin/bash

echo "=========================================="
echo "Getting SHA-1 Fingerprint for PeerLink"
echo "=========================================="
echo ""

cd android

# Check if gradlew exists and is executable
if [ ! -f "./gradlew" ]; then
    echo "Error: gradlew not found. Make sure you're in the project root."
    exit 1
fi

echo "Running signingReport..."
echo ""

# Get the SHA-1 from signing report
./gradlew signingReport 2>&1 | grep -A 2 "Variant: debug" | grep "SHA1"

echo ""
echo "=========================================="
echo "Copy the SHA1 value above and paste it in:"
echo "Firebase Console → Project Settings → Your apps → SHA certificate fingerprints"
echo "=========================================="
