/**
 * 學生成績管理系統 - Google Apps Script Web App
 *
 * 同時提供 HTML 前端與 CRUD 後端，並能自動在使用者 Google Drive
 * 建立/連結名為 "StudentGradeSystemDatabase" 的試算表。
 */

// 取得或建立試算表及工作表
function getOrCreateSheet() {
  var properties = PropertiesService.getScriptProperties();
  var sheetId = properties.getProperty('SPREADSHEET_ID');
  var ss;

  if (sheetId) {
    try {
      ss = SpreadsheetApp.openById(sheetId);
    } catch (e) {
      // 若 ID 失效，清除之以重試
      properties.deleteProperty('SPREADSHEET_ID');
    }
  }

  if (!ss) {
    // 嘗試在雲端硬碟搜尋同名檔案
    var files = DriveApp.getFilesByName("StudentGradeSystemDatabase");
    if (files.hasNext()) {
      var file = files.next();
      sheetId = file.getId();
      properties.setProperty('SPREADSHEET_ID', sheetId);
      ss = SpreadsheetApp.openById(sheetId);
    } else {
      // 找不到則建立新檔案
      ss = SpreadsheetApp.create("StudentGradeSystemDatabase");
      sheetId = ss.getId();
      properties.setProperty('SPREADSHEET_ID', sheetId);
    }
  }

  var sheet = ss.getSheetByName("Grades");
  if (!sheet) {
    sheet = ss.insertSheet("Grades");
    // 初始化標頭欄位
    sheet.appendRow([
      "ID",
      "StudentID",
      "Name",
      "Class",
      "Math",
      "English",
      "Science",
      "History",
      "Average",
      "Status",
      "Notes",
      "UpdatedAt"
    ]);
    // 刪除預設的 Sheet1 (若存在且非 Grades)
    var defaultSheet = ss.getSheetByName("工作表1") || ss.getSheetByName("Sheet1");
    if (defaultSheet && defaultSheet.getName() !== "Grades") {
      try {
        ss.deleteSheet(defaultSheet);
      } catch(e) {}
    }
  }
  return sheet;
}

// 產生隨機 UUID
function generateUUID() {
  return Utilities.getUuid();
}

// 讀取 HTML 片段，供 index.html 樣板內嵌 CSS 與 JavaScript。
function include(filename) {
  return HtmlService.createHtmlOutputFromFile(filename).getContent();
}

// 網頁應用程式入口：前端與後端由同一個 GAS 部署提供。
function doGet() {
  return HtmlService.createTemplateFromFile('index')
    .evaluate()
    .setTitle('卓越學生成績管理系統')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
}

// 輔助函式：保留舊版 POST API 的 JSON 輸出相容性。
function jsonResponse(data) {
  return ContentService.createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

// 由前端透過 google.script.run 呼叫：讀取所有資料。
function getStudents() {
  try {
    var sheet = getOrCreateSheet();
    var data = sheet.getDataRange().getValues();
    if (data.length === 0) {
      return { success: true, data: [] };
    }
    var headers = data[0];
    var list = [];

    for (var i = 1; i < data.length; i++) {
      var row = data[i];
      var item = {};
      for (var j = 0; j < headers.length; j++) {
        item[headers[j]] = row[j];
      }
      list.push(item);
    }

    return {
      success: true,
      data: list
    };
  } catch (error) {
    return {
      success: false,
      error: error.toString()
    };
  }
}

// 由前端透過 google.script.run 呼叫：新增或修改一筆資料。
function saveStudent(studentData) {
  try {
    var normalized = normalizeStudentData_(studentData || {});
    var sheet = getOrCreateSheet();
    var id = normalized.ID || generateUUID();
    var average = (
      normalized.Math + normalized.English + normalized.Science + normalized.History
    ) / 4.0;
    var status = average >= 60 ? "及格" : "不及格";
    var updatedAt = new Date().toISOString();
    var rowValues = [[
      id,
      normalized.StudentID,
      normalized.Name,
      normalized.Class,
      normalized.Math,
      normalized.English,
      normalized.Science,
      normalized.History,
      average,
      status,
      normalized.Notes,
      updatedAt
    ]];

    if (!normalized.ID) {
      sheet.appendRow([
        id,
        normalized.StudentID,
        normalized.Name,
        normalized.Class,
        normalized.Math,
        normalized.English,
        normalized.Science,
        normalized.History,
        average,
        status,
        normalized.Notes,
        updatedAt
      ]);
    } else {
      var data = sheet.getDataRange().getValues();
      var rowIndex = -1;
      for (var i = 1; i < data.length; i++) {
        if (data[i][0] === id) {
          rowIndex = i + 1; // 轉為 1-based index
          break;
        }
      }

      if (rowIndex < 0) {
        return { success: false, error: "找不到要修改的資料" };
      }
      sheet.getRange(rowIndex, 1, 1, 12).setValues(rowValues);
    }

    return {
      success: true,
      data: { id: id, average: average, status: status }
    };
  } catch (error) {
    return {
      success: false,
      error: error.toString()
    };
  }
}

// 由前端透過 google.script.run 呼叫：刪除一筆資料。
function deleteStudent(id) {
  try {
    if (!id) {
      return { success: false, error: "缺少要刪除的資料 ID" };
    }

    var sheet = getOrCreateSheet();
    var data = sheet.getDataRange().getValues();
    var rowIndex = -1;
    for (var i = 1; i < data.length; i++) {
      if (data[i][0] === id) {
        rowIndex = i + 1;
        break;
      }
    }

    if (rowIndex < 0) {
      return { success: false, error: "找不到要刪除的資料" };
    }

    sheet.deleteRow(rowIndex);
    return { success: true, message: "刪除成功" };
  } catch (error) {
    return { success: false, error: error.toString() };
  }
}

function normalizeStudentData_(studentData) {
  var requiredText = ['StudentID', 'Name', 'Class'];
  for (var i = 0; i < requiredText.length; i++) {
    var key = requiredText[i];
    if (!String(studentData[key] || '').trim()) {
      throw new Error('缺少必填欄位：' + key);
    }
  }

  var scoreKeys = ['Math', 'English', 'Science', 'History'];
  var normalized = {
    ID: String(studentData.ID || ''),
    StudentID: String(studentData.StudentID).trim(),
    Name: String(studentData.Name).trim(),
    Class: String(studentData.Class).trim(),
    Notes: String(studentData.Notes || '').trim()
  };

  for (var j = 0; j < scoreKeys.length; j++) {
    var scoreKey = scoreKeys[j];
    var score = Number(studentData[scoreKey]);
    if (!isFinite(score) || score < 0 || score > 100) {
      throw new Error(scoreKey + ' 必須介於 0 至 100');
    }
    normalized[scoreKey] = score;
  }

  return normalized;
}

// 保留舊版 Netlify 前端的 POST API 相容性；新 GAS 前端不使用此入口。
function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return jsonResponse({ success: false, error: "Missing payload" });
    }

    var payload = JSON.parse(e.postData.contents);
    if (payload.action === 'create' || payload.action === 'update') {
      return jsonResponse(saveStudent(payload.data || {}));
    }
    if (payload.action === 'delete') {
      return jsonResponse(deleteStudent(payload.id));
    }
    return jsonResponse({ success: false, error: "Invalid action" });
  } catch (error) {
    return jsonResponse({ success: false, error: error.toString() });
  }
}
