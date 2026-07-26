#!/bin/bash
# .app バンドルを組み立てて未署名のzipを生成する。
# 署名・notarizeはrelease-build.yml側で、このスクリプトの後段として行う。
#
# 使い方: scripts/build-app.sh [version]
#   version省略時は .release-please-manifest.json の値を使う。
#   SKIP_ZIP=1を指定すると、署名前提のCIフロー向けに.app組み立てだけ行いzip化を省略する。

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(sed -n 's/.*"\.": *"\([^"]*\)".*/\1/p' .release-please-manifest.json)}"
if [ -z "$VERSION" ]; then
  echo "error: バージョンを特定できませんでした。引数で指定してください（例: scripts/build-app.sh 0.0.1）" >&2
  exit 1
fi

APP_NAME="RekieSekie"
BUILD_CONFIG="release"
BUILD_DIR=".build/${BUILD_CONFIG}"
DIST_DIR="dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"

echo "==> swift build -c ${BUILD_CONFIG}"
swift build -c "${BUILD_CONFIG}"

echo "==> ${APP_NAME}.app を組み立て中 (version ${VERSION})"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# SwiftPMが生成する自パッケージ・依存パッケージのリソースバンドルを同梱する。
# 実行バイナリ自体はGRDB/KeyboardShortcutsとも静的リンクなので、コピーが必要なのはリソースのみ。
for bundle in "${BUILD_DIR}"/*.bundle; do
  [ -d "$bundle" ] && cp -R "$bundle" "${APP_BUNDLE}/Contents/Resources/"
done

# --- KeyboardShortcutsのリソースバンドル解決を配布.app向けに補正する ---
# SwiftPMが生成する Bundle.module アクセサは、リソースバンドルを
#   1) Bundle.main.bundleURL 直下（=.appルート。コード署名不可なので置けない）
#   2) ビルドマシンの絶対パス（実機に存在しない）
# の順でしか探さず、どちらも解決できずショートカット録画UI表示時にfatalErrorで落ちる。
# 自パッケージ(RekieSekie)はLocalizationManager側でContents/Resourcesを見るよう回避済みだが、
# 第三者パッケージのアクセサはソースを変更できない。そこで:
#   - バンドルを Contents/Resources/KS.bundle にリネーム配置（署名可能な正規の場所）
#   - バイナリ内の参照文字列(独立cstring)を "Contents/Resources/KS.bundle" に差し替え
# これで Bundle.main.bundleURL + "Contents/Resources/KS.bundle" が解決する（設置場所非依存）。
KS_SRC="${APP_BUNDLE}/Contents/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle"
if [ -d "$KS_SRC" ]; then
  mv "$KS_SRC" "${APP_BUNDLE}/Contents/Resources/KS.bundle"
  python3 - "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" <<'PYEOF'
import sys
path = sys.argv[1]
data = bytearray(open(path, "rb").read())
# 前後がNULの独立cstringだけを対象にする（buildPath内の部分一致は除外）
old = b"\x00KeyboardShortcuts_KeyboardShortcuts.bundle\x00"
replacement = b"Contents/Resources/KS.bundle"
assert len(replacement) <= 42, "置換文字列が元の長さを超えている"
# 同一バイト長を維持（先頭NUL + 内容 + NUL埋め）してオフセットをずらさない
new = b"\x00" + replacement + b"\x00" * (42 - len(replacement)) + b"\x00"
count = data.count(old)
if count != 1:
    sys.exit(f"error: KSバンドル参照文字列が想定外の出現数です: {count}")
open(path, "wb").write(data.replace(old, new))
print("KeyboardShortcutsのバンドル参照をContents/Resources/KS.bundleへ補正しました")
PYEOF
fi

# SparkleのみSPMが動的フレームワーク(@rpath/Sparkle.framework/...)としてリンクするため、
# Contents/Frameworksに同梱しrpathを追加する。GRDB/KeyboardShortcutsは静的リンクなので対象外。
mkdir -p "${APP_BUNDLE}/Contents/Frameworks"
cp -R "${BUILD_DIR}/Sparkle.framework" "${APP_BUNDLE}/Contents/Frameworks/"
install_name_tool -add_rpath "@executable_path/../Frameworks" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

cp Packaging/Info.plist "${APP_BUNDLE}/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"
plutil -replace CFBundleVersion -string "${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"

printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"

if [ -n "${SKIP_ZIP:-}" ]; then
  echo "==> done (unsigned): ${APP_BUNDLE}"
  exit 0
fi

ZIP_PATH="${DIST_DIR}/${APP_NAME}-v${VERSION}.zip"
rm -f "${ZIP_PATH}"
# 通常のzipではなくditto: リソースフォーク・拡張属性・コード署名を壊さずに固める（署名後の配布物にも使う手順のため統一）
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

echo "==> done: ${ZIP_PATH}"
