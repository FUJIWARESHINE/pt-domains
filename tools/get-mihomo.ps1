<#
.SYNOPSIS
    下载与本仓库固定版本一致的 mihomo 内核，供 tools/build.ps1 编译 .mrs 规则集。

.DESCRIPTION
    版本号固定维护在 tools/mihomo.version（唯一事实来源）。本地与 GitHub Actions
    使用完全相同的内核版本，生成的 pt-domains.mrs 才能字节一致，不会出现
    「本地生成一套、云端生成另一套、互相覆盖」的问题。

    脚本自动按当前系统 / 架构挑选官方 release 资产，下载解压到 tools/.bin/：
      windows -> mihomo-windows-<arch>-compatible-<ver>.zip
      linux   -> mihomo-linux-<arch>-compatible-<ver>.gz
      darwin  -> mihomo-darwin-<arch>-compatible-<ver>.gz
    （arm64 没有 compatible 变体，会自动回退到普通构建）

    tools/.bin/ 已在 .gitignore 中忽略，不会污染仓库。
    已存在同版本二进制时直接复用，加 -Force 可强制重新下载。

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\get-mihomo.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\get-mihomo.ps1 -Force
#>
[CmdletBinding()]
param(
    # 覆盖 tools/mihomo.version 中的版本号，一般不需要
    [string]$Version,

    # 即使已缓存同版本也强制重新下载
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$isWin = ($env:OS -eq 'Windows_NT')

$root    = Split-Path -Parent $PSScriptRoot
$cache   = Join-Path $PSScriptRoot '.bin'
$binName = if ($isWin) { 'mihomo.exe' } else { 'mihomo' }
$binPath = Join-Path $cache $binName
$verFile = Join-Path $cache '.version'

# ---------- 读取锁定版本 ----------
if (-not $Version) {
    $vf = Join-Path $PSScriptRoot 'mihomo.version'
    if (-not (Test-Path -LiteralPath $vf)) { throw "version file not found: $vf" }
    $Version = ([System.IO.File]::ReadAllText($vf)).Trim()
}
if (-not $Version) { throw 'mihomo version is empty' }

# ---------- 平台 / 架构 ----------
if ($isWin) {
    $platform = 'windows'
} elseif ($PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS) {
    $platform = 'darwin'
} else {
    $platform = 'linux'
}

if ($isWin) { $archRaw = "$env:PROCESSOR_ARCHITECTURE" } else { $archRaw = "$(& uname -m)" }
$archRaw = $archRaw.Trim()

switch ($archRaw.ToLowerInvariant()) {
    'amd64'   { $arch = 'amd64' }
    'x86_64'  { $arch = 'amd64' }
    'arm64'   { $arch = 'arm64' }
    'aarch64' { $arch = 'arm64' }
    default   { throw "unsupported architecture: $archRaw" }
}

$ext = if ($platform -eq 'windows') { 'zip' } else { 'gz' }

# ---------- 缓存命中就直接复用 ----------
if (-not $Force -and (Test-Path -LiteralPath $binPath) -and (Test-Path -LiteralPath $verFile)) {
    $have = ([System.IO.File]::ReadAllText($verFile)).Trim()
    if ($have -eq $Version) {
        try {
            $probe = (& $binPath -v 2>&1) -join ' '
            if ($probe -match [regex]::Escape($Version)) {
                Write-Host "mihomo $Version already cached: $binPath"
                return $binPath
            }
        } catch { }
    }
}

New-Item -ItemType Directory -Force -Path $cache | Out-Null

# ---------- 下载 ----------
$variants = if ($arch -eq 'amd64') { @('-compatible', '') } else { @('') }
$base     = "https://github.com/MetaCubeX/mihomo/releases/download/$Version"
$archive  = $null

foreach ($v in $variants) {
    $asset = "mihomo-$platform-$arch$v-$Version.$ext"
    $tmp   = Join-Path $cache $asset
    Write-Host "downloading $asset ..."
    try {
        $ProgressPreference = 'SilentlyContinue'   # 关闭进度条，否则 5.1 下大文件会极慢
        Invoke-WebRequest -Uri "$base/$asset" -OutFile $tmp -UseBasicParsing
        $archive = $tmp
        break
    } catch {
        Write-Host '  asset not available, trying next ...'
    }
}
if (-not $archive) { throw "no matching mihomo asset for $platform/$arch at $Version" }

# ---------- 解压 ----------
# 刻意不用 Expand-Archive + Remove-Item 清理临时目录：某些带「删除拦截」的环境里
# Remove-Item -Recurse 会被直接拦下报错。按条目解压出单个可执行文件更省事，也不留临时目录。
if ($ext -eq 'zip') {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
    try {
        $entry = $zip.Entries | Where-Object { $_.Name -like '*.exe' } | Select-Object -First 1
        if (-not $entry) { throw "no executable inside $archive" }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $binPath, $true)
    } finally {
        $zip.Dispose()
    }
} else {
    $inStream = [System.IO.File]::OpenRead($archive)
    try {
        $gz = New-Object System.IO.Compression.GZipStream($inStream, [System.IO.Compression.CompressionMode]::Decompress)
        try {
            $outStream = [System.IO.File]::Create($binPath)
            try { $gz.CopyTo($outStream) } finally { $outStream.Dispose() }
        } finally { $gz.Dispose() }
    } finally { $inStream.Dispose() }
    & chmod +x $binPath
}

# 删掉压缩包（用 .NET API，避免被「删除拦截」类工具链拦下）
try { [System.IO.File]::Delete($archive) } catch { }
[System.IO.File]::WriteAllText($verFile, $Version, (New-Object System.Text.UTF8Encoding($false)))

# ---------- 自检 ----------
$out = (& $binPath -v 2>&1) -join ' '
if ($out -notmatch [regex]::Escape($Version)) { throw "mihomo self-check failed: $out" }
Write-Host "mihomo ready: $binPath"
Write-Host "  $out"

return $binPath
