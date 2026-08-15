# 驗證 clasp-gas-skill 的結構、編碼、安全規則與四全域目標安裝冪等性。

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path.TrimEnd('\', '/')
$skillRoot = Join-Path $root 'skills\clasp-setup'
$appRoot = Join-Path $root 'apps\student-grade-system'
$errors = [Collections.Generic.List[string]]::new()

function Add-ValidationError {
    param([Parameter(Mandatory)][string]$Message)
    $errors.Add($Message)
}

function Get-FileMap {
    param([Parameter(Mandatory)][string]$Base)

    $map = @{}
    foreach ($file in Get-ChildItem -LiteralPath $Base -Recurse -File -Force) {
        $relative = $file.FullName.Substring($Base.Length + 1)
        $map[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
    $map
}

$required = @(
    '.codex-plugin\plugin.json',
    '.gitattributes',
    '.gitignore',
    'AGENTS.md',
    'CLAUDE.md',
    'README.md',
    'apps\student-grade-system\.claspignore',
    'apps\student-grade-system\app.html',
    'apps\student-grade-system\appsscript.json',
    'apps\student-grade-system\gas_code.js',
    'apps\student-grade-system\index.html',
    'apps\student-grade-system\package-lock.json',
    'apps\student-grade-system\package.json',
    'apps\student-grade-system\README.md',
    'apps\student-grade-system\style.html',
    'scripts\install.ps1',
    'scripts\install.sh',
    'skills\clasp-setup\SKILL.md',
    'skills\clasp-setup\agents\openai.yaml',
    'skills\clasp-setup\references\platform-notes.md'
)

foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf)) {
        Add-ValidationError "缺少必要檔案：$relative"
    }
}

$appClaspIgnore = Get-Content -LiteralPath (Join-Path $appRoot '.claspignore') -Raw -Encoding UTF8
foreach ($entry in @('!gas_code.js', '!index.html', '!style.html', '!app.html', '!appsscript.json')) {
    if (-not $appClaspIgnore.Contains($entry)) {
        Add-ValidationError "應用程式 .claspignore 缺少：$entry"
    }
}

$appBackend = Get-Content -LiteralPath (Join-Path $appRoot 'gas_code.js') -Raw -Encoding UTF8
$appFrontend = Get-Content -LiteralPath (Join-Path $appRoot 'app.html') -Raw -Encoding UTF8
$appIndex = Get-Content -LiteralPath (Join-Path $appRoot 'index.html') -Raw -Encoding UTF8
if (-not $appBackend.Contains('HtmlService.createTemplateFromFile')) {
    Add-ValidationError '應用程式後端缺少 GAS HTML Service 入口。'
}
if (-not $appFrontend.Contains('google.script.run') -or $appFrontend.Contains('GAS_API_URL')) {
    Add-ValidationError '應用程式前端必須使用 google.script.run，且不可硬編碼 GAS_API_URL。'
}
if (-not $appIndex.Contains("include('style')") -or -not $appIndex.Contains("include('app')")) {
    Add-ValidationError '應用程式 index.html 未完整內嵌 style/app。'
}

$skillFile = Join-Path $skillRoot 'SKILL.md'
$skillText = Get-Content -LiteralPath $skillFile -Raw -Encoding UTF8
$name = ((Get-Content -LiteralPath $skillFile -Encoding UTF8 -TotalCount 12 |
        Where-Object { $_ -match '^\s*name:' } |
        Select-Object -First 1) -replace '^\s*name:\s*', '').Trim().Trim('"', "'")

if ($name -ne 'clasp-setup') {
    Add-ValidationError "Skill name 應為 clasp-setup，目前是：$name"
}
if ((Split-Path -Leaf $skillRoot) -ne $name) {
    Add-ValidationError 'Skill 資料夾名與 frontmatter name 不一致。'
}

foreach ($requiredText in @(
        'npx.cmd --yes @google/clasp@3',
        'create-script',
        'show-authorized-user',
        'create-deployment',
        'open-web-app',
        'references/platform-notes.md'
    )) {
    if (-not $skillText.Contains($requiredText)) {
        Add-ValidationError "SKILL.md 缺少必要內容：$requiredText"
    }
}

try {
    $plugin = Get-Content -LiteralPath (Join-Path $root '.codex-plugin\plugin.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($plugin.name -ne 'clasp-gas-skill') {
        Add-ValidationError 'plugin.json name 必須是 clasp-gas-skill。'
    }
    if ($plugin.skills -ne './skills/') {
        Add-ValidationError 'plugin.json skills 必須指向 ./skills/。'
    }
} catch {
    Add-ValidationError "plugin.json 無法解析：$($_.Exception.Message)"
}

$openaiYaml = Get-Content -LiteralPath (Join-Path $skillRoot 'agents\openai.yaml') -Raw -Encoding UTF8
if (-not $openaiYaml.Contains('$clasp-setup')) {
    Add-ValidationError 'agents/openai.yaml 的 default_prompt 必須明確提到 $clasp-setup。'
}

$readme = Get-Content -LiteralPath (Join-Path $root 'README.md') -Raw -Encoding UTF8
foreach ($path in @('.claude/skills', '.agents/skills', '.config/opencode/skills', '.gemini/config/skills')) {
    if (-not $readme.Contains($path)) {
        Add-ValidationError "README 缺少全域安裝路徑：$path"
    }
}

$strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
$textNames = @('.gitattributes', '.gitignore')
$textExtensions = @('.md', '.ps1', '.sh', '.json', '.yaml', '.yml')
foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Force | Where-Object {
        $_.FullName -notmatch '[\\/]\.git[\\/]' -and
        $_.Name -notin @('.clasp.json', '.clasprc.json') -and
        ($textNames -contains $_.Name -or $textExtensions -contains $_.Extension.ToLowerInvariant())
    }) {
    $bytes = [IO.File]::ReadAllBytes($file.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Add-ValidationError "UTF-8 BOM：$($file.FullName.Substring($root.Length + 1))"
    }
    try {
        $null = $strictUtf8.GetString($bytes)
    } catch {
        Add-ValidationError "不是有效 UTF-8：$($file.FullName.Substring($root.Length + 1))"
    }
}

$secretPatterns = @(
    'AKIA[0-9A-Z]{16}',
    'AIza[0-9A-Za-z_-]{20,}',
    'gh[pousr]_[A-Za-z0-9]{20,}',
    '-----BEGIN [A-Z ]*PRIVATE KEY-----'
)
foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Force | Where-Object {
        $_.FullName -notmatch '[\\/]\.git[\\/]' -and
        $_.Name -notin @('.clasp.json', '.clasprc.json')
    }) {
    $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    foreach ($pattern in $secretPatterns) {
        if ($text -match $pattern) {
            Add-ValidationError "疑似敏感資訊：$($file.FullName.Substring($root.Length + 1))（$pattern）"
        }
    }
}

foreach ($localClasp in Get-ChildItem -LiteralPath $root -Recurse -File -Force -Filter '.clasp.json') {
    $relativeClasp = $localClasp.FullName.Substring($root.Length + 1)
    & git -C $root check-ignore --quiet -- $relativeClasp
    if ($LASTEXITCODE -ne 0) {
        Add-ValidationError "本機 clasp 連線檔未被 git 忽略：$relativeClasp"
    }
}

$tempRoot = [IO.Path]::Combine([IO.Path]::GetTempPath(), 'clasp-gas-skill-validate-' + [Guid]::NewGuid().ToString('N'))
$resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
$allowedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())

try {
    $fakeUserProfile = Join-Path $resolvedTemp 'home'
    $relativeBases = @(
        '.claude\skills',
        '.agents\skills',
        '.config\opencode\skills',
        '.gemini\config\skills'
    )
    foreach ($relativeBase in $relativeBases) {
        New-Item -ItemType Directory -Path (Join-Path $fakeUserProfile $relativeBase) -Force | Out-Null
    }

    # 覆寫 install.ps1 的家目錄接縫（不能覆寫 $HOME：作用域傳不進子 scope）
    $originalSkillHome = $env:CLASP_SKILL_HOME
    try {
        $env:CLASP_SKILL_HOME = $fakeUserProfile
        & (Join-Path $root 'scripts' 'install.ps1') *> $null
        foreach ($relativeBase in $relativeBases) {
            $staleFile = Join-Path $fakeUserProfile (Join-Path $relativeBase 'clasp-setup\stale-from-previous-version.txt')
            [IO.File]::WriteAllText($staleFile, 'stale', [Text.UTF8Encoding]::new($false))
        }
        & (Join-Path $root 'scripts' 'install.ps1') *> $null
    } finally {
        if ($null -eq $originalSkillHome) {
            Remove-Item Env:CLASP_SKILL_HOME -ErrorAction SilentlyContinue
        } else {
            $env:CLASP_SKILL_HOME = $originalSkillHome
        }
    }

    $sourceMap = Get-FileMap -Base $skillRoot
    foreach ($relativeBase in $relativeBases) {
        $relativeTarget = Join-Path $relativeBase 'clasp-setup'
        $target = Join-Path $fakeUserProfile $relativeTarget
        if (Test-Path -LiteralPath (Join-Path $target 'clasp-setup')) {
            Add-ValidationError "重複安裝產生巢狀資料夾：$relativeTarget\clasp-setup"
        }
        if (Test-Path -LiteralPath (Join-Path $target 'stale-from-previous-version.txt')) {
            Add-ValidationError "更新後仍殘留舊檔：$relativeTarget\stale-from-previous-version.txt"
        }
        $targetMap = Get-FileMap -Base $target
        $bad = @($sourceMap.Keys | Where-Object { $targetMap[$_] -ne $sourceMap[$_] })
        $extra = @($targetMap.Keys | Where-Object { -not $sourceMap.ContainsKey($_) })
        if ($bad.Count -gt 0 -or $extra.Count -gt 0) {
            Add-ValidationError "安裝冪等驗證失敗：$relativeTarget"
        }
    }
} catch {
    Add-ValidationError "安裝器測試失敗：$($_.Exception.Message)"
} finally {
    if ($resolvedTemp.StartsWith($allowedTemp, [StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $resolvedTemp)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

if ($errors.Count -gt 0) {
    Write-Host "VALIDATION_FAILED=$($errors.Count)"
    foreach ($errorMessage in $errors) {
        Write-Host "- $errorMessage"
    }
    exit 1
}

Write-Host 'SKILL_VALID=True'
Write-Host 'PLUGIN_JSON_VALID=True'
Write-Host 'UTF8_BOM_FREE=True'
Write-Host 'SECRET_SCAN_CLEAN=True'
Write-Host 'GLOBAL_INSTALL_TARGETS=4'
Write-Host 'POWERSHELL_GLOBAL_INSTALL_IDEMPOTENT=True'
Write-Host 'STALE_FILE_CLEANUP=True'
Write-Host 'VALIDATION_PASSED=True'
exit 0
