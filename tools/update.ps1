<#
.SYNOPSIS
    一键维护：归一化清单 -> 生成规则产物 -> 提交并推送到 GitHub。

.DESCRIPTION
    先调用 tools/build.ps1 重新生成产物，然后把改动提交推送到 GitHub。
    提交信息默认 "update: refresh domain list"，可用 -Message 自定义。

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\update.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\update.ps1 -Message "add example.com"
#>
[CmdletBinding()]
param(
    # 自定义提交信息
    [string]$Message,

    # 手动指定 git 可执行文件路径（默认自动查找）
    [string]$GitExe
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# 1) 归一化清单 + 生成规则产物
& (Join-Path $PSScriptRoot 'build.ps1')

# 2) 找到 git
function Resolve-Git([string]$Explicit) {
    if ($Explicit) { return $Explicit }
    $cmd = Get-Command git -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    $candidates = @(
        'E:\WorkBuddy\binaries\PortableGit\versions\1.2.0\mingw64\bin\git.exe',
        'C:\Program Files\Git\cmd\git.exe',
        'C:\Program Files (x86)\Git\cmd\git.exe'
    )
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
    throw 'git not found. Pass -GitExe <path to git.exe> or add git to PATH.'
}

$git = Resolve-Git $GitExe

Push-Location $root
try {
    $status = @(& $git status --porcelain)
    if ($status.Count -eq 0) {
        Write-Host 'No changes to commit. Everything is up to date.'
        return
    }

    Write-Host '--- changes ---'
    $status | ForEach-Object { Write-Host ('  ' + $_) }

    & $git add -A
    if (-not $Message) { $Message = 'update: refresh domain list' }
    & $git commit -m $Message
    & $git push

    Write-Host ''
    Write-Host 'Pushed to GitHub.'
} finally {
    Pop-Location
}
