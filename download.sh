#!/usr/bin/env bash
#
# denwacho (タウンページ Web本) ebook page downloader
#
# Each viewer page is served as an individual JPEG at:
#   https://www.denwacho.ne.jp/ebook/<BOOK_ID>/books/images/<SIZE>_<PAGE>.jpg
#
# Sizes (defined in books/db/dbook.xml <pagesizes>):
#   el = 1448x2048 (最高画質 / best for OCR)   l = 870x1230   m = 597x844   t = thumbnail
#
# Page count is read live from each book's dbook.xml, so no need to hard-code it.
#
# Usage:
#   ./download.sh                 # download all books in BOOKS[] at default size (el)
#   SIZE=l ./download.sh          # choose a different resolution
#   OUTDIR=/path ./download.sh    # choose output directory (default: ./out)
#   PAR=8 ./download.sh           # parallel downloads per book (default: 6)
#   ./download.sh 202502_391646   # download only the given book id(s)
#
set -euo pipefail

HOST="https://www.denwacho.ne.jp/ebook"
SIZE="${SIZE:-el}"
OUTDIR="${OUTDIR:-./out}"
PAR="${PAR:-6}"

# Fallback set of books, used only when no CLI args and no books.txt is present
BOOKS_DEFAULT=(
  "202502_391646"   # タウンページ 福岡県福岡版
  "202508_392644"   # タウンページ 福岡県北九州・筑豊版
  "202508_392643"   # タウンページ 福岡県筑後・佐賀県鳥栖版
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOKS_FILE="${BOOKS_FILE:-$SCRIPT_DIR/books.txt}"

# Books to process, in priority order:
#   1) CLI args           ./download.sh 202502_391646 ...
#   2) books.txt          one id per line ('#' starts a comment)
#   3) BOOKS_DEFAULT
if [ "$#" -gt 0 ]; then
  BOOKS=("$@")
elif [ -f "$BOOKS_FILE" ]; then
  # take the first whitespace-delimited token of each non-comment, non-blank line
  mapfile -t BOOKS < <(sed -e 's/#.*//' "$BOOKS_FILE" | awk 'NF{print $1}')
  echo "Loaded ${#BOOKS[@]} book id(s) from $BOOKS_FILE"
else
  BOOKS=("${BOOKS_DEFAULT[@]}")
fi

# curl with retries; --fail so soft-404 HTML error pages are treated as failures
fetch() { curl -sSL --fail --retry 4 --retry-delay 2 --retry-all-errors "$@"; }

# Download one page: skip if a valid (>1KB) jpeg already exists; verify content-type
download_page() {
  local book="$1" size="$2" page="$3" dir="$4"
  local url="${HOST}/${book}/books/images/${size}_${page}.jpg"
  local dest="${dir}/${size}_${page}.jpg"

  if [ -f "$dest" ] && [ "$(stat -c%s "$dest" 2>/dev/null || echo 0)" -gt 1024 ]; then
    return 0
  fi

  local tmp="${dest}.part"
  local ct
  ct=$(curl -sSL --fail --retry 4 --retry-delay 2 --retry-all-errors \
        -o "$tmp" -w "%{content_type}" "$url" 2>/dev/null) || {
    rm -f "$tmp"; echo "FAIL  ${book} p${page}" >&2; return 1; }

  case "$ct" in
    image/*) mv "$tmp" "$dest" ;;
    *) rm -f "$tmp"; echo "NOTIMG ${book} p${page} (ct=$ct)" >&2; return 1 ;;
  esac
}
export -f download_page
export HOST

for book in "${BOOKS[@]}"; do
  dir="${OUTDIR}/${book}"
  mkdir -p "$dir"

  # Page count from dbook.xml
  xml=$(fetch "${HOST}/${book}/books/db/dbook.xml")
  count=$(printf '%s' "$xml" | grep -c '<page ')
  name=$(printf '%s' "$xml" | grep -o 'name="[^"]*"' | head -1 | sed 's/name="//;s/"$//')

  echo "=== ${book} : ${name:-?} : ${count} pages : size=${SIZE} ==="

  seq 1 "$count" | xargs -P "$PAR" -I{} bash -c \
    'download_page "$0" "$1" "$2" "$3"' "$book" "$SIZE" {} "$dir"

  got=$(find "$dir" -name "${SIZE}_*.jpg" -size +1k | wc -l)
  echo "--- ${book}: downloaded ${got}/${count} pages into ${dir}"
done

echo "Done. Output in: ${OUTDIR}"
