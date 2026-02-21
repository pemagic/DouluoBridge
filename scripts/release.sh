#!/bin/bash
# Douluo Bridge - 本地构建验证 + 直接发布 GitHub Release
# 用法: ./scripts/release.sh 1.8.5
# 不依赖 GitHub Actions，本地 assembleRelease 成功后直接通过 API 发布。

set -e

VERSION=$1
REPO="pemagic/DouluoBridge"

if [ -z "$VERSION" ]; then
    echo "用法: $0 <version>  例如: $0 1.8.5"
    exit 1
fi

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
if [ ! -d "$ROOT_DIR/android" ]; then
    echo "❌ 必须在项目根目录运行"
    exit 1
fi

# ── Step 0: 获取 GitHub Token ──────────────────────────────────────────────
echo "🔑 获取 GitHub 凭证..."
GH_TOKEN=$(printf "protocol=https\nhost=github.com\n" | git credential fill 2>/dev/null | grep "^password=" | cut -d= -f2-)
if [ -z "$GH_TOKEN" ]; then
    echo "❌ 无法获取 GitHub Token，请确认已通过 git credential 登录 GitHub。"
    exit 1
fi
echo "✅ Token 获取成功"

# ── Step 1: 更新版本号 ────────────────────────────────────────────────────
echo "📝 更新版本号 → $VERSION ..."
GRADLE="$ROOT_DIR/android/app/build.gradle.kts"
CURRENT_VC=$(grep "versionCode =" "$GRADLE" | sed 's/[^0-9]//g')
NEW_VC=$((CURRENT_VC + 1))
sed -i '' "s/versionCode = .*/versionCode = $NEW_VC/" "$GRADLE"
sed -i '' "s/versionName = \".*\"/versionName = \"$VERSION\"/" "$GRADLE"
echo "   versionCode: $CURRENT_VC → $NEW_VC, versionName → $VERSION"

# ── Step 2: 更新 CHANGELOG 日期 ───────────────────────────────────────────
echo "📄 更新 CHANGELOG 日期..."
DATE=$(date +%Y-%m-%d)
sed -i '' "s/## \[$VERSION\] - TBD/## [$VERSION] - $DATE/" "$ROOT_DIR/CHANGELOG.md"

# ── Step 3: 更新 RELEASE_LOG (提取当前版本说明) ────────────────────────────
echo "📄 生成 RELEASE_LOG.md..."
VERSION_ESCAPED=$(echo "$VERSION" | sed 's/\./\\./g')
awk "/## \[$VERSION_ESCAPED\]/{flag=1;next} /^## \[/{flag=0} flag" \
    "$ROOT_DIR/CHANGELOG.md" > "$ROOT_DIR/RELEASE_LOG.md"

# ── Step 4: 本地 release 构建 ────────────────────────────────────────────
echo "🔨 本地 assembleRelease 构建..."
cd "$ROOT_DIR/android"
./gradlew clean assembleRelease 2>&1 | tail -5
if [ $? -ne 0 ]; then
    echo "❌ 本地 Release 构建失败，终止发布！"
    exit 1
fi
APK_PATH="$ROOT_DIR/android/app/build/outputs/apk/release/app-release.apk"
if [ ! -f "$APK_PATH" ]; then
    echo "❌ APK 不存在: $APK_PATH"
    exit 1
fi
echo "✅ 构建成功: $APK_PATH"

cd "$ROOT_DIR"

# ── Step 5: Commit + Tag + Push ──────────────────────────────────────────
echo "📦 Commit 并推送..."
git add android/app/build.gradle.kts CHANGELOG.md RELEASE_LOG.md
git commit -m "chore: 发布 v$VERSION"
git tag "v$VERSION" 2>/dev/null || (git tag -d "v$VERSION" && git tag "v$VERSION")
git push origin main
git push origin "v$VERSION" --force

# ── Step 6: 通过 API 创建 GitHub Release ────────────────────────────────
echo "🚀 创建 GitHub Release v$VERSION ..."
RELEASE_BODY=$(cat "$ROOT_DIR/RELEASE_LOG.md")

RESPONSE=$(curl -s -X POST \
    -H "Authorization: token $GH_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO/releases" \
    -d "$(python3 -c "
import json, sys
body = open('$ROOT_DIR/RELEASE_LOG.md').read()
print(json.dumps({'tag_name': 'v$VERSION', 'name': 'v$VERSION', 'body': body, 'draft': False, 'prerelease': False}))
")")

RELEASE_ID=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id',''))")
RELEASE_URL=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('html_url',''))")

if [ -z "$RELEASE_ID" ]; then
    echo "⚠️  Release 已存在或创建失败，尝试更新..."
    # 获取已有 release id
    RELEASE_ID=$(curl -s -H "Authorization: token $GH_TOKEN" \
        "https://api.github.com/repos/$REPO/releases/tags/v$VERSION" | \
        python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id',''))")
fi

# ── Step 7: 上传 APK 到 Release ─────────────────────────────────────────
echo "📤 上传 APK..."
APK_NAME="DouluoBridge-Android-v$VERSION.apk"
UPLOAD_URL="https://uploads.github.com/repos/$REPO/releases/$RELEASE_ID/assets?name=$APK_NAME"

curl -s -X POST \
    -H "Authorization: token $GH_TOKEN" \
    -H "Content-Type: application/vnd.android.package-archive" \
    --data-binary @"$APK_PATH" \
    "$UPLOAD_URL" | python3 -c "import json,sys; d=json.load(sys.stdin); print('✅ APK 上传成功:', d.get('browser_download_url',''))"

echo ""
echo "🎉 发布完成！"
echo "   Release 页面: $RELEASE_URL"
echo "   本地 APK: $APK_PATH"
