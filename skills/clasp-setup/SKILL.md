---
name: clasp-setup
description: 把 Google Apps Script 接進 AI agent 的完整流程（clasp 登入 → 建立綁定試算表的專案 → push 程式碼 → 部署成網頁應用程式 → 取得正確網址）。使用者說「接 Apps Script」「clasp 登入」「把試算表變成網頁表單」「部署 GAS 網頁應用程式」「用 clasp 改線上的程式碼」時載入。
license: MIT
---

# Apps Script ＋ clasp 連線

> **這份是寫給 AI agent 照著執行的**，不是給人讀的教學。
> 目標：讓 agent 能「讀得到、改得到、推得回」使用者線上那份 Apps Script 程式碼。

---

## 為什麼要用 clasp

不用 clasp 的話，agent 是瞎的——每改一次都要使用者自己複製、切到瀏覽器、貼上、存檔。
接上 clasp 之後是完整的編輯迴圈：`clasp pull` 讀下來 → 改 → `clasp push` 推回去。

需要反覆調整的專案，這個差別會被放大很多次。

---

## 你面對的使用者

預設把使用者當成**沒有程式基礎**的人（老師、行政人員、想自動化日常工作的一般使用者）。

- 全程用**使用者的語言**，不要丟術語。
- 需要他本人操作的地方（選帳號、點允許、去試算表確認），**停下來講清楚，等他回覆**。
- Windows 一律用 PowerShell，**不要用 `&&` 串指令**（PowerShell 5.1 會語法錯誤），用 `;`。

---

## 🔴 六條硬性紅線

### 1. 一定要用個人 Google 帳號

`clasp login` 時**主動提醒他選個人 Gmail，不要選學校或公司的 Workspace 帳號**。

受管理的 Workspace 帳號會回 `admin_policy_enforced`，那是**該網域的管理員才能解的**（要進 Admin Console 把 clasp 的 OAuth Client ID 加白名單）。使用者自己弄不了，不要讓他在那邊試。

### 2. 用 `npx`，不要全域安裝

一律 `npx @google/clasp ...`。

理由：不用先安裝，而且**繞開 Windows 的執行原則限制**。使用者主動要求常用時，才建議 `npm install -g @google/clasp`，並準備處理執行原則。

### 3. 反覆失敗就提退路，不要無限重試

如果 `clasp login` 或 API 授權連續失敗，**不要繼續重試迴圈**。主動說：

> 「clasp 這條卡住了。我們換一條——我直接把程式碼給你，你貼到 script.google.com 就好，做出來的東西完全一樣，只是之後每次改都要重貼一次。要換嗎？」

**clasp 是效率升級，不是做出成品的必要條件。** 保住成品優先。

### 4. 不要把可識別個資寫進雲端

試算表欄位**不要放真實姓名**，改用不具識別性的代號（編號、流水號等）。使用者提供的資料裡有姓名欄，**主動指出並建議移除**。

也不要放身分證字號、電話、地址、家長聯絡方式。

理由很實際：網頁應用程式的網址通常會發給一群人，那是**公開網頁**；而試算表本身也可能被誤設成任何人可讀。

### 5. 網頁應用程式的網址一律用 `open-web-app --json` 取得

**不准自己拼網址。** 詳見步驟 5——`scriptId`、`parentId`、`deploymentId` 是三個不同的東西，
拼錯的結果是「網頁不存在」，而且看起來像部署失敗，會把你帶去修錯的地方。

### 6. 不要覆蓋既有的 clasp 專案

執行 `clasp create-script` 前先確認當前資料夾**沒有** `.clasp.json`。有的話先問使用者這是不是他要接的專案，不要直接蓋掉。

---

## 前置檢查（依序跑，任一不過就停下來說）

| 檢查 | 怎麼做 | 不過的話 |
|---|---|---|
| Node 版本 | `node --version` | clasp v3 要 **Node 22 以上**。低於或找不到 → 問他「要我幫你裝 Node.js LTS 嗎？」 |
| Apps Script API 開關 | 無法用指令查，**直接問使用者** | 沒開 → 給他 <https://script.google.com/home/usersettings>，把「Google Apps Script API」打開。<br>**告訴他要等 1–2 分鐘才生效**，這段時間先做別的，不要空等 |
| 資料夾 | 當前目錄是不是他要放專案的資料夾 | 不是 → 先確認要在哪裡建 |

---

## 步驟

### 1. clasp 登入

```
npx @google/clasp login
```

