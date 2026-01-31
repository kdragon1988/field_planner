#!/bin/bash
# py3dtilesをPyInstallerでスタンドアロンバイナリにビルドするスクリプト
#
# 使用方法:
#   ./scripts/build_py3dtiles.sh
#
# 前提条件:
#   - Python 3.8以上がインストールされていること
#   - pipが利用可能であること

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/macos/Runner/Resources/tools"
BUILD_DIR="$PROJECT_DIR/build/py3dtiles_build"

echo "=== py3dtiles バイナリビルドスクリプト ==="
echo "出力先: $OUTPUT_DIR"

# ビルドディレクトリを作成
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 仮想環境を作成
echo "仮想環境を作成中..."
python3 -m venv venv
source venv/bin/activate

# 依存パッケージをインストール
echo "依存パッケージをインストール中..."
pip install --upgrade pip
pip install py3dtiles[las] pyinstaller

# ラッパースクリプトを作成
cat > py3dtiles_wrapper.py << 'EOF'
#!/usr/bin/env python3
"""
py3dtiles CLIラッパー
"""
import sys
import os
import multiprocessing
import tempfile

# 起動直後にログを出力 (バッファリング無効化)
print("DEBUG: Wrapper script started", flush=True)

# [FIX] MacOS App Sandbox内でパスが長くなりすぎる問題を回避するため、/tmp を使用する
# zmq.error.ZMQError: ipc path "..." is longer than 103 characters
try:
    # /tmp は短く、システム標準の場所。App Sandbox内でもアクセス許可があればパス長問題を回避できる
    target_temp = '/tmp'
    if os.path.exists(target_temp) and os.access(target_temp, os.W_OK):
        old_temp = tempfile.gettempdir()
        tempfile.tempdir = target_temp
        print(f"DEBUG: Overriding tempfile.tempdir from {old_temp} to {target_temp}", flush=True)
    else:
        print(f"DEBUG: {target_temp} not accessible, keeping default: {tempfile.gettempdir()}", flush=True)
except Exception as e:
    print(f"DEBUG: Failed to override tempdir: {e}", flush=True)

def main():
    print("DEBUG: Entering main function", flush=True)
    try:
        print("DEBUG: Importing py3dtiles.convert...", flush=True)
        from py3dtiles.convert import convert
        print("DEBUG: Import successful", flush=True)
    except Exception as e:
        print(f"CRITICAL ERROR: Failed to import py3dtiles: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    
    if len(sys.argv) < 3:
        print("Usage: py3dtiles_converter <input_file> <output_dir> [options]")
        # ... (help text) ...
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_dir = sys.argv[2]
    
    # オプション解析
    srs = None
    jobs = 1
    
    i = 3
    while i < len(sys.argv):
        if sys.argv[i] == '--srs' and i + 1 < len(sys.argv):
            srs = sys.argv[i + 1]
            i += 2
        elif sys.argv[i] == '--jobs' and i + 1 < len(sys.argv):
            jobs = int(sys.argv[i + 1])
            i += 2
        else:
            i += 1
    
    if not os.path.exists(input_file):
        print(f"Error: Input file not found: {input_file}")
        sys.exit(1)
    
    os.makedirs(output_dir, exist_ok=True)
    
    print(f"Converting: {input_file}")
    print(f"Output: {output_dir}")
    print(f"Jobs: {jobs}")
    print(f"Source CRS: {srs if srs else 'auto-detect'}")
    print(f"Target CRS: EPSG:4978 (ECEF for CesiumJS)")
    
    try:
        import pyproj
        
        # CRS設定：CesiumはECEF座標（EPSG:4978）を期待
        crs_out = pyproj.CRS.from_epsg(4978)
        
        # 入力CRSの設定
        crs_in = None
        force_crs_in = False
        if srs:
            try:
                crs_in = pyproj.CRS.from_epsg(int(srs))
                force_crs_in = True
                print(f"Forcing input CRS: EPSG:{srs}")
            except Exception as e:
                print(f"Warning: Could not parse CRS {srs}: {e}")
        
        convert(
            input_file,
            outfolder=output_dir,
            jobs=jobs,
            overwrite=True,
            use_process_pool=False,
            crs_in=crs_in,
            force_crs_in=force_crs_in,
            crs_out=crs_out,
        )
        print("Conversion completed successfully.")
        sys.exit(0)
    except Exception as e:
        print(f"Error during conversion: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    try:
        print("DEBUG: Initializing multiprocessing", flush=True)
        multiprocessing.freeze_support()
        multiprocessing.set_start_method('spawn', force=True)
        main()
    except Exception as e:
        print(f"CRITICAL ERROR in main block: {e}")
        sys.exit(1)
EOF

# PyInstallerでバイナリをビルド
echo "PyInstallerでバイナリをビルド中..."
pyinstaller --onedir \
    --name py3dtiles_converter \
    --hidden-import=py3dtiles \
    --hidden-import=py3dtiles.convert \
    --hidden-import=laspy \
    --hidden-import=plyfile \
    --hidden-import=pyproj \
    --hidden-import=numpy \
    --collect-all py3dtiles \
    --noconfirm \
    --clean \
    py3dtiles_wrapper.py

# 出力先にコピー
echo "バイナリディレクトリを出力先にコピー中..."
mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_DIR/py3dtiles_converter" # 既存のファイルを削除
rm -rf "$OUTPUT_DIR/py3dtiles_converter_dir" # 既存のディレクトリを削除

# ディレクトリとしてコピー（名前を区別するため _dir をつけるか、構造を変える）
# Dart側では .../tools/py3dtiles_converter/py3dtiles_converter を呼ぶことになる
cp -r dist/py3dtiles_converter "$OUTPUT_DIR/"

# 実行権限
chmod +x "$OUTPUT_DIR/py3dtiles_converter/py3dtiles_converter"

# クリーンアップ
deactivate
cd "$PROJECT_DIR"

echo ""
echo "=== ビルド完了 ==="
echo "バイナリの場所: $OUTPUT_DIR/py3dtiles_converter/py3dtiles_converter"
echo ""
echo "テスト方法:"
echo "  $OUTPUT_DIR/py3dtiles_converter/py3dtiles_converter <input.las> <output_dir>"
