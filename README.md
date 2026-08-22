# clasp ＋ Apps Script 連線技能

一個**跨 agent 通用**的 Agent Skill，讓 AI agent 能真正「讀得到、改得到、推得回」你線上那份 Google Apps Script 程式碼——而不是把程式碼吐給你、要你自己複製貼上到瀏覽器。

適用於：**Claude Code**、**ChatGPT 應用程式（Codex）**、**opencode**、**AntiGravity 2**

---

## 這解決什麼問題

沒有 clasp 的時候，agent 是瞎的：它看不到 `script.google.com` 上那份程式碼，每改一次都要你複製、切視窗、貼上、存檔。

接上 clasp 之後是完整的編輯迴圈：

```
clasp pull  →  agent 讀得到現有程式碼
   ↓
agent 改
   ↓
clasp push  →  推回雲端，直接生效
```

需要反覆調整的專案，這個差別會被放大很多次。

## 技能會帶使用者走完的流程

1. 前置檢查（Node 版本、Apps Script API 開關）
2. `clasp login` — 預設建議個人 Google 帳號，Workspace 受政策限制時提供管理員處理路徑
3. 建立專案（可綁定既有試算表，或新建一份）
4. 產出 `Code.gs` ＋ `index.html` 並 `push`
5. 部署成網頁應用程式，**用正確的方式取得網址**
6. 請使用者實測，確認資料真的有進試算表

## 這份技能特別處理的四個坑

| 坑 | 症狀 | 技能怎麼處理 |
|---|---|---|
| **拿錯 ID 拼網址** | 給出去的網址打開是「網頁不存在」 | 強制走 `clasp open-web-app <deploymentId> --json`，禁止用 `scriptId` 去拼 `/macros/s/.../exec` |
| **v2 舊指令名** | 「指令不存在」，然後 agent 開始亂試 | 內建 v2 → v3 對照表（`create`→`create-script`、`login --status`→`show-authorized-user` …） |
| **受管理的公司／學校帳號** | `admin_policy_enforced`，使用者自己解不了 | 登入前就先提醒選個人 Gmail，撞到直接判定並給退路 |
| **部署網址只有擁有者能開** | 自己測正常，分享給別人卻被拒絕 | 取得網址後再確認部署存取權，並用無痕視窗或第二帳號實測 |

技能也內建了硬性的隱私紅線（不把真實姓名寫進雲端試算表）與**卡住就換路**的退場機制——clasp 是效率升級，不是做出成品的必要條件。

---

## 安裝

Agent Skill 的內容格式可以共用，但全域安裝採四個平台各自的正式目錄：

| 平台 | 讀取的資料夾 |
|---|---|
| Claude Code | `~/.claude/skills/` |
| ChatGPT 應用程式（Codex） | `~/.agents/skills/` |
| OpenCode | `~/.config/opencode/skills/` |
| Antigravity | `~/.gemini/config/skills/` |

### 一鍵安裝

**Windows、macOS、Linux 都是同一行**，不必分平台：

```bash
git clone https://github.com/changyiwu/clasp-gas-skill.git
node ./clasp-gas-skill/scripts/install.mjs
```

安裝邏輯只有 `scripts/install.mjs` 這一份，三個作業系統跑的是同一段程式碼，不會有兩套實作各自漂移的問題。Node.js 不是額外負擔：clasp v3 本來就要求它，沒裝 Node 這個技能第一步就跑不動。直接呼叫 `node` 也繞開了 Windows 的 PowerShell 執行原則與 `Unblock-File`。

<details>
<summary>可選：習慣點兩下或用殼層進入點的話</summary>

```powershell
# Windows
.\clasp-gas-skill\scripts\install.ps1
```

```bash
# macOS／Linux
bash ./clasp-gas-skill/scripts/install.sh
```

這兩支只負責找到 `node` 並轉呼叫 `install.mjs`，沒有任何自己的安裝邏輯，行為與上面那行完全一樣。

</details>

> 為什麼不做成單一 PowerShell 腳本跑遍 Windows 與 macOS？因為 PowerShell 7 在**兩個平台都不是內建的**——Windows 內建的是 5.1，macOS 內建的是 zsh，等於要使用者各多裝一個 runtime；而 Node 是本來就必須有的。

全域模式只安裝到**已存在**的 Agent Skill 根目錄，不會替尚未安裝的工具建立空目錄。每個目標都會做遞迴 SHA-256 驗證；重複執行會更新原位置，不會產生巢狀 `clasp-setup/clasp-setup`，也會清掉來源已刪除的舊檔。
安裝器只提供全域安裝，不會在目前 repo 建立專案層級的 Skill 副本。

