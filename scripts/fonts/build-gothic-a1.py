#!/usr/bin/env python3
"""build-gothic-a1.py — Gothic A1 UI 无衬线字体资产构建

对应 docs/design-system/无衬线字体升级方案_Gothic_A1_v1.1.md §3.1（资产瘦身）
与 §3.2（纵向度量校正）。可重复运行：加字符集或换版本时改本文件里的常量重跑即可。

流程：
  1. 从 Google Fonts 官方仓库 google/fonts 的 ofl/gothica1/ 拉取三档原始静态 TTF
     （固定 commit，可复现；不用 Fontsource 等二次分发文件）
  2. 用 fontTools.subset 按 §3.1 的 unicode 范围裁剪，保留全部 OpenType 特性和 name 表
  3. 用 fontTools.ttLib 按 §3.2 的起始值统一校正三档的纵向度量
  4. 产物 + OFL.txt 写入 AIEnglishApp/Resources/Fonts/

依赖：fontTools（`brew install fonttools` 或 `pip install fonttools brotli`）

用法：
  python3 scripts/fonts/build-gothic-a1.py
"""

from __future__ import annotations

import argparse
import shutil
import sys
import tempfile
import urllib.request
from pathlib import Path

try:
    from fontTools import subset
    from fontTools.ttLib import TTFont
except ImportError:
    sys.exit(
        "缺少 fontTools。先安装：brew install fonttools 或 pip install fonttools brotli"
    )

# google/fonts 仓库里 ofl/gothica1/ 的固定 commit（2026-09-24 核实，Gothic A1 Version 2.50）。
# 换版本时改这里，重跑本脚本。
SOURCE_COMMIT = "3ab2d94b73baca0964033f6bcb0346fdba01a374"
SOURCE_REPO_RAW = "https://raw.githubusercontent.com/google/fonts/{commit}/ofl/gothica1/{name}"

WEIGHTS = ["Regular", "Medium", "SemiBold"]

# §3.1 保留字符集
UNICODE_RANGES = [
    "U+0020-007E",  # Basic Latin
    "U+00A0-00FF",  # Latin-1 Supplement
    "U+0100-017F",  # Latin Extended-A
    "U+0250-02AF",  # IPA Extensions
    "U+02B0-02FF",  # Spacing Modifiers（ˈ ˌ ː 等）
    "U+03B8",  # 希腊字母 θ（IPA theta 借用，不在 IPA Extensions 区块内；只加这一个码点）
    "U+2000-206F",  # 常用标点（' " " … – — •等）
    "U+20AC",  # €
    "U+2122",  # ™
    "U+2190-2193",  # 箭头
    "U+00D7",  # ×
    "U+00F7",  # ÷
]

# §3.2 纵向度量起始值（UPM 1024）。若第 3 刀真机截图发现偏移，只改这两个数字重跑。
TARGET_ASCENDER = 1010
TARGET_DESCENDER = -260

REPO_ROOT = Path(__file__).resolve().parents[2]
DEST_DIR = REPO_ROOT / "AIEnglishApp" / "Resources" / "Fonts"


def download_sources(dest: Path, commit: str) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    for weight in WEIGHTS:
        name = f"GothicA1-{weight}.ttf"
        url = SOURCE_REPO_RAW.format(commit=commit, name=name)
        print(f"下载 {name} <- {url}")
        urllib.request.urlretrieve(url, dest / name)
    ofl_url = SOURCE_REPO_RAW.format(commit=commit, name="OFL.txt")
    print(f"下载 OFL.txt <- {ofl_url}")
    urllib.request.urlretrieve(ofl_url, dest / "OFL.txt")


