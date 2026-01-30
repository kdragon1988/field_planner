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

点群ファイル（LAS/LAZ/PLY）を3D Tiles形式に変換する
PyInstallerでパッケージ化して使用
"""
import sys
import os
import multiprocessing

def main():
    from py3dtiles.convert import convert
    
    if len(sys.argv) < 3:
        print("Usage: py3dtiles_converter <input_file> <output_dir> [options]")
        print("")
        print("Options:")
        print("  --srs <epsg>       Source CRS (e.g., 4326)")
        print("  --jobs <n>         Number of parallel jobs (default: 1)")
        print("")
        print("Supported formats: LAS, LAZ, PLY, XYZ")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_dir = sys.argv[2]
    
    # オプション解析
    srs = None
    jobs = 1  # PyInstallerではマルチプロセスが問題を起こすためデフォルト1
    
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
    
    # 入力ファイルの存在確認
    if not os.path.exists(input_file):
        print(f"Error: Input file not found: {input_file}")
        sys.exit(1)
    
    # 出力ディレクトリを作成
    os.makedirs(output_dir, exist_ok=True)
    
    print(f"Converting: {input_file}")
    print(f"Output: {output_dir}")
    print(f"Jobs: {jobs}")
    if srs:
        print(f"Source CRS: EPSG:{srs}")
    
    try:
        # py3dtilesで変換
        convert(
            input_file,
            outfolder=output_dir,
            jobs=jobs,
            # SRSが指定されていればそれを使用
        )
        print("Conversion completed successfully.")
        sys.exit(0)
    except Exception as e:
        print(f"Error during conversion: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    # PyInstallerでのマルチプロセッシングサポートに必須
    multiprocessing.freeze_support()
    # macOSでforkの問題を回避
    multiprocessing.set_start_method('spawn', force=True)
    main()
EOF

# PyInstallerでバイナリをビルド
echo "PyInstallerでバイナリをビルド中..."
pyinstaller --onefile \
    --name py3dtiles_converter \
    --hidden-import=py3dtiles \
    --hidden-import=py3dtiles.convert \
    --hidden-import=laspy \
    --hidden-import=plyfile \
    --hidden-import=pyproj \
    --hidden-import=numpy \
    --collect-all py3dtiles \
    py3dtiles_wrapper.py

# 出力先にコピー
echo "バイナリを出力先にコピー中..."
mkdir -p "$OUTPUT_DIR"
cp dist/py3dtiles_converter "$OUTPUT_DIR/"
chmod +x "$OUTPUT_DIR/py3dtiles_converter"

# クリーンアップ
deactivate
cd "$PROJECT_DIR"

echo ""
echo "=== ビルド完了 ==="
echo "バイナリの場所: $OUTPUT_DIR/py3dtiles_converter"
echo ""
echo "テスト方法:"
echo "  $OUTPUT_DIR/py3dtiles_converter <input.las> <output_dir>"
