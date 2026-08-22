# clasp ＋ Google Apps Script 跨 Agent Skill（專案藍圖）

> 本檔為跨 Agent 通用的專案藍圖（AGENTS.md 開放標準）。任何 Agent 的每個 session 都應先讀本檔＋`handoff.md`。
> Claude Code 不直接讀 `AGENTS.md`，改由 `CLAUDE.md` 的 `@AGENTS.md` import 本檔；Claude 專屬規範寫在 `CLAUDE.md`。

## 專案簡介

這個 repo 維護一個跨 Claude Code、Codex、OpenCode、Antigravity 通用的 Agent Skill，帶使用者透過 clasp 連接 Google Apps Script，完成登入、建立或接續專案、推送程式碼、部署網頁應用程式與取得正確網址。

## 關鍵時程

- 無固定截止日期；以完成四個 Agent 的安裝、觸發與 clasp 主流程驗收為目前里程碑。

## 目標與路線圖

- [x] 階段一：完成三層級專案初始化與既有內容盤點
- [x] 階段二：強化四 Agent 安裝器、冪等更新與逐檔驗證
- [x] 階段三：修正 clasp 跨平台命令、授權與部署流程說明
- [ ] 階段四：在四個 Agent 完成實機觸發與 clasp 端到端測試
- [x] 階段五：經使用者授權後同步四個全域 Skill 副本

## 資料夾結構

```text
clasp-gas-skill/
├── .codex-plugin/
│   └── plugin.json                 # Codex plugin manifest
├── apps/
│   └── student-grade-system/       # 實際部署中的 GAS 同源網頁範例
│       ├── gas_code.js             # HTML Service 入口與 Sheets CRUD
│       ├── index.html              # 前端主頁
│       ├── style.html              # 內嵌樣式
│       ├── app.html                # google.script.run 前端邏輯
│       ├── appsscript.json         # GAS manifest
│       ├── .claspignore            # 只推送上述 GAS 檔案
│       ├── .clasp.json             # 本機連線資訊，不進 git
│       ├── package.json
│       ├── package-lock.json
│       └── README.md
├── scripts/
│   ├── install.mjs                 # 安裝邏輯唯一實作，也是對外主要指令（跨平台，Node.js）
│   ├── install.ps1                 # 可選 Windows 進入點，純轉呼叫 install.mjs
│   ├── install.sh                  # 可選 macOS／Linux 進入點，純轉呼叫 install.mjs
│   └── validate.ps1                # 結構、安全、殼層漂移與安裝冪等驗證
├── skills/
│   └── clasp-setup/
│       ├── SKILL.md                # 唯一的 Agent 工作流程來源
│       ├── agents/openai.yaml      # Codex UI metadata
│       └── references/
│           └── platform-notes.md   # 平台差異與 MCP 接法
├── AGENTS.md                       # 長期專案藍圖與規則
├── CLAUDE.md                       # Claude Code 橋接檔
├── handoff.md                      # 下一個 session 的交接，不進 git
├── README.md                       # 人類版說明
├── .gitattributes                  # 固定 LF，避免跨電腦 hash 漂移
├── .gitignore
└── LICENSE
```

新增、移除或改名主要檔案時，同步更新本節。

## 專案專屬規則

### 內容與文件同步

- `skills/clasp-setup/SKILL.md` 是 Agent 工作流程的唯一內容來源；`README.md` 是人類版說明。
- 改動流程、指令、前置需求或錯誤處理時，同步更新 `SKILL.md`、`README.md` 與受影響的 reference。
- 平台差異集中在 `skills/clasp-setup/references/platform-notes.md`，不要把四套平台設定塞回主流程。

### clasp 技術基準

- 指令語法以 **clasp v3** 為準，包括 `create-script`、`open-script`、`open-web-app`、`create-deployment`、`list-deployments`、`show-authorized-user`。
- 變更 clasp 流程或指令前，對照 <https://github.com/google/clasp> 的目前 README、原始碼或 Google 官方 Apps Script 文件，不憑記憶修改。
- Windows PowerShell 與 POSIX shell 的命令前綴分開處理；不可宣稱一般 `npx` 必然繞過 PowerShell 執行原則。
- clasp 套件至少固定主版號，避免未來 major 升級無聲破壞流程。

### 四 Agent 安裝目標

