<#
  denwacho (タウンページ Web本) ebook page downloader — Windows PowerShell version

  Downloads every page of the viewers as individual high-resolution JPEGs.
  Works on Windows PowerShell 5.1 (built into Windows 10/11) and PowerShell 7+.
  No extra software required.

  Image URL pattern:
    https://www.denwacho.ne.jp/ebook/<BOOK_ID>/books/images/<SIZE>_<PAGE>.jpg
  Sizes: el (1448x2048, best for OCR) | l (870x1230) | m (597x844) | t (thumbnail)

  Usage (from a PowerShell window in this folder):
    .\download.ps1                       # all 3 books, size el, into .\out
    .\download.ps1 -Size l               # different resolution
    .\download.ps1 -OutDir D:\townpage   # different output folder
    .\download.ps1 -Books 202502_391646  # only specific book id(s)

  If you get "running scripts is disabled on this system", start it like this:
    powershell -ExecutionPolicy Bypass -File .\download.ps1
#>

param(
  [string[]]$Books,
  [string]$Size = 'el',
  [string]$OutDir = '.\out',
  [string]$BooksFile,
  [string]$Host_ = 'https://www.denwacho.ne.jp/ebook'
)

$ErrorActionPreference = 'Stop'

# Book list priority: 1) -Books arg  2) books.txt  3) built-in fallback
if (-not $Books -or $Books.Count -eq 0) {
  if (-not $BooksFile) { $BooksFile = Join-Path $PSScriptRoot 'books.txt' }
  if (Test-Path $BooksFile) {
    $Books = Get-Content $BooksFile |
      ForEach-Object { ($_ -replace '#.*','').Trim() } |
      Where-Object { $_ -ne '' } |
      ForEach-Object { ($_ -split '\s+')[0] }
    Write-Host "Loaded $($Books.Count) book id(s) from $BooksFile"
  } else {
    $Books = @('202502_391646','202508_392644','202508_392643')
  }
}
# denwacho requires TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-Text([string]$url) {
  return (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
}

function Save-Page([string]$book, [string]$size, [int]$page, [string]$dir) {
  $url  = "$Host_/$book/books/images/${size}_${page}.jpg"
  $dest = Join-Path $dir "${size}_${page}.jpg"

  if ((Test-Path $dest) -and ((Get-Item $dest).Length -gt 1024)) { return $true }

  $tmp = "$dest.part"
  for ($try = 1; $try -le 4; $try++) {
    try {
      $wc = New-Object System.Net.WebClient
      $wc.DownloadFile($url, $tmp)
      $wc.Dispose()
      # Verify it is a real JPEG (server returns an HTML error page for out-of-range pages)
      $fs = [IO.File]::OpenRead($tmp)
      $b0 = $fs.ReadByte(); $b1 = $fs.ReadByte(); $fs.Close()
      if ($b0 -eq 0xFF -and $b1 -eq 0xD8 -and (Get-Item $tmp).Length -gt 1024) {
        Move-Item -Force $tmp $dest
        return $true
      } else {
        Remove-Item -Force $tmp -ErrorAction SilentlyContinue
        return $false   # not an image = past the last page
      }
    } catch {
      if (Test-Path $tmp) { Remove-Item -Force $tmp -ErrorAction SilentlyContinue }
      Start-Sleep -Seconds ([math]::Pow(2, $try))   # backoff on network errors
    }
  }
  Write-Warning "FAILED $book page $page"
  return $false
}

foreach ($book in $Books) {
  $dir = Join-Path $OutDir $book
  New-Item -ItemType Directory -Force -Path $dir | Out-Null

  $xml   = Get-Text "$Host_/$book/books/db/dbook.xml"
  $count = ([regex]::Matches($xml, '<page ')).Count
  $name  = ([regex]::Match($xml, 'name="([^"]*)"')).Groups[1].Value

  Write-Host "=== $book : $name : $count pages : size=$Size ==="

  $got = 0
  for ($p = 1; $p -le $count; $p++) {
    if (Save-Page $book $Size $p $dir) { $got++ }
    if ($p % 25 -eq 0 -or $p -eq $count) {
      Write-Progress -Activity $book -Status "$p / $count" -PercentComplete (($p / $count) * 100)
    }
  }
  Write-Host "--- $book : downloaded $got / $count pages into $dir"
}

Write-Host "Done. Output in: $OutDir"
