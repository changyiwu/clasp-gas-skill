# 各平台差異說明

技能本體（`SKILL.md`）共用同一套 clasp v3 流程；平台差異集中在命令前綴、Skill 安裝位置與 MCP 設定。
這份只記「不一樣的地方」。非 Windows agent 執行主流程前要先讀本檔。

---

## 技能安裝位置

Agent Skill 的內容格式可以共用；本 repo 的安裝器只安裝到四個平台各自的正式全域目錄。

| 平台 | 全域位置 |
|---|---|
| Claude Code | `~/.claude/skills/clasp-setup/` |
| ChatGPT 應用程式／Codex | `~/.agents/skills/clasp-setup/` |
| OpenCode | `~/.config/opencode/skills/clasp-setup/` |
| Antigravity | `~/.gemini/config/skills/clasp-setup/` |

裝完沒出現在清單裡 → 重開 agent 或開一個新對話。

---

## Shell 差異

`SKILL.md` 裡的指令都是跨平台的，但要注意執行環境：

| 環境 | 注意 |
|---|---|
| Windows PowerShell | 使用 `npx.cmd --yes @google/clasp@3 ...`；不要只寫 `npx`，它可能解析成受執行原則限制的 `npx.ps1`。不要用 `&&` 串指令（PowerShell 5.1 會語法錯誤），用 `;` |
| macOS／Linux | 使用 `npx --yes @google/clasp@3 ...` |

`SKILL.md` 主流程以 Windows 命令示範。macOS／Linux 只把每行開頭的 `npx.cmd --yes @google/clasp@3` 換成 `npx --yes @google/clasp@3`。

---

## 授權會開瀏覽器

`clasp login` 與首次部署授權都需要**真的打開瀏覽器**。

- 在遠端／容器／CI 這類沒有瀏覽器的環境，Windows 改用 `npx.cmd --yes @google/clasp@3 login --no-localhost`；macOS／Linux 使用 `npx --yes @google/clasp@3 login --no-localhost`。
- 不論哪個平台，**選帳號與點「允許」只能使用者本人做**。技能會在這裡停下來等他，這是刻意的，不要跳過。

---

## 進階：把 clasp 當 MCP server 接（實驗性）

clasp v3 內建一個 stdio 的 MCP server，接上之後 agent 可以直接用工具呼叫操作 Apps Script，不必一直下 shell 指令。

**前提**：先 `clasp login`、先在 <https://script.google.com/home/usersettings> 開好 Apps Script API。它用的是跟 CLI 同一份憑證。

> ⚠️ 官方標示為 **EXPERIMENTAL**。技能主線流程刻意只用 CLI 以求穩定；這一段是給想長期用 agent 維護 Apps Script 專案的人選用的。

### Claude Code

```bash
claude mcp add clasp -- npx.cmd --yes @google/clasp@3 mcp
```

clasp 官方也提供 plugin 形式：在 Claude Code 中執行 `/plugin install @google/clasp`。

### ChatGPT 應用程式／Codex

`~/.codex/config.toml`：

```toml
[mcp_servers.clasp]
command = "npx.cmd"
args = ["--yes", "@google/clasp@3", "mcp"]
```

改完重啟 Codex，用 `codex mcp list` 確認。

### opencode

`~/.config/opencode/opencode.json`：

```json
{
  "mcp": {
    "clasp": {
      "type": "local",
      "command": ["npx.cmd", "--yes", "@google/clasp@3", "mcp"],
      "enabled": true
    }
  }
}
```

改完關掉 opencode 再開，用 `opencode mcp list` 確認。

### AntiGravity 2

設定檔位置請用 **Settings → Customizations → Installed MCP Servers → View raw config** 打開（不同版本讀的檔案不一樣，不要用猜的）：

```json
{
  "mcpServers": {
    "clasp": {
      "command": "npx.cmd",
      "args": ["--yes", "@google/clasp@3", "mcp"]
    }
  }
}
```

改完按該區的 **Refresh**。

> 註：以上是本機 stdio 形式，跟遠端 MCP 的鍵名規則不同——AntiGravity 只有**遠端**連線才必須用 `serverUrl`。

> macOS／Linux：上述 MCP 設定把 `npx.cmd` 改成 `npx`，其餘參數不變。

---

## 資料來源

指令語法對照 [google/clasp](https://github.com/google/clasp) 的 README 與原始碼核對過（含 `open-web-app` 的 `entryPoints` 行為與 `--json` 輸出）。
網路上多數既有教學仍是 clasp v2 語法，請以 `SKILL.md` 內的 v2 → v3 對照表為準。
