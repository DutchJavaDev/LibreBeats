<#
.SYNOPSIS
  Downloads a YouTube track or playlist with the same yt-dlp options the audio
  service uses (service/audio/sourceHelper.go), for running on Windows.

.DESCRIPTION
  Writes the same metadata files the service reads (ids.txt, names.txt,
  duration.txt, tags.txt) and the audio/thumbnail files into a run_<time>
  folder under -OutDir. Playlists are downloaded one track at a time, each in
  its own numbered folder, as the service does.

  Requires yt-dlp, ffmpeg and deno on PATH. A Netscape-format cookies file is
  required, see src/backend-self-hosted/hosting-with-existing-nginx.md.

.EXAMPLE
  .\ytdlp-audio.ps1 -Url "https://www.youtube.com/watch?v=dQw4w9WgXcQ" -Cookies "$HOME\cookies.txt"

.EXAMPLE
  .\ytdlp-audio.ps1 -Url "https://www.youtube.com/playlist?list=PLxxxx" -Cookies .\cookies.txt -OutDir D:\beats
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$Cookies,
    [string]$OutDir = ".\ytdlp-out",
    [ValidateSet("opus", "mp3", "m4a", "flac")][string]$Format = "opus",
    [switch]$Playlist
)

# Native stderr is redirected to a log file, so PowerShell must not treat it as an error.
$ErrorActionPreference = "Continue"

function Stop-Run([string]$Message) {
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

foreach ($tool in "yt-dlp", "ffmpeg", "deno") {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Stop-Run "$tool is not on PATH. Install yt-dlp, ffmpeg and deno, then open a new terminal."
    }
}

if (-not (Test-Path -LiteralPath $Cookies -PathType Leaf)) {
    Stop-Run "cookies file not found: $Cookies"
}
$Cookies = (Resolve-Path -LiteralPath $Cookies).Path
$header = (Get-Content -LiteralPath $Cookies -TotalCount 1) -replace "`r", ""
if ($header -notmatch '^#\s*(Netscape )?HTTP Cookie File') {
    Stop-Run "cookies file is not in Netscape format (first line must be '# Netscape HTTP Cookie File'). JSON and CSV exports are rejected. Export it again."
}

$isPlaylist = $Playlist -or ($Url -like "*playlist?*")
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$session = Join-Path $OutDir "run_$stamp"
New-Item -ItemType Directory -Force -Path $session | Out-Null
$session = (Resolve-Path -LiteralPath $session).Path

function Get-SharedArgs {
    @(
        "--force-ipv4",
        "--extractor-args=youtube:player_js_variant=tv;player_client=default,-web_embedded",
        "--cookies=$Cookies",
        "--js-runtimes=deno",
        "--remote-components=ejs:npm"
    )
}

function Get-SingleArgs([string]$Dir, [string]$Target, [string]$Ids, [string]$Names, [string]$Duration, [string]$Tags) {
    @(
        "--write-thumbnail",
        "--extract-audio",
        "-f", "ba/b",
        "--audio-quality=0",
        "--audio-format=$Format",
        "--convert-thumbnails=jpg",
        "--no-keep-video",
        "--print-to-file", "%(id)s", $Ids,
        "--print-to-file", "%(title)s", $Names,
        "--print-to-file", "%(duration)s", $Duration,
        "--print-to-file", "%(tags)s", $Tags,
        "--output", "$Dir\%(id)s.%(ext)s",
        "--concurrent-fragments=20",
        "--ignore-errors"
    ) + (Get-SharedArgs) + @("--", $Target)
}

function Get-PlaylistArgs([string]$Target, [string]$Ids, [string]$Names, [string]$Duration, [string]$PlTitle, [string]$PlId) {
    @(
        "--force-ipv4",
        "--no-keep-video",
        "--skip-download",
        "--flat-playlist",
        "--write-thumbnail",
        "--print-to-file", "%(id)s", $Ids,
        "--print-to-file", "%(title)s", $Names,
        "--print-to-file", "%(duration)s", $Duration,
        "--print-to-file", "%(playlist_id)s", $PlId,
        "--print-to-file", "%(playlist_title)s", $PlTitle,
        "--ignore-errors"
    ) + (Get-SharedArgs) + @("--", $Target)
}