> 裝完技能沒出現在清單裡 → 重開 agent 或開一個新對話。
> 各平台的細節與差異見 [`skills/clasp-setup/references/platform-notes.md`](skills/clasp-setup/references/platform-notes.md)。

---

## 使用

裝好之後直接用自然語言講就會觸發：

```
幫我把這份試算表做成一個可以填的網頁表單
接 Apps Script
用 clasp 把線上那支腳本抓下來改
幫我部署成網頁應用程式
```

技能會在需要你本人操作的地方（選帳號、點允許、去試算表確認）**停下來等你**，不會自己往下衝。

---

## 需求

- **Node.js 22 以上**（clasp v3 的要求）
- 建議使用個人 Google 帳號；Workspace 是否可用取決於網域政策，受限時需管理員 allow-list clasp 或提供內部 OAuth 專案
- 到 <https://script.google.com/home/usersettings> 打開「Google Apps Script API」（開完要等 1–2 分鐘生效）

技能本身不需要任何 API 金鑰。Windows 走 `npx.cmd --yes @google/clasp@3`，macOS／Linux 走 `npx --yes @google/clasp@3` 與瀏覽器 OAuth。

---

## 檔案結構

```text
clasp-gas-skill/
├── .codex-plugin/
│   └── plugin.json
├── apps/
│   └── student-grade-system/       ← 已部署的 GAS 同源前後端完整原始碼
├── skills/
│   └── clasp-setup/
│       ├── SKILL.md                     ← 技能本體
│       ├── agents/
│       │   └── openai.yaml
│       └── references/
│           └── platform-notes.md        ← 四平台安裝細節與 clasp MCP 接法
├── scripts/
│   ├── install.mjs                   ← 安裝器本體，也是主要指令（跨平台共用）
│   ├── install.ps1                   ← 可選的 Windows 進入點，只轉呼叫 install.mjs
│   ├── install.sh                    ← 可選的 macOS／Linux 進入點，只轉呼叫 install.mjs
│   └── validate.ps1                  ← 結構、編碼、安全、殼層漂移與重複安裝驗證
├── AGENTS.md
├── CLAUDE.md
├── .gitattributes
├── LICENSE
└── README.md
```

## 完整實作範例

`apps/student-grade-system/` 保存一套已實際部署的學生成績管理 Web App。HTML、CSS、瀏覽器端 JavaScript、Apps Script 後端與 manifest 都在同一個資料夾，前端以 `google.script.run` 同源呼叫後端，不依賴 Netlify 或舊 repo。

Windows PowerShell 從該資料夾維護線上專案：

```powershell
cd .\apps\student-grade-system
npx.cmd --yes @google/clasp@3 show-authorized-user --json
npx.cmd --yes @google/clasp@3 show-file-status
npx.cmd --yes @google/clasp@3 push
```

本機 `.clasp.json` 保存既有 GAS 連線但不進 Git；從 GitHub 重新 clone 時，必須自行重新連結有權限的 Apps Script 專案。

## 相容性說明

- 對照 **clasp v3** 撰寫並逐條核對過官方 README 與原始碼（含 `open-web-app` 的 `entryPoints` 行為）。
- 網路上多數既有教學仍是 v2 語法，照著下會先撞「指令不存在」；技能內附完整的 v2 → v3 對照表。
- clasp v3 另有實驗性的內建 MCP server（Windows：`npx.cmd --yes @google/clasp@3 mcp`），技能的主線流程刻意只用 CLI 以求穩定，MCP 接法列在 `platform-notes.md` 供進階使用者選用。

## 驗證

Windows 可在 repo 根目錄以 PowerShell 7 執行：

```powershell
pwsh -NoProfile -File .\scripts\validate.ps1
```

驗證器會檢查 Skill／plugin 基本結構、四平台文件路徑、UTF-8 BOM、敏感資訊樣式，並在系統暫存目錄模擬四個全域根目錄、連續安裝兩次，確認來源與四個副本的 SHA-256 完全一致。

## 來源與授權

本 repo 接續修改自 [mathruffian-dot/clasp-gas-skill](https://github.com/mathruffian-dot/clasp-gas-skill)，保留原作者 MIT 著作權聲明；後續跨 Agent 安裝、驗證與安全流程由 `changyiwu` 維護。

## 授權

MIT License
