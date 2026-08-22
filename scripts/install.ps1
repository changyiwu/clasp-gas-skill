# clasp-setup 安裝器的 Windows 進入點。
#
# 這支「只負責找到 node 並轉呼叫」，安裝邏輯的唯一實作在 scripts/install.mjs。
# 不要在這裡加入任何複製、排除、驗證或路徑判斷邏輯——那正是雙軌漂移的來源，
# validate.ps1 會擋下含有安裝邏輯的殼層。
#
# 用法：
#   .\scripts\install.ps1

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Stop'

$installer = Join-Path $PSScriptRoot 'install.mjs'
$node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue

if (-not $node) {
    throw '找不到 Node.js。clasp v3 需要 Node.js 22 以上，請先安裝：https://nodejs.org/'
}

& $node.Source $installer @Rest
exit $LASTEXITCODE
