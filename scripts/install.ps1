# 安裝 clasp-setup 技能到本機（Windows / PowerShell）
#
# 用法：
#   .\scripts\install.ps1              # 安裝到已存在的四個 Agent 全域目錄

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$skillName = 'clasp-setup'
$source = Join-Path $PSScriptRoot "..\skills\$skillName"
$skip = '[\\/](\.git|node_modules|\.venv|venv|site-packages|generated|dist|build|__pycache__)[\\/]'

if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "找不到技能來源資料夾：$source"
}

$source = (Resolve-Path -LiteralPath $source).Path.TrimEnd('\', '/')
$skillFile = Join-Path $source 'SKILL.md'
$frontmatterName = ((Get-Content -LiteralPath $skillFile -Encoding UTF8 -TotalCount 12 |
        Where-Object { $_ -match '^\s*name:' } |
        Select-Object -First 1) -replace '^\s*name:\s*', '').Trim().Trim('"', "'")

if ($frontmatterName -ne $skillName) {
    throw "SKILL.md 的 name 必須是 '$skillName'，目前是 '$frontmatterName'。"
}

function Get-InstallFiles {
    param([Parameter(Mandatory)][string]$Base)

    @(Get-ChildItem -LiteralPath $Base -Recurse -File -Force | Where-Object {
            $relative = $_.FullName.Substring($Base.Length)
            $relative -notmatch $skip
        })
}

function Assert-SafeTarget {
    param(
        [Parameter(Mandatory)][string]$Base,
        [Parameter(Mandatory)][string]$Target
    )

    $baseFull = [IO.Path]::GetFullPath($Base).TrimEnd('\', '/')
    $targetFull = [IO.Path]::GetFullPath($Target).TrimEnd('\', '/')
    $prefix = $baseFull + [IO.Path]::DirectorySeparatorChar

    if (-not $targetFull.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Leaf $targetFull) -ne $skillName) {
        throw "拒絕操作不安全的安裝目標：$targetFull"
    }
}

function Get-HashMap {
    param([Parameter(Mandatory)][string]$Base)

    $map = @{}
    foreach ($file in Get-InstallFiles -Base $Base) {
        $relative = $file.FullName.Substring($Base.Length + 1)
        $map[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
    $map
}

# 用 $HOME 而不是 $env:USERPROFILE：後者在 macOS 是空字串，而且不報錯。
# CLASP_SKILL_HOME 是給 validate.ps1 隔離測試用的覆寫接縫——$HOME 的作用域覆寫
# 傳不進子 scope，不能像以前覆寫 USERPROFILE 那樣做。
$homeDir = if ($env:CLASP_SKILL_HOME) { $env:CLASP_SKILL_HOME } else { $HOME }
if (-not $homeDir) {
    throw '找不到家目錄，無法決定全域安裝位置。'
}

$destinations = [ordered]@{
    'Claude Code' = Join-Path $homeDir '.claude' 'skills'
    'Codex' = Join-Path $homeDir '.agents' 'skills'
    'OpenCode' = Join-Path $homeDir '.config' 'opencode' 'skills'
    'Antigravity' = Join-Path $homeDir '.gemini' 'config' 'skills'
}

$sourceFiles = Get-InstallFiles -Base $source
$sourceRelatives = @{}
foreach ($file in $sourceFiles) {
    $sourceRelatives[$file.FullName.Substring($source.Length + 1)] = $true
}

$installed = 0
foreach ($destination in $destinations.GetEnumerator()) {
    $base = [IO.Path]::GetFullPath($destination.Value)

    if (-not (Test-Path -LiteralPath $base -PathType Container)) {
        Write-Host "[SKIP] $($destination.Key)：目錄不存在（這台可能未安裝該工具）"
        continue
    }

    $target = Join-Path $base $skillName
    Assert-SafeTarget -Base $base -Target $target
    New-Item -ItemType Directory -Path $target -Force | Out-Null

    foreach ($file in $sourceFiles) {
        $relative = $file.FullName.Substring($source.Length + 1)
        $targetFile = Join-Path $target $relative
        $targetParent = Split-Path -Parent $targetFile
        New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $targetFile -Force
    }

    foreach ($file in @(Get-ChildItem -LiteralPath $target -Recurse -File -Force)) {
        $relative = $file.FullName.Substring($target.Length + 1)
        if (-not $sourceRelatives.ContainsKey($relative)) {
            Remove-Item -LiteralPath $file.FullName -Force
        }
    }

    Get-ChildItem -LiteralPath $target -Recurse -Directory -Force |
        Sort-Object { $_.FullName.Length } -Descending |
        Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force) } |
        Remove-Item -Force

    $sourceMap = Get-HashMap -Base $source
    $targetMap = Get-HashMap -Base $target
    $bad = @($sourceMap.Keys | Where-Object { $targetMap[$_] -ne $sourceMap[$_] })
    $extra = @($targetMap.Keys | Where-Object { -not $sourceMap.ContainsKey($_) })

    if ($bad.Count -gt 0 -or $extra.Count -gt 0) {
        throw "$($destination.Key) 安裝驗證失敗：內容差異=[$($bad -join ', ')]，多出檔案=[$($extra -join ', ')]"
    }

    $installed++
    Write-Host "[OK] $($destination.Key)：$target（$($sourceMap.Count) 檔，SHA-256 一致）"
}

if ($installed -eq 0) {
    throw '沒有可用的安裝目標。全域模式只安裝到已存在的 Agent 技能目錄。'
}

Write-Host ''
Write-Host '安裝完成。若技能未立即出現，請重開 agent 或開新對話。'
