"""把 assets/images 下的 PNG 主题图批量转成 WebP，并同步改写题库里的引用。

背景：169 MB 的 PNG 主题图是安装包最大的一块（整包 318 MB）。同一张画转成
WebP 后体积通常降到三分之一左右，画质肉眼无差别。

做法：
  1. 逐张 PNG -> 同名 .webp（quality 82，method 6，保留原分辨率）
  2. 把 content.json 里所有 ".png" 引用改成 ".webp"
  3. 原 PNG 不删，交给调用方决定（默认移到备份目录，保持"只移不删"的习惯）

用法：
  python tool/to_webp.py --dry-run     # 只统计，不写文件
  python tool/to_webp.py               # 全量转换并改写引用
  python tool/to_webp.py --limit 5     # 只转前 5 张，用于验证效果
"""
import argparse
import json
import os
import sys

from PIL import Image

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG_DIR = os.path.join(APP, "assets", "images")
DATA = os.path.join(APP, "assets", "data", "content.json")

QUALITY = 82
METHOD = 6


def iter_pngs():
    for root, _dirs, files in os.walk(IMG_DIR):
        for name in sorted(files):
            if name.lower().endswith(".png"):
                yield os.path.join(root, name)


def convert(png_path, dry_run=False):
    webp = png_path[:-4] + ".webp"
    before = os.path.getsize(png_path)
    if dry_run:
        with Image.open(png_path) as im:
            w, h = im.size
        return before, before, w, h
    with Image.open(png_path) as im:
        im = im.convert("RGBA" if "A" in im.getbands() else "RGB")
        im.save(webp, "WEBP", quality=QUALITY, method=METHOD)
    return before, os.path.getsize(webp), im.width, im.height


def rewrite_refs(dry_run=False):
    with open(DATA, encoding="utf-8") as f:
        raw = f.read()
    if ".png" not in raw:
        return 0
    n = raw.count(".png")
    if not dry_run:
        with open(DATA, "w", encoding="utf-8", newline="\n") as f:
            f.write(raw.replace(".png", ".webp"))
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    if not os.path.isdir(IMG_DIR):
        print("找不到图片目录:", IMG_DIR)
        return 1

    pngs = list(iter_pngs())
    if args.limit:
        pngs = pngs[: args.limit]
    print("待处理 PNG: %d 张" % len(pngs))

    total_before = total_after = 0
    worst = []
    for i, p in enumerate(pngs, 1):
        try:
            before, after, w, h = convert(p, args.dry_run)
        except Exception as e:  # 单张失败不打断全量
            print("失败 %-40s %s" % (os.path.relpath(p, APP), e))
            continue
        total_before += before
        total_after += after if not args.dry_run else before
        worst.append((after / before if before else 1, os.path.relpath(p, APP), before, after))
        if i % 100 == 0:
            print("  已处理 %d/%d" % (i, len(pngs)))

    if not args.dry_run and not args.limit:
        n_ref = rewrite_refs(False)
        print("content.json 引用改写: %d 处 .png -> .webp" % n_ref)
    elif args.limit:
        print("抽样模式（--limit），不改写 content.json 引用，避免指向尚未生成的文件")

    worst.sort(reverse=True)
    print("\n合计: %.1f MB -> %.1f MB（%.0f%%）" % (
        total_before / 1024 / 1024,
        total_after / 1024 / 1024,
        100 * total_after / max(total_before, 1)))
    print("压缩比最高（效果最差）的 3 张:")
    for r, name, b, a in worst[:3]:
        print("  %-38s %6.0f KB -> %6.0f KB (%.0f%%)" % (name, b / 1024, a / 1024, r * 100))
    return 0


if __name__ == "__main__":
    sys.exit(main())
