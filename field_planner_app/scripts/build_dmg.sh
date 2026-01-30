#!/bin/bash

# エラーが発生したら停止
set -e

# スクリプトのディレクトリの親ディレクトリ（プロジェクトルート）に移動
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
cd "$PROJECT_ROOT"

APP_NAME="field_planner_app"
VOL_NAME="Field Planner"
DMG_NAME="field_planner_app.dmg"
BUILD_PATH="build/macos/Build/Products/Release"
APP_PATH="$BUILD_PATH/$APP_NAME.app"
TMP_DIR="$BUILD_PATH/tmp_dmg"

echo "Using project root: $PROJECT_ROOT"

# Flutterのビルド状況を確認し、必要ならビルド
if [ ! -d "$APP_PATH" ]; then
  echo "Release build not found. Building..."
  flutter clean
  flutter build macos --release
else
  echo "Release build found. Skipping build. (Run 'flutter clean' manually if you want a fresh build)"
fi

# 外部バイナリ（py3dtiles_converter）の同梱
CONVERTER_SRC="macos/Runner/Resources/tools/py3dtiles_converter"
CONVERTER_DEST="$APP_PATH/Contents/Resources/tools"

if [ -f "$CONVERTER_SRC" ]; then
  echo "Bundling py3dtiles_converter..."
  mkdir -p "$CONVERTER_DEST"
  cp "$CONVERTER_SRC" "$CONVERTER_DEST/"
  chmod +x "$CONVERTER_DEST/py3dtiles_converter"
  echo "Copied converter to: $CONVERTER_DEST/py3dtiles_converter"
else
  echo "WARNING: py3dtiles_converter binary not found at $CONVERTER_SRC"
  echo "Please run scripts/build_py3dtiles.sh first."
  exit 1
fi

# 一時ディレクトリのクリーンアップと作成
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

echo "Preparing DMG contents..."
# .appをコピー
cp -r "$APP_PATH" "$TMP_DIR/"

# Applicationsへのリンク作成
ln -s /Applications "$TMP_DIR/Applications"

echo "Creating DMG..."
# 既存のDMGがあれば削除
rm -f "$BUILD_PATH/$DMG_NAME"

# DMG作成
hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$TMP_DIR" \
  -ov -format UDZO \
  "$BUILD_PATH/$DMG_NAME"

# 後片付け
rm -rf "$TMP_DIR"

echo "DMG created successfully at: $BUILD_PATH/$DMG_NAME"
