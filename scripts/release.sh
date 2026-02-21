#!/bin/bash

# Douluo Bridge - Unified Release Script
# Usage: ./scripts/release.sh [version]
# Example: ./scripts/release.sh 1.8.0

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "Usage: $0 [version]"
    echo "Example: $0 1.8.0"
    exit 1
fi

# Ensure we are in the root directory
ROOT_DIR=$(pwd)
if [ ! -d "$ROOT_DIR/ios" ] || [ ! -d "$ROOT_DIR/android" ]; then
    echo "Error: Must run from project root."
    exit 1
fi

echo "🚀 Starting Release Process for v$VERSION..."

# 1. Update Android Version
echo "🤖 Updating Android version..."
ANDROID_GRADLE="$ROOT_DIR/android/app/build.gradle.kts"
sed -i '' "s/versionName = \".*\"/versionName = \"$VERSION\"/" "$ANDROID_GRADLE"
# Increment versionCode (simple integer increment)
CURRENT_VC=$(grep "versionCode =" "$ANDROID_GRADLE" | sed 's/[^0-9]//g')
NEW_VC=$((CURRENT_VC + 1))
sed -i '' "s/versionCode = .*/versionCode = $NEW_VC/" "$ANDROID_GRADLE"

# 2. Update iOS Version
echo "🍎 Updating iOS version..."
IOS_PROJ="$ROOT_DIR/ios/DouluoBridge.xcodeproj/project.pbxproj"
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $VERSION;/" "$IOS_PROJ"
# Increment CURRENT_PROJECT_VERSION (build number)
CURRENT_CV=$(grep "CURRENT_PROJECT_VERSION =" "$IOS_PROJ" | head -n 1 | sed 's/[^0-9]//g')
NEW_CV=$((CURRENT_CV + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION = .*;/CURRENT_PROJECT_VERSION = $NEW_CV;/g" "$IOS_PROJ"

# 3. Update CHANGELOG date
echo "📝 Updating CHANGELOG..."
DATE=$(date +%Y-%m-%d)
sed -i '' "s/## \[$VERSION\] - TBD/## \[$VERSION\] - $DATE/" "$ROOT_DIR/CHANGELOG.md"

# 4. Git Operations
echo "📦 Committing and Tagging..."
git add .
git commit -m "Release v$VERSION"
git tag "v$VERSION"

echo "✅ Local steps complete."
echo "➡️ To finish the release, run:"
echo "   git push origin main && git push origin v$VERSION"
echo ""
echo "This will trigger GitHub Actions to build and upload the .ipa and .apk to the Release page."
