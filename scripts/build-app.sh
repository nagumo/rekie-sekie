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
