#!/usr/bin/env python3
"""タウンページのページ画像 (el: 1448x2048) を読み取り用タイルに分割する。

紙面は本文が4段組なので、段ごと×上下2分割（重なりあり）の8タイルに切る。
タイルは元解像度のまま保存するため、拡大表示で極小活字が読み取れる。

usage: python3 scripts/tile_page.py <input.jpg> <outdir>
出力: <outdir>/<stem>_c{1-4}{a,b}.png  (c1a=1段目上半分, c1b=1段目下半分, ...)
"""
import sys
from pathlib import Path
from PIL import Image

# 4段組の段境界 (1448px幅基準)。左右の余白・耳インデックスを含めて広めに取る
COL_X = [(0, 420), (370, 750), (700, 1080), (1030, 1448)]
# 上下2分割、境界で行が切れないよう 120px 重ねる
ROW_Y = [(0, 1120), (1000, 2048)]


def tile(src: Path, outdir: Path) -> list[Path]:
    im = Image.open(src)
    sx = im.width / 1448
    sy = im.height / 2048
    outdir.mkdir(parents=True, exist_ok=True)
    out = []
    for ci, (x0, x1) in enumerate(COL_X, start=1):
        for ri, (y0, y1) in zip("ab", ROW_Y):
            box = (int(x0 * sx), int(y0 * sy), int(x1 * sx), int(y1 * sy))
            p = outdir / f"{src.stem}_c{ci}{ri}.png"
            im.crop(box).save(p)
            out.append(p)
    return out


if __name__ == "__main__":
    src, outdir = Path(sys.argv[1]), Path(sys.argv[2])
    for p in tile(src, outdir):
        print(p)