**執行前先講**：「等一下瀏覽器會打開，**請選你的個人 Gmail**，然後點允許。」

### 2. 驗證登入

```
npx @google/clasp show-authorized-user --json
```

看到帳號 = 成功。**沒看到就不要往下做**，先照錯誤表處理。

> ⚠️ 指令是 `show-authorized-user`，**不是 `login --status`**——v3 沒有那個旗標。

### 3. 建立專案

問使用者要叫什麼名字，然後依情況選一種：

| 情境 | 指令 |
|---|---|
| 要**新建**一份試算表並綁定 | `npx @google/clasp create-script --type sheets --title "專案名"` |
| 要綁到**現有**的試算表／文件／簡報 | `npx @google/clasp create-script --title "專案名" --parentId "<檔案ID>"` |
| 不綁任何檔案（獨立腳本） | `npx @google/clasp create-script --type standalone --title "專案名"` |

- `--parentId` 就是檔案網址中間那一段：`https://docs.google.com/spreadsheets/d/{這一段}/edit`
- **有 `--parentId` 時 `--type` 會被忽略**。

> 綁定試算表（container-bound）的好處：資料直接落在他看得懂的表格裡，不用另外接資料庫。

### 4. 產出程式碼並推上去

- 架構用**純 GAS ＋ `google.script.run` 同源溝通**，**不要**用 `fetch` 打自己的 `/exec`（會有 CORS 問題）。
- `appsscript.json` 裡要有 `"webapp"` 設定才能部署成網頁應用程式。
- `npx @google/clasp push` 推上去。

> 常見的起手式：一個 `Code.gs`（後端：讀寫試算表）＋ 一個 `index.html`（前端表單），
> 使用者填表 → `google.script.run.saveData(...)` → 資料進試算表。

### 5. 部署為網頁應用程式

#### 🔴 網址不能自己組——這是實際踩過的坑

**症狀**：agent 給出的網址打開是「網頁不存在」或連到錯誤的頁面。

**原因**：clasp 裡有**三種網址、三個不同的 ID**，很容易拿錯：

| 要開什麼 | 指令 | 網址來源 | 用哪個 ID |
|---|---|---|---|
| Apps Script 編輯器 | `clasp open-script` | `script.google.com/d/<id>/edit` | **scriptId** |
| 綁定的試算表 | `clasp open-container` | `drive.google.com/open?id=<id>` | **parentId** |
| **部署好的網頁應用程式** | `clasp open-web-app <id>` | 🔴 **API 回傳的 `webApp.url`** | **deploymentId** |

> 🔴 **網頁應用程式的網址「組不出來」，只能跟 API 要。**
> clasp 原始碼裡**沒有任何 `/macros/s/...` 的網址範本**——它一律是
> `deploymentId → 打 API 拿 entryPoints → 找 entryPointType === 'WEB_APP' → 讀出 webApp.url`。
>
> **所以絕對不要拿 `.clasp.json` 裡的 `scriptId` 去拼 `https://script.google.com/macros/s/<scriptId>/exec`。**
> 那個 ID 是錯的，拼出來一定是 404。這正是「網頁不存在」的來源。

#### 正確做法

```powershell
npx @google/clasp create-deployment --description "第一版"
```

從輸出取得 **deploymentId**，然後：

```powershell
npx @google/clasp open-web-app <deploymentId> --json
```

`--json` 是**全域旗標**，會把真正的網址印成 `{"url": "..."}` 給你讀。**用它印出來的網址，不要自己拼。**

> - 拿不到 deploymentId 就先 `npx @google/clasp list-deployments`。
> - **一定要帶 deploymentId。** 不帶的話，clasp 只有在互動式終端機才會跳選單；在 agent 的非互動環境會直接報 `Deployment ID is required.`
> - 這個指令除了印出網址，**也會順手把瀏覽器打開**，屬正常行為。
> - 回 `No web app entry point found` → 這個部署不是網頁應用程式類型，回去確認 `appsscript.json` 的 `webapp` 設定。

拿到正確網址之後，如果使用者要發給一群人，**順手產生 QR Code** 給他。

⚠️ 首次部署會跳授權，**要先跟他說**：

> 「會跳一個紅色警告說『Google 尚未驗證這個應用程式』。那是正常的——那支腳本就是你自己寫的。請點左下角『進階』→『前往〈你的專案名〉（不安全）』→ 允許。」

### 6. 請他實測

