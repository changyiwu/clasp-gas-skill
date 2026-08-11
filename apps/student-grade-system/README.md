# GAS 同源學生成績管理系統

這個資料夾是學生成績管理 Web App 的完整且唯一原始碼。原本部署在 Netlify 的前端已搬入既有 Google Apps Script；現在 HTML、CSS、JavaScript、CRUD 後端與 Google Sheets 存取都由同一個 GAS Web App 部署提供，不依賴舊 repo、Netlify 網站或前端硬編碼 API 網址。

## 架構

- `index.html`：網頁主畫面
- `style.html`：由 HTML Service 內嵌的 CSS
- `app.html`：瀏覽器端程式，以 `google.script.run` 呼叫後端
- `gas_code.js`：HTML Service 入口、資料驗證與 Google Sheets CRUD
- `appsscript.json`：Apps Script manifest
- `.claspignore`：只允許 GAS 所需的 5 個部署檔案上傳
- `.clasp.json`：本機與既有 Apps Script 的連線資訊，由 repo 根目錄 `.gitignore` 排除
- `package.json`／`package-lock.json`：固定本機 clasp v3 依賴版本；不需要搬 `node_modules`

## 本機與線上同步

先切換到這個資料夾，再以 Windows PowerShell 使用固定 clasp v3：

```powershell
cd .\apps\student-grade-system
npx.cmd --yes @google/clasp@3 show-authorized-user --json
npx.cmd --yes @google/clasp@3 pull
npx.cmd --yes @google/clasp@3 push
```

建立新的不可變版本部署：

```powershell
npx.cmd --yes @google/clasp@3 create-deployment --description "GAS 同源前端"
```

從上一步輸出取得 `deploymentId`，再向 Apps Script API 取得真正的網頁網址：

```powershell
npx.cmd --yes @google/clasp@3 open-web-app <deploymentId> --json
```

不要自行拼接 `/macros/s/.../exec` 網址；`.clasp.json` 的 `scriptId` 不是 Web App 網址 ID。

## 開發規則

- 前端與自己的 GAS 後端一律用 `google.script.run`，不使用跨網域 `fetch`。
- `.claspignore` 只允許 `gas_code.js`、`appsscript.json` 與三個根目錄 HTML 檔案上傳。
- 不在 Git 中提交 `.clasp.json`、OAuth 憑證或任何金鑰。
- 部署前先 `pull` 並檢查 Git 差異，避免覆蓋線上較新的程式。

## 刪除舊本機專案前

只要此資料夾的部署檔、`.claspignore`、本機 `.clasp.json` 與 Node 鎖檔都已驗證，舊的 `clasp-netlify-mcp-guide` 本機資料夾便不再是執行或維護依賴。刪除舊本機資料夾不會刪除線上 GAS 或 Google Sheets；請勿刪除 Apps Script 線上專案、Web App 部署或試算表。

## 隱私與存取權限

這個範例會保存姓名與成績，屬於可識別個人資料。`appsscript.json` 目前設定為匿名可存取；公開分享網址前，請在 Apps Script 的「部署 → 管理部署」確認執行身分與存取範圍符合實際用途，並用無痕視窗或非擁有者帳號測試。正式使用時，優先以不可識別的學生代號取代姓名，或限制只允許指定帳號存取。
