# 安裝 clasp-setup 技能到本機（Windows / PowerShell）
#
# 會複製到兩個資料夾，一次涵蓋四個平台：
#   ~/.claude/skills/   → Claude Code、opencode
#   ~/.agents/skills/   → ChatGPT 應用程式（Codex）、AntiGravity 2、opencode
#
# 用法：
#   .\scripts\install.ps1              # 裝到使用者家目錄（預設）
#   .\scripts\install.ps1 -Project     # 改裝到目前專案資料夾

[CmdletBinding()]
param(
    [switch]$Project
)

$ErrorActionPreference = 'Stop'

$skillName = 'clasp-setup'
$source = Join-Path $PSScriptRoot "..\skills\$skillName"

if (-not (Test-Path $source)) {
    Write-Error "找不到技能來源資料夾：$source"
}

$source = (Resolve-Path $source).Path

if ($Project) {
    $bases = @('.claude\skills', '.agents\skills')
    $root = (Get-Location).Path
} else {
    $bases = @('.claude\skills', '.agents\skills')
    $root = $env:USERPROFILE
}

foreach ($base in $bases) {
    $target = Join-Path $root (Join-Path $base $skillName)
    $parent = Split-Path $target -Parent

    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Copy-Item -Recurse -Force -Path $source -Destination $target
    Write-Host "✅ 已安裝：$target"
}

Write-Host ""
Write-Host "裝好了。請重開你的 agent（或開一個新對話）讓它讀到新技能。"
Write-Host "驗證方式：跟 agent 說「接 Apps Script」，看它有沒有載入 $skillName。"
