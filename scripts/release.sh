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

echo "🚀 启动 v$VERSION 发布流程..."

# 0. 本地环境校验 (Local Verification)
echo "🔍 正在进行本地构建与安装校验..."
cd "$ROOT_DIR/android"
./gradlew assembleDebug > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ 错误: 本地 Android 构建失败，请先修复代码再发布。"
    exit 1
fi

ADB="/Users/mac/android-sdk/platform-tools/adb"
DEVICE=$($ADB devices | grep -w "device" | head -n 1 | cut -f1)

if [ -z "$DEVICE" ]; then
    echo "⚠️ 警告: 未检测到连接的安卓设备/模拟器。根据您的要求，必须在本地安装测试通过后才能执行 Git 同步。"
    echo "请连接设备并确保其处于 'device' 状态后再重试。"
    exit 1
fi

echo "📲 正在安装到设备 ($DEVICE) 进行最后验证..."
$ADB -s $DEVICE install -r app/build/outputs/apk/debug/app-debug.apk > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ 错误: APK 安装到设备失败。请检查设备连接或存储空间。"
    exit 1
fi

echo "✅ 本地安装成功！请在手机上确认运行正常。确认无误后按任意键继续执行 Git 同步（或 Ctrl+C 退出）..."
read -n 1 -s

cd "$ROOT_DIR"

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

# 4. Extract Release Notes for GitHub Release
echo "📄 Extracting release notes..."
# Extract from current version until the next second-level header (##) or end of file
VERSION_ESCAPED=$(echo $VERSION | sed 's/\./\\./g')
awk "/## \[$VERSION_ESCAPED\]/{flag=1;next} /^## \[/{flag=0} flag" "$ROOT_DIR/CHANGELOG.md" > "$ROOT_DIR/RELEASE_LOG.md"

# 5. Git Operations
echo "📦 Committing and Tagging..."
git add .
git commit -m "Release v$VERSION"
git tag "v$VERSION"

echo "✅ Local steps complete."
echo "➡️ To finish the release, run:"
echo "   git push origin main && git push origin v$VERSION"
echo ""
echo "This will trigger GitHub Actions to build and upload artifacts with the summary in RELEASE_LOG.md."
