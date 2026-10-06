<#
.SYNOPSIS
    一键维护：归一化清单 -> 生成规则产物 -> 提交并推送到 GitHub。

.DESCRIPTION
    先调用 tools/get-mihomo.ps1 准备固定版本的 mihomo 内核，再调用 tools/build.ps1
    重新生成全部产物（含 pt-domains.mrs），最后把改动提交推送到 GitHub。
    提交信息默认 "update: refresh domain list"，可用 -Message 自定义。

    内核下载失败（比如离线）时只警告并跳过 .mrs，其余产物照常构建提交，
    下次云端 Actions 会自动补齐 .mrs。

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

# 1) 准备固定版本的 mihomo 内核，用于生成 pt-domains.mrs
#    下载失败不阻断流程，build.ps1 会跳过 .mrs 并给出警告
try {
    & (Join-Path $PSScriptRoot 'get-mihomo.ps1') | Out-Null
} catch {
    Write-Warning ('mihomo 准备失败，将跳过 pt-domains.mrs：' + $_.Exception.Message)
}

# 2) 归一化清单 + 生成规则产物
& (Join-Path $PSScriptRoot 'build.ps1')

# 3) 找到 git
function Resolve-Git([string]$Explicit) {
    if ($Explicit) { return $Explicit }
    $cmd = Get-Command git -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    # 通配匹配，兼容 WorkBuddy 自带 PortableGit 的版本号变化与安装位置变化。
    # 必须用 cmd\git.exe 这个包装入口：直接跑 mingw64\bin\git.exe 会因为缺少
    # 运行时环境而报 "remote-https is not a git command"，导致推送失败。
    $patterns = @(
        (Join-Path $env:USERPROFILE '.workbuddy\binaries\PortableGit\versions\*\cmd\git.exe'),
        (Join-Path $env:USERPROFILE '.workbuddy\binaries\PortableGit\versions\*\mingw64\bin\git.exe'),
        'C:\Program Files\Git\cmd\git.exe',
        'C:\Program Files (x86)\Git\cmd\git.exe'
    )
    foreach ($p in $patterns) {
        $hit = Get-ChildItem -Path $p -ErrorAction SilentlyContinue |
               Sort-Object FullName -Descending | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    throw 'git not found. Pass -GitExe <path to git.exe> or add git to PATH.'
}

$git = Resolve-Git $GitExe

# WorkBuddy 自带的 PortableGit 是精简版：remote helper（git-remote-https.exe）只放在
# mingw64\bin 下，而 git 默认的 exec-path 指向 mingw64\libexec\git-core（那里只剩几个 shell
# 脚本），于是推送时报 "remote-https is not a git command"。默认 exec-path 里找不到 helper
# 时，把 mingw64\bin 一并补进 GIT_EXEC_PATH。完整的 Git 安装不受影响。
if (-not $env:GIT_EXEC_PATH) {
    $probe = Split-Path -Parent $git
    while ($probe -and -not (Test-Path -LiteralPath (Join-Path $probe 'mingw64\bin\git-remote-https.exe'))) {
        $parent = Split-Path -Parent $probe
        if (-not $parent -or $parent -eq $probe) { $probe = $null; break }
        $probe = $parent
    }
    if ($probe) {
        $libexec = Join-Path $probe 'mingw64\libexec\git-core'
        $binDir  = Join-Path $probe 'mingw64\bin'
        $helper  = Join-Path $libexec 'git-remote-https.exe'
        if (-not (Test-Path -LiteralPath $helper) -and (Test-Path -LiteralPath (Join-Path $binDir 'git-remote-https.exe'))) {
            $dirs = @($libexec, $binDir) | Where-Object { Test-Path -LiteralPath $_ }
            $env:GIT_EXEC_PATH = ($dirs -join ';')
            Write-Host "git exec-path patched: $env:GIT_EXEC_PATH"
        }
    }
}

Push-Location $root
try {
    $status = @(& $git status --porcelain)
    if ($status.Count -eq 0) {
        # 没有新改动。但上次可能只提交没推成功，这里把没推上去的提交补推掉。
        $ahead = @(& $git log --oneline '@{u}..HEAD' 2>$null)
        if ($ahead.Count -gt 0) {
            Write-Host 'No new changes, but there are unpushed commits - pushing.'
            & $git push
            Write-Host ''
            Write-Host 'Pushed to GitHub.'
        } else {
            Write-Host 'No changes to commit. Everything is up to date.'
        }
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
