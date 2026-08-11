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
2. `clasp login` — 提醒選個人 Google 帳號
3. 建立專案（可綁定既有試算表，或新建一份）
4. 產出 `Code.gs` ＋ `index.html` 並 `push`
5. 部署成網頁應用程式，**用正確的方式取得網址**
6. 請使用者實測，確認資料真的有進試算表

## 這份技能特別處理的三個坑

| 坑 | 症狀 | 技能怎麼處理 |
|---|---|---|
| **拿錯 ID 拼網址** | 給出去的網址打開是「網頁不存在」 | 強制走 `clasp open-web-app <deploymentId> --json`，禁止用 `scriptId` 去拼 `/macros/s/.../exec` |
| **v2 舊指令名** | 「指令不存在」，然後 agent 開始亂試 | 內建 v2 → v3 對照表（`create`→`create-script`、`login --status`→`show-authorized-user` …） |
| **受管理的公司／學校帳號** | `admin_policy_enforced`，使用者自己解不了 | 登入前就先提醒選個人 Gmail，撞到直接判定並給退路 |

技能也內建了硬性的隱私紅線（不把真實姓名寫進雲端試算表）與**卡住就換路**的退場機制——clasp 是效率升級，不是做出成品的必要條件。

---

## 安裝

Agent Skill 的規格是共通的，差別只在放哪個資料夾。**兩個目標資料夾就能涵蓋四個平台。**

| 平台 | 讀取的資料夾 |
|---|---|
| Claude Code | `~/.claude/skills/` |
| ChatGPT 應用程式（Codex） | `~/.agents/skills/` |
| AntiGravity 2 | `~/.agents/skills/` |
| opencode | 以上兩個都讀（另外也讀 `~/.config/opencode/skills/`）|

### 一鍵安裝

Windows（PowerShell）：

```powershell
git clone https://github.com/mathruffian-dot/clasp-gas-skill.git
.\clasp-gas-skill\scripts\install.ps1
```

macOS／Linux：

```bash
git clone https://github.com/mathruffian-dot/clasp-gas-skill.git
bash ./clasp-gas-skill/scripts/install.sh
```

腳本會把 `skills/clasp-setup` 同時複製到 `~/.claude/skills/` 與 `~/.agents/skills/`，四個平台一次到位。

### 手動安裝

Windows（PowerShell）：

```powershell
Copy-Item -Recurse -Force ".\clasp-gas-skill\skills\clasp-setup" "$env:USERPROFILE\.claude\skills\clasp-setup"
Copy-Item -Recurse -Force ".\clasp-gas-skill\skills\clasp-setup" "$env:USERPROFILE\.agents\skills\clasp-setup"
```

macOS／Linux：

```bash
mkdir -p ~/.claude/skills ~/.agents/skills
cp -r ./clasp-gas-skill/skills/clasp-setup ~/.claude/skills/
cp -r ./clasp-gas-skill/skills/clasp-setup ~/.agents/skills/
```

只裝在單一專案的話，把同一個資料夾放進專案裡的 `.claude/skills/` 或 `.agents/skills/` 即可。

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
- 一個**個人** Google 帳號（受管理的公司／學校 Workspace 帳號會被 `admin_policy_enforced` 擋下）
- 到 <https://script.google.com/home/usersettings> 打開「Google Apps Script API」（開完要等 1–2 分鐘生效）

技能本身不需要任何 API 金鑰，全部走 `npx @google/clasp` 與瀏覽器 OAuth。

---

## 檔案結構

```text
clasp-gas-skill/
├── .codex-plugin/
│   └── plugin.json
├── skills/
│   └── clasp-setup/
│       ├── SKILL.md                     ← 技能本體
│       ├── agents/
│       │   └── openai.yaml
│       └── references/
│           └── platform-notes.md        ← 四平台安裝細節與 clasp MCP 接法
├── scripts/
│   ├── install.ps1
│   └── install.sh
├── AGENTS.md
├── LICENSE
└── README.md
```

## 相容性說明

- 對照 **clasp v3** 撰寫並逐條核對過官方 README 與原始碼（含 `open-web-app` 的 `entryPoints` 行為）。
- 網路上多數既有教學仍是 v2 語法，照著下會先撞「指令不存在」；技能內附完整的 v2 → v3 對照表。
- clasp v3 另有實驗性的內建 MCP server（`npx -y @google/clasp mcp`），技能的主線流程刻意只用 CLI 以求穩定，MCP 接法列在 `platform-notes.md` 供進階使用者選用。

## 授權

MIT License
