#!/usr/bin/env python3
"""本地构建验证后直接通过 GitHub API 发布 Release，上传 APK。"""

import json, subprocess, urllib.request, urllib.error, os, sys

REPO = "pemagic/DouluoBridge"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RELEASE_LOG = os.path.join(ROOT, "RELEASE_LOG.md")
GRADLE = os.path.join(ROOT, "android/app/build.gradle.kts")

# 读版本号
version = None
with open(GRADLE) as f:
    for line in f:
        if 'versionName' in line:
            version = line.split('"')[1]
            break
if not version:
    print("❌ 无法读取 versionName"); sys.exit(1)
print(f"📦 版本: {version}")

APK_PATH = os.path.join(ROOT, f"android/app/build/outputs/apk/release/DouluoBridge-Android-v{version}.apk")

# 获取 GitHub Token
result = subprocess.run(
    ["git", "credential", "fill"],
    input="protocol=https\nhost=github.com\n",
    capture_output=True, text=True
)
token = None
for line in result.stdout.splitlines():
    if line.startswith("password="):
        token = line[9:]
        break
if not token:
    print("❌ 无法获取 GitHub Token"); sys.exit(1)
print(f"✅ Token 获取成功 ({token[:6]}...)")

headers_json = {
    "Authorization": f"token {token}",
    "Accept": "application/vnd.github.v3+json",
    "Content-Type": "application/json"
}

# 删除已有同名 Release
try:
    req = urllib.request.Request(
        f"https://api.github.com/repos/{REPO}/releases/tags/v{version}",
        headers=headers_json
    )
    with urllib.request.urlopen(req) as r:
        existing = json.load(r)
        rid = existing["id"]
        del_req = urllib.request.Request(
            f"https://api.github.com/repos/{REPO}/releases/{rid}",
            headers=headers_json, method="DELETE"
        )
        urllib.request.urlopen(del_req)
        print(f"🗑  删除已有 Release id={rid}")
except urllib.error.HTTPError as e:
    if e.code != 404:
        print(f"警告: {e}")

# 动态读取最新的 Git Commit 作为当前版本的 Release 说明
body_text = f"## 🚀 DouluoBridge v{version} 正式发布\n\n"
commits_text = ""
try:
    # 仅获取最近一次的 commit（即发版 commit）作为本次版本内容
    commits = subprocess.check_output(["git", "log", "-1", "--pretty=format:%s%n%b"]).decode().strip()
    if commits:
        commits_text = "- " + commits.replace('\n', '\n- ')
        body_text += "### ✨ 更新内容\n" + commits_text
    else:
        body_text += "常规稳定性维护与性能优化。"
except Exception:
    body_text += f"v{version} release"

# ---- NEW: 自动同步到 README.md ----
README_PATH = os.path.join(ROOT, "README.md")
if os.path.exists(README_PATH):
    import re
    with open(README_PATH, "r", encoding="utf-8") as f:
        readme_content = f.read()
    
    # 1. 更新顶部标语的版本号
    # 比如: > **Cross-Platform Edition** v1.8.15 — 中国水墨风武侠横版动作游戏 (iOS & Android)
    readme_content = re.sub(
        r'(> \*\*Cross-Platform Edition\*\* v)[\d\.]+ (—)',
        f'\\g<1>{version} \\g<2>',
        readme_content
    )
    
    # 2. 更新发布特性的段落
    # 匹配从 ### 💥 v... 开始到下一个 ### 开始之间的内容
    feature_pattern = re.compile(
        r'(### 💥 v[\d\.]+.*?)\n+(?=### 🏯)', 
        re.DOTALL
    )
    
    new_feature_section = f"### 💥 v{version} 最新特性与变更\n{commits_text}\n"
    readme_content = feature_pattern.sub(new_feature_section, readme_content)
    
    with open(README_PATH, "w", encoding="utf-8") as f:
        f.write(readme_content)
    print("✅ 已同步更新 README.md 中的版本号和最新特性汇总")
    
    # 因为 README 被改了，我们顺便提交它以免工作区不干净
    subprocess.run(["git", "add", README_PATH])
    subprocess.run(["git", "commit", "--amend", "--no-edit"])
    subprocess.run(["git", "push", "-f", "origin", "HEAD"])
# ---------------------------------

# 创建 Release
payload = json.dumps({
    "tag_name": f"v{version}",
    "name": f"v{version}",
    "body": body_text,
    "draft": False,
    "prerelease": False
}).encode()

req = urllib.request.Request(
    f"https://api.github.com/repos/{REPO}/releases",
    data=payload, headers=headers_json, method="POST"
)
with urllib.request.urlopen(req) as r:
    release = json.load(r)
    release_id = release["id"]
    release_url = release["html_url"]
print(f"✅ Release 创建: {release_url}")

# 上传 APK
if not os.path.exists(APK_PATH):
    print(f"❌ APK 不存在: {APK_PATH}"); sys.exit(1)

apk_name = f"DouluoBridge-Android-v{version}.apk"
file_size = os.path.getsize(APK_PATH)

import http.client
from urllib.parse import urlparse

# Get upload URL
req = urllib.request.Request(
    f"https://api.github.com/repos/{REPO}/releases/{release_id}",
    headers=headers_json
)
with urllib.request.urlopen(req) as r:
    upload_url_base = json.load(r)["upload_url"].split("{")[0]

upload_url = f"{upload_url_base}?name={apk_name}"
print(f"📤 正在上传 APK ({file_size / 1024 / 1024:.1f} MB)...")

parsed = urlparse(upload_url)
conn = http.client.HTTPSConnection(parsed.netloc, timeout=120)

headers_upload = {
    "Authorization": f"token {token}",
    "Content-Type": "application/vnd.android.package-archive",
    "Content-Length": str(file_size),
    "Accept": "application/vnd.github.v3+json"
}

conn.putrequest("POST", f"{parsed.path}?{parsed.query}")
for k, v in headers_upload.items():
    conn.putheader(k, v)
conn.endheaders()

# Streaming upload in 512KB chunks
with open(APK_PATH, "rb") as f:
    while True:
        chunk = f.read(512 * 1024)
        if not chunk:
            break
        conn.send(chunk)

res = conn.getresponse()
body = res.read().decode()
if res.status in [200, 201]:
    d = json.loads(body)
    print(f"✅ APK 上传成功: {d.get('browser_download_url', '')}")
else:
    print(f"❌ APK 上传失败 ({res.status}): {body}")
    sys.exit(1)

print(f"\n🎉 发布完成！Release 页面: {release_url}")
