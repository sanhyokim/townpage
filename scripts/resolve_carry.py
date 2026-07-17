#!/usr/bin/env python3
"""ページ先頭の《承前》プレースホルダを前ページの末尾状態で解決する。

usage: python3 scripts/resolve_carry.py <csv> <category> <municipality> <area_code>

- カテゴリ列が《承前》の行 → <category>
- 住所列が《承前》で始まる行 → 《承前》を <municipality> に置換
- 電話番号列が《承前》- で始まる行 → 《承前》を <area_code> に置換
"""
import csv
import sys

path, category, municipality, area = sys.argv[1:5]
rows = list(csv.reader(open(path, encoding="utf-8")))
n = 0
for r in rows[1:]:
    changed = False
    if r[0] == "《承前》":
        r[0] = category
        changed = True
    if r[2].startswith("《承前》"):
        r[2] = municipality + r[2][len("《承前》"):]
        changed = True
    if r[3].startswith("《承前》-"):
        r[3] = area + r[3][len("《承前》"):]
        changed = True
    n += changed
with open(path, "w", encoding="utf-8", newline="") as f:
    csv.writer(f).writerows(rows)
print(f"{path}: {n} rows resolved")
