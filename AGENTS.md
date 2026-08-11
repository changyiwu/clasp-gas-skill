# clasp ＋ Google Apps Script 跨 Agent Skill（專案藍圖）

> 本檔為跨 Agent 通用的專案藍圖（AGENTS.md 開放標準）。任何 Agent 的每個 session 都應先讀本檔＋`handoff.md`。
> Claude Code 不直接讀 `AGENTS.md`，改由 `CLAUDE.md` 的 `@AGENTS.md` import 本檔；Claude 專屬規範寫在 `CLAUDE.md`。

## 專案簡介

這個 repo 維護一個跨 Claude Code、Codex、OpenCode、Antigravity 通用的 Agent Skill，帶使用者透過 clasp 連接 Google Apps Script，完成登入、建立或接續專案、推送程式碼、部署網頁應用程式與取得正確網址。

## 關鍵時程

- 無固定截止日期；以完成四個 Agent 的安裝、觸發與 clasp 主流程驗收為目前里程碑。

## 目標與路線圖

- [x] 階段一：完成三層級專案初始化與既有內容盤點
- [ ] 階段二：強化四 Agent 安裝器、冪等更新與逐檔驗證
- [ ] 階段三：修正 clasp 跨平台命令、授權與部署流程說明
- [ ] 階段四：在四個 Agent 完成實機觸發與 clasp 端到端測試
- [ ] 階段五：經使用者授權後同步四個全域 Skill 副本

## 資料夾結構

```text
clasp-gas-skill/
├── .codex-plugin/
│   └── plugin.json                 # Codex plugin manifest
├── scripts/
│   ├── install.ps1                 # Windows 安裝器
│   └── install.sh                  # macOS／Linux 安裝器
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
- 全域安裝與專案安裝使用不同目標矩陣；專案安裝使用 `.claude/skills/` 與 `.agents/skills/`。
- 安裝必須可重複執行，不得產生 `clasp-setup/clasp-setup/` 巢狀目錄或留下已刪除的舊檔。
- 安裝後用遞迴檔案清單與 SHA-256 驗證來源和目標一致。
- 未經使用者明確要求，不覆蓋四個全域 Skill 副本；正式同步交給 `sync-skills`。

### 安全與隱私

- 不要在任何檔案放入真實的 scriptId、deploymentId、Google 帳號、OAuth 憑證或其他個資；範例一律使用 `<placeholder>`。
- 不把 `.clasp.json`、`.clasprc.json`、`.env`、金鑰或 credentials 提交進 git。
- Workspace 帳號、Google 未驗證警告與網頁應用程式公開權限都必須依實際狀態判斷，不使用過度絕對的繞過指示。
- 網頁應用程式交付前，用非擁有者帳號或無痕視窗驗證實際存取權限。

### 驗證要求

- 修改 Skill 後執行 Skill validator；修改 plugin manifest 後執行 plugin validator。
- 安裝器必須測試首次安裝、重複安裝、更新、來源刪檔後清理與路徑安全。
- 檢查所有文字檔為有效 UTF-8 且不含 BOM，並執行敏感資訊掃描。
- 網路或帳號授權不足時，只能回報「未驗證」，不可宣稱 clasp 線上流程已通過。

## 同步層級（本專案初始化至第 3 層級）

| 層級 | 平台 | 位置 | 讀取時機 |
|------|------|------|---------|
| L1 | 本地（GDrive） | `AGENTS.md`＋`handoff.md`（不進 git，只走雲端硬碟）＋`CLAUDE.md`（橋接） | 每個 session |
| L2 | GitHub | 初始化中；預定 `changyiwu/clasp-gas-skill` | 指定時 |
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