| Agent | 全域 Skill 目錄 |
|---|---|
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.agents/skills/` |
| OpenCode | `~/.config/opencode/skills/` |
| Antigravity | `~/.gemini/config/skills/` |

- 原始 Skill 只維護一份，安裝器負責複製到平台專屬全域目錄。
- 安裝器只提供四平台全域安裝，不建立 repo 內的專案層級 Skill 副本。
- 安裝必須可重複執行，不得產生 `clasp-setup/clasp-setup/` 巢狀目錄或留下已刪除的舊檔。
- 安裝後用遞迴檔案清單與 SHA-256 驗證來源和目標一致。
- 未經使用者明確要求，不覆蓋四個全域 Skill 副本；正式同步交給 `sync-skills`。

### 實際 GAS 應用程式

- `apps/student-grade-system/` 是正式應用程式的唯一原始碼位置；不要再依賴舊 `clasp-netlify-mcp-guide` repo。
- 前端與後端皆由同一個 GAS Web App 提供；前端必須用 `google.script.run` 呼叫後端。
- `.clasp.json` 只保留在本機並由 `.gitignore` 排除；GitHub 只保存可公開的程式碼與 placeholder 文件。
- 刪除舊本機 repo 前，必須從本目錄通過 SHA-256、`show-file-status`、部署清單與瀏覽器載入驗證。
- 刪除舊本機 repo 不等於刪除線上 Apps Script 或 Google Sheets；未經使用者明確要求，不得刪除線上專案、部署或試算表。

### 安全與隱私

- 不要在任何檔案放入真實的 scriptId、deploymentId、Google 帳號、OAuth 憑證或其他個資；範例一律使用 `<placeholder>`。
- 不把 `.clasp.json`、`.clasprc.json`、`.env`、金鑰或 credentials 提交進 git。
- Workspace 帳號、Google 未驗證警告與網頁應用程式公開權限都必須依實際狀態判斷，不使用過度絕對的繞過指示。
- 網頁應用程式交付前，用非擁有者帳號或無痕視窗驗證實際存取權限。

### 驗證要求

- 修改 Skill 後執行 Skill validator；修改 plugin manifest 後執行 plugin validator。
- 安裝器必須測試首次安裝、重複安裝、更新、來源刪檔後清理、排除目錄不被安裝與路徑安全。
- 新增驗證守門後必須做反向測試：故意打壞對應行為，確認驗證器真的會失敗，避免寫出恆真的假檢查。
- 檢查所有文字檔為有效 UTF-8 且不含 BOM，並執行敏感資訊掃描。
- validator 一律用 PowerShell 7 執行：`pwsh -NoProfile -File .\scripts\validate.ps1`。檔案含繁體中文且專案禁止 BOM，Windows PowerShell 5.1 會誤判編碼。
- 網路或帳號授權不足時，只能回報「未驗證」，不可宣稱 clasp 線上流程已通過。

## 同步層級（本專案初始化至第 3 層級）

| 層級 | 平台 | 位置 | 讀取時機 |
|------|------|------|---------|
| L1 | 本地（GDrive） | `AGENTS.md`＋`handoff.md`（不進 git，只走雲端硬碟）＋`CLAUDE.md`（橋接） | 每個 session |
| L2 | GitHub | [`changyiwu/clasp-gas-skill`](https://github.com/changyiwu/clasp-gas-skill)（公開） | 指定時 |
| L3 | Obsidian | `clasp-gas-skill/專案工作流程.md` | 有需要時 |

## 三個檔案的職責（依「時效性」分家，不是依「詳細程度」）

| 檔案 | 時效 | 寫入方式 | 放什麼 |
|------|------|---------|--------|
| `handoff.md` | **只對下一個 session 有效**，過期即丟 | 每次收工**整份重寫** | 做到哪、下一步、**這次**的暫時 workaround |
| `AGENTS.md`（本檔） | **長期有效**，每個 session 都適用 | 只有規則本身變了才改 | 目標、路線圖、常設規則、結構 |
| Obsidian（L3）／`git log` | **歷史**：發生過什麼、為什麼 | 只增不刪 | 決策紀錄、踩坑完整版、逐次進度 |

驗收標準：**`handoff.md` 整份刪掉，不應損失任何長期資訊**——會的話代表該升級進本檔卻沒升級。

**本檔不要出現的東西**（會無限膨脹，且開工每次都要重讀）：

- ❌ `## 最近進度`／逐次工作紀錄 → 寫 Obsidian「🗓️ 最近更動紀錄」或靠 `git log`
- ❌ 決策記錄、取捨理由、踩坑經過的完整版 → 寫 Obsidian「決策紀錄」「🕳️ 踩坑筆記」
- ✅ 只留「結論式的規則」：踩過的坑收斂成祈使句，歷史脈絡留在 Obsidian

## 工作約定

- 任何 Agent、任何電腦：**開工先讀 `handoff.md`，收工必更新 `handoff.md`**。
- `handoff.md` **不進 git**，跨電腦只靠雲端硬碟同步，不要把它加回版控。
- 修改共用檔案前先讀最新內容，避免覆蓋其他 Agent 的變更。
- 所有回應與文件使用繁體中文。
- 修改前先確認計畫，優先保留原有資料結構。
- 使用 `apply_patch` 編輯 repo 檔案；不要用 shell 重建檔案內容。
- **安裝邏輯只有一份：`scripts/install.mjs`（Node.js，跨平台共用）**。`install.ps1` 與 `install.sh` 是純轉呼叫殼層，**不得含任何複製、排除、雜湊或路徑判斷邏輯**——舊的雙軌實作已漂移過一次，不要走回去。改安裝行為一律只改 `install.mjs`。
- 對外文件的**主要安裝指令是 `node scripts/install.mjs`**，三個作業系統同一行。`install.ps1`／`install.sh` 降級為「可選的方便寫法」，不要再把它們寫成分平台的正式入口——那會讓人誤以為存在兩套安裝方式。
- 選 Node 而非 pwsh 或 Python 的理由：clasp v3 本來就要求 Node.js 22+，不新增任何依賴。**不要再提議「叫使用者先裝 PowerShell 7 就能單一腳本跑遍 Windows 與 macOS」**——pwsh 7 在兩個平台都不是內建的（Windows 是 5.1、macOS 是 zsh），等於兩邊各多一個 runtime 安裝步驟，而且 5.1 讀無 BOM 的繁中檔會誤判編碼、下載來的 `.ps1` 還卡執行原則。pwsh 7 只在維護者跑 `validate.ps1` 時要求，不是使用者的安裝門檻。