def subset_font(src: Path, dst: Path) -> None:
    # --no-hinting: TrueType hinting 指令占 glyf 表的绝大部分体积（未裁剪前约占单档 90%+），
    # CoreText 在现代 iOS 屏幕上不依赖它做灰阶渲染；去掉才能达到 §3.1 的 ≤80KB/档指标。
    args = [
        str(src),
        f"--output-file={dst}",
        f"--unicodes={','.join(UNICODE_RANGES)}",
        "--layout-features=*",
        "--name-IDs=*",
        "--name-legacy",
        "--glyph-names",
        "--notdef-outline",
        "--recommended-glyphs",
        "--no-hinting",
    ]
    subset.main(args)


def fix_vertical_metrics(path: Path, ascender: int, descender: int) -> None:
    """按 §3.2：统一 lineGap=0，ascender/descender 校正到目标值；
    usWinAscent/usWinDescent 保持不小于字形实际最高/最低点；USE_TYPO_METRICS 位保持开启。
    """
    font = TTFont(str(path))

    hhea = font["hhea"]
    os2 = font["OS/2"]

    hhea.ascender = ascender
    hhea.descender = descender
    hhea.lineGap = 0

    os2.sTypoAscender = ascender
    os2.sTypoDescender = descender
    os2.sTypoLineGap = 0

    # 字形实际最高/最低点：逐字形量 yMax/yMin，取全字体极值。
    glyf = font["glyf"]
    y_max, y_min = 0, 0
    for glyph_name in font.getGlyphOrder():
        glyph = glyf[glyph_name]
        if glyph.numberOfContours == 0:
            continue
        glyph.recalcBounds(glyf)
        y_max = max(y_max, glyph.yMax)
        y_min = min(y_min, glyph.yMin)

    os2.usWinAscent = max(os2.usWinAscent, y_max)
    os2.usWinDescent = max(os2.usWinDescent, -y_min)

    # USE_TYPO_METRICS（fsSelection bit 7）保持开启：DirectWrite/CoreText 用 sTypo* 而非 usWin*。
    os2.fsSelection |= 1 << 7

    font.save(str(path))


def report(path: Path) -> None:
    font = TTFont(str(path))
    name_table = font["name"]
    ps_name = name_table.getDebugName(6)
    hhea = font["hhea"]
    os2 = font["OS/2"]
    cmap = font.getBestCmap()
    size_kb = path.stat().st_size / 1024
    print(
        f"  {path.name}: {size_kb:.1f}KB, PS名={ps_name}, "
        f"ascender={hhea.ascender} descender={hhea.descender} lineGap={hhea.lineGap}, "
        f"usWinAscent={os2.usWinAscent} usWinDescent={os2.usWinDescent}, "
        f"字符数={len(cmap)}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--src-dir",
        type=Path,
        default=None,
        help="已下载好的原始 TTF 目录（跳过下载，离线场景用）",
    )
    parser.add_argument("--commit", default=SOURCE_COMMIT, help="google/fonts 固定 commit")
    parser.add_argument("--ascender", type=int, default=TARGET_ASCENDER)
    parser.add_argument("--descender", type=int, default=TARGET_DESCENDER)
    args = parser.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)

        if args.src_dir is not None:
            src_dir = args.src_dir
        else:
            src_dir = tmp_path / "src"
            download_sources(src_dir, args.commit)

        subset_dir = tmp_path / "subset"
        subset_dir.mkdir()

        DEST_DIR.mkdir(parents=True, exist_ok=True)

        print("\n子集化 + 纵向度量校正：")
        for weight in WEIGHTS:
            src = src_dir / f"GothicA1-{weight}.ttf"
            subset_path = subset_dir / f"GothicA1-{weight}.ttf"
            subset_font(src, subset_path)
            fix_vertical_metrics(subset_path, args.ascender, args.descender)
            dst = DEST_DIR / f"GothicA1-{weight}.ttf"
            shutil.copy2(subset_path, dst)
            report(dst)

        ofl_src = src_dir / "OFL.txt"
        shutil.copy2(ofl_src, DEST_DIR / "OFL.txt")

    print(f"\n完成。产物在 {DEST_DIR}")
    print(f"来源：google/fonts@{args.commit}（ofl/gothica1/）")


if __name__ == "__main__":
    main()
