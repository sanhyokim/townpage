# townpage — denwacho ebook page downloader

Downloads every page of the タウンページ Web本 (denwacho) ebook viewers as
individual high‑resolution JPEG images, so the pages can be archived, printed,
or later OCR'd.

## How it works

The viewers at `https://www.denwacho.ne.jp/ebook/<BOOK_ID>/viewer.html` are a
legacy jQuery‑Mobile viewer that renders each page from a plain per‑page JPEG.
Rather than screenshotting the rendered viewer, this tool downloads the source
images directly — higher quality and far more reliable.

Image URL pattern (derived from `books/js/Config.js` → `PageConfig.getFileName`):

```
https://www.denwacho.ne.jp/ebook/<BOOK_ID>/books/images/<SIZE>_<PAGE>.jpg
```

Available sizes (from each book's `books/db/dbook.xml` `<pagesizes>`):

| SIZE | dimensions | notes                         |
|------|------------|-------------------------------|
| `el` | 1448×2048  | best quality — recommended for OCR |
| `l`  | 870×1230   | medium                        |
| `m`  | 597×844    | standard                      |
| `t`  | 87×123     | thumbnail                     |

The total page count is read live from each book's `dbook.xml`, so nothing is
hard‑coded.

## Books

| BOOK_ID          | edition                                    | pages |
|------------------|--------------------------------------------|-------|
| `202502_391646`  | タウンページ 福岡県福岡版                    | 469   |
| `202508_392644`  | タウンページ 福岡県北九州・筑豊版            | 389   |
| `202508_392643`  | タウンページ 福岡県筑後・佐賀県鳥栖版        | 245   |

Approximate download size at `el` (highest quality): **~555 MB total**
(福岡版 ~247 MB / 北九州・筑豊 ~187 MB / 筑後・鳥栖 ~121 MB).
At `l` ~219 MB total; at `m` ~106 MB total.

## Usage

### Windows (PowerShell — no extra software needed)

Open PowerShell in this folder and run:

```powershell
.\download.ps1                       # all 3 books, size el, into .\out
.\download.ps1 -Size l               # different resolution (el | l | m | t)
.\download.ps1 -OutDir D:\townpage   # different output folder
.\download.ps1 -Books 202502_391646  # only specific book id(s)
```

If you see "running scripts is disabled on this system":

```powershell
powershell -ExecutionPolicy Bypass -File .\download.ps1
```

(Windows users who prefer the bash script can run `download.sh` from **Git Bash**,
which ships with Git for Windows and includes `curl`.)

### macOS / Linux / Git Bash (bash)

```bash
./download.sh                 # all three books above, size=el, into ./out
SIZE=l ./download.sh          # different resolution (el | l | m | t)
OUTDIR=/some/path ./download.sh
PAR=8 ./download.sh           # parallel downloads per book (default 6)
./download.sh 202502_391646   # only specific book id(s)
```

Output layout:

```
out/
  202502_391646/  el_1.jpg el_2.jpg … el_469.jpg
  202508_392644/  el_1.jpg …
  202508_392643/  el_1.jpg …
```

The script skips files it has already downloaded, retries transient network
errors, and validates that each response is really a JPEG (the server returns a
9.5 KB HTML error page for out‑of‑range pages, which is rejected).

## Requirements

- **Windows:** `download.ps1` — Windows PowerShell 5.1 (built in) or PowerShell 7+. Nothing to install.
- **macOS / Linux / Git Bash:** `download.sh` — `bash`, `curl`, and coreutils (`seq`, `xargs`, `stat`, `find`). No other dependencies.