**停下來**，請他實際打開網址填一筆，然後去試算表確認資料有進去。**等他回報再繼續。**

---

## 錯誤處理

| 錯誤 | 意義 | 你要做的 |
|---|---|---|
| `admin_policy_enforced` | 用到受管理的 Workspace 帳號 | `npx @google/clasp logout`，重來並**強調選個人 Gmail** |
| `User has not enabled the Apps Script API` | 開關沒開或**還沒生效** | 給 <https://script.google.com/home/usersettings>，請他開，**等 1–2 分鐘**再重試 |
| 「因為這個系統上已停用指令碼執行」 | Windows 執行原則 | 用 `npx` 而非全域安裝即可繞開；若已全域安裝，用 `Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned` |
| 「Google 尚未驗證這個應用程式」 | 正常，自己的腳本 | 引導：進階 → 前往〈專案名〉（不安全）→ 允許 |
| `node: 找不到指令` | 沒裝 Node | 回前置檢查 |
| 指令名稱找不到 | **clasp v3 把指令全改名了**（見下方對照表） | 用 v3 的名字。舊教學與舊記憶都是 v2 的，照著下會先撞「指令不存在」然後開始亂試 |
| **給出去的網址打開是「網頁不存在」** | 🔴 **拿 `scriptId` 去拼 `/macros/s/.../exec` 了。**網頁應用程式的網址只能跟 API 要 | `clasp open-web-app <deploymentId> --json`，用它印出來的網址（見步驟 5）|
| `No web app entry point found` | 這個部署不是網頁應用程式類型 | 確認 `appsscript.json` 有 `webapp` 設定，重新部署 |
| `Deployment ID is required.` | 非互動環境沒帶 deploymentId | 先 `list-deployments` 拿到 ID 再帶進去 |

**同一個錯誤重試兩次還不過 → 走紅線 3 的退路，不要繼續耗。**

### v2 → v3 指令對照

| 舊（v2，別再用） | 新（v3） |
|---|---|
| `clasp create` | `clasp create-script` |
| `clasp clone` | `clasp clone-script` |
| `clasp open` | `clasp open-script` |
| `clasp deploy` | `clasp create-deployment` |
| `clasp deployments` | `clasp list-deployments` |
| `clasp undeploy` | `clasp delete-deployment` |
| `clasp status` | `clasp show-file-status` |
| `clasp login --status` | `clasp show-authorized-user` |
| （無） | `clasp open-container`、`clasp open-web-app` |

---

## 進階：把 clasp 本身當 MCP 用（實驗性）

clasp v3 內建一個 stdio 的 MCP server，可以讓 agent 直接用工具呼叫操作 Apps Script，而不是一直下 shell 指令。

```
npx -y @google/clasp mcp
```

- 前提一樣：**先 `clasp login`、先開好 Apps Script API**，它用的是同一份憑證。
- 官方標示為 **EXPERIMENTAL**。本技能的主線流程刻意只用 CLI，**穩定度優先**。
- 使用者主動問起、或希望長期用 agent 維護 Apps Script 專案時，才建議他接。
- 各家 agent 的接法見 `references/platform-notes.md`。

---

## 完成後回報

```
✅ clasp 已登入（帳號：<使用者的 gmail>）
✅ 專案已建立並綁定試算表「<專案名>」
✅ 已部署，網址：<用 open-web-app --json 取得的網址>
✅ QR Code 已產生（如果有需要發給多人）
📋 待你確認：打開網址填一筆，看試算表有沒有進資料

下一步可以做的：
- 加 CalendarApp／MailApp，讓它自動寫行事曆或寄通知
- 把專案資料夾納入 Git 版控
```

**然後停下來。** 不要自作主張繼續加功能。

---

## 不要做的事

- ❌ 不要用受管理的 Workspace 帳號登入
- ❌ 不要在 `clasp login` 失敗時無限重試——兩次不過就提退路
- ❌ 不要把真實姓名或其他個資寫進試算表或程式碼
- ❌ 不要用 `fetch` 打自己的 `/exec`（用 `google.script.run`）
- ❌ 不要主動幫他建定時觸發器
- ❌ 不要在使用者還沒確認「資料真的有進試算表」之前，就宣告完成
- ❌ **不要自己拼網頁應用程式的網址**（`/macros/s/<scriptId>/exec` 一定是錯的），一律用 `open-web-app --json` 取得
- ❌ 不要用 clasp v2 的舊指令名（`create`、`open`、`deploy`、`deployments`、`login --status`）