# Runs yt-dlp with the given arguments, stdout and stderr go to the given files.
function Invoke-YtDlp([string[]]$Arguments, [string]$Log, [string]$Err) {
    & yt-dlp @Arguments > $Log 2> $Err
    return $LASTEXITCODE
}

function Show-ErrorTail([string]$Err) {
    if (Test-Path -LiteralPath $Err) {
        Write-Host "--- last lines of $Err ---" -ForegroundColor Yellow
        Get-Content -LiteralPath $Err -Tail 20
    }
}

function Get-FirstLine([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    return ((Get-Content -LiteralPath $Path -TotalCount 1) -replace "`r", "").Trim()
}

function Get-Lines([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    return @(Get-Content -LiteralPath $Path | ForEach-Object { $_ -replace "`r", "" } | Where-Object { $_ -ne "" })
}

function Invoke-Single([string]$Dir, [string]$Target) {
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    $ids = Join-Path $Dir "ids.txt"
    $names = Join-Path $Dir "names.txt"
    $duration = Join-Path $Dir "duration.txt"
    $tags = Join-Path $Dir "tags.txt"
    $log = Join-Path $Dir "output.log"
    $err = Join-Path $Dir "error.log"

    $code = Invoke-YtDlp (Get-SingleArgs $Dir $Target $ids $names $duration $tags) $log $err
    if ($code -ne 0) {
        Show-ErrorTail $err
        Stop-Run "yt-dlp exited with code $code for $Target"
    }

    $id = Get-FirstLine $ids
    if ([string]::IsNullOrEmpty($id)) {
        Show-ErrorTail $err
        Stop-Run "yt-dlp did not report a video id for $Target"
    }
    $audio = Join-Path $Dir "$id.$Format"
    $image = Join-Path $Dir "$id.jpg"
    if (-not (Test-Path -LiteralPath $audio)) {
        Show-ErrorTail $err
        Stop-Run "audio file was not created: $audio"
    }
    if (-not (Test-Path -LiteralPath $image)) {
        Write-Host "WARNING: thumbnail was not created: $image" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Title:    $(Get-FirstLine $names)"
    Write-Host "Id:       $id"
    Write-Host "Duration: $(Get-FirstLine $duration) s"
    Write-Host "Audio:    $audio"
    Write-Host "Image:    $image"
}

if (-not $isPlaylist) {
    Invoke-Single $session $Url
    Write-Host ""
    Write-Host "Done. Files are in $session" -ForegroundColor Green
    exit 0
}

# Playlist: first a metadata pass (no download), then one track at a time.
$ids = Join-Path $session "ids.txt"
$names = Join-Path $session "names.txt"
$duration = Join-Path $session "duration.txt"
$plTitle = Join-Path $session "playlist_title.txt"
$plId = Join-Path $session "playlist_id.txt"
$log = Join-Path $session "output.log"
$err = Join-Path $session "error.log"

$code = Invoke-YtDlp (Get-PlaylistArgs $Url $ids $names $duration $plTitle $plId) $log $err
if ($code -ne 0) {
    Show-ErrorTail $err
    Stop-Run "yt-dlp exited with code $code while reading the playlist"
}

$videoIds = @(Get-Lines $ids)
$titles = @(Get-Lines $names)
$durations = @(Get-Lines $duration)
if ($videoIds.Count -eq 0) {
    Stop-Run "the playlist is empty or could not be read"
}
if ($titles.Count -ne $videoIds.Count -or $durations.Count -ne $videoIds.Count) {
    Stop-Run "playlist metadata line count does not match ($($videoIds.Count) ids, $($titles.Count) titles, $($durations.Count) durations)"
}

Write-Host "Playlist: $(Get-FirstLine $plTitle) ($($videoIds.Count) tracks)"
$failed = 0
for ($i = 0; $i -lt $videoIds.Count; $i++) {
    $track = "https://www.youtube.com/watch?v=$($videoIds[$i])"
    Write-Host ""
    Write-Host "[$($i + 1)/$($videoIds.Count)] $($titles[$i])"
    try {
        Invoke-Single (Join-Path $session $i) $track
    } catch {
        $failed++
        Write-Host "WARNING: track failed: $track" -ForegroundColor Yellow
    }
}

Write-Host ""
if ($failed -gt 0) {
    Write-Host "Finished with $failed failed track(s). Files are in $session" -ForegroundColor Yellow
    exit 1
}
Write-Host "Done. Files are in $session" -ForegroundColor Green
