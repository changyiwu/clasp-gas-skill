#!/usr/bin/env node
// 安裝 clasp-setup 技能到本機四個 Agent 全域目錄。
//
// 這是安裝邏輯的「唯一」實作，Windows／macOS／Linux 共用同一份程式碼。
// scripts/install.ps1 與 scripts/install.sh 只是轉呼叫殼層，不得含任何安裝邏輯。
// 選 Node 而非 pwsh 或 Python：clasp v3 本來就要 Node.js 22+，主流程整條靠
// `npx --yes @google/clasp@3`，所以會用到這個技能的人必定已經有 Node，不新增依賴。
//
// 用法：
//   node scripts/install.mjs

import { createHash } from 'node:crypto';
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  realpathSync,
  rmdirSync,
  rmSync,
  statSync,
} from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const SKILL_NAME = 'clasp-setup';
const SKIP_DIRS = new Set([
  '.git',
  'node_modules',
  '.venv',
  'venv',
  'site-packages',
  'generated',
  'dist',
  'build',
  '__pycache__',
]);

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const source = path.resolve(scriptDir, '..', 'skills', SKILL_NAME);

function fail(message) {
  console.error(message);
  process.exit(1);
}

if (process.argv.length > 2) {
  console.error(`不支援的參數：${process.argv[2]}`);
  process.exit(2);
}

if (!existsSync(source) || !statSync(source).isDirectory()) {
  fail(`找不到技能來源資料夾：${source}`);
}

const skillFile = path.join(source, 'SKILL.md');
if (!existsSync(skillFile)) {
  fail(`找不到技能主檔：${skillFile}`);
}

const frontmatterName = (
  readFileSync(skillFile, 'utf8')
    .split(/\r?\n/, 12)
    .find((line) => /^\s*name:/.test(line)) ?? ''
)
  .replace(/^\s*name:\s*/, '')
  .trim()
  .replace(/^["']|["']$/g, '');

if (frontmatterName !== SKILL_NAME) {
  fail(`SKILL.md 的 name 必須是 '${SKILL_NAME}'，目前是 '${frontmatterName}'。`);
}

// 遞迴列出可安裝檔案，回傳以 / 分隔的相對路徑（跨平台一致的 hash map key）。
// symlink 一律視為錯誤而非靜默略過：不同平台的 symlink 複製語意不同，
// 靜默處理正是雙軌時代讓驗證假性通過的破口。
function listFiles(base, relative = '') {
  const results = [];
  for (const entry of readdirSync(path.join(base, relative), { withFileTypes: true })) {
    const childRelative = relative ? `${relative}/${entry.name}` : entry.name;
    if (entry.isSymbolicLink()) {
      fail(`不支援符號連結，請先移除：${path.join(base, childRelative)}`);
    }
    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name)) {
        continue;
      }
      results.push(...listFiles(base, childRelative));
    } else if (entry.isFile()) {
      results.push(childRelative);
    }
  }
  return results;
}

function hashFile(absolute) {
  return createHash('sha256').update(readFileSync(absolute)).digest('hex');
}

function hashMap(base, relatives) {
  const map = new Map();
  for (const relative of relatives) {
    map.set(relative, hashFile(path.join(base, relative)));
  }
  return map;
}

// 由 base 推導安裝目標，並確認它真的位於 base 之下、結尾就是技能名。
// base 先取 realpath，避免 symlink 或 `..` 讓後面的刪檔動作跑到別的地方去。
function resolveTarget(base) {
  const baseFull = realpathSync(path.resolve(base));
  const targetFull = path.resolve(baseFull, SKILL_NAME);
  const prefix = baseFull.endsWith(path.sep) ? baseFull : baseFull + path.sep;
  const insensitive = process.platform === 'win32' || process.platform === 'darwin';
  const inside = insensitive
    ? targetFull.toLowerCase().startsWith(prefix.toLowerCase())
    : targetFull.startsWith(prefix);

  if (!inside || path.basename(targetFull) !== SKILL_NAME) {
    fail(`拒絕操作不安全的安裝目標：${targetFull}`);
  }
  return targetFull;
}

// 移除空目錄（由深至淺），讓來源刪掉整個子資料夾後目標不留空殼。
function pruneEmptyDirs(base, relative = '') {
  const absolute = path.join(base, relative);
  for (const entry of readdirSync(absolute, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      pruneEmptyDirs(base, relative ? `${relative}/${entry.name}` : entry.name);
    }
  }
  if (relative && readdirSync(absolute).length === 0) {
    rmdirSync(absolute);
  }
}

// CLASP_SKILL_HOME 是給 validate 隔離測試用的覆寫接縫，正式安裝不會設定它。
const home = process.env.CLASP_SKILL_HOME || homedir();
if (!home) {
  fail('找不到家目錄，無法決定全域安裝位置。');
}

const destinations = [
  ['Claude Code', path.join(home, '.claude', 'skills')],
  ['Codex', path.join(home, '.agents', 'skills')],
  ['OpenCode', path.join(home, '.config', 'opencode', 'skills')],
  ['Antigravity', path.join(home, '.gemini', 'config', 'skills')],
];

const sourceRelatives = listFiles(source);
if (sourceRelatives.length === 0) {
  fail(`技能來源沒有任何可安裝檔案：${source}`);
}
const sourceMap = hashMap(source, sourceRelatives);
const sourceSet = new Set(sourceRelatives);

let installed = 0;
for (const [label, base] of destinations) {
  if (!existsSync(base) || !statSync(base).isDirectory()) {
    console.log(`[SKIP] ${label}：目錄不存在（這台可能未安裝該工具）`);
    continue;
  }

  const target = resolveTarget(base);

  // 就地覆蓋而非 rm -rf 整包重建：不炸掉使用者放在該目錄的東西，
  // 也不會在複製中途留下沒有技能的空窗。
  mkdirSync(target, { recursive: true });
  for (const relative of sourceRelatives) {
    const targetFile = path.join(target, relative);
    mkdirSync(path.dirname(targetFile), { recursive: true });
    copyFileSync(path.join(source, relative), targetFile);
  }

  for (const relative of listFiles(target)) {
    if (!sourceSet.has(relative)) {
      rmSync(path.join(target, relative), { force: true });
    }
  }
  pruneEmptyDirs(target);

  const targetRelatives = listFiles(target);
  const targetMap = hashMap(target, targetRelatives);
  const bad = sourceRelatives.filter((relative) => targetMap.get(relative) !== sourceMap.get(relative));
  const extra = targetRelatives.filter((relative) => !sourceSet.has(relative));

  if (bad.length > 0 || extra.length > 0) {
    fail(`${label} 安裝驗證失敗：內容差異=[${bad.join(', ')}]，多出檔案=[${extra.join(', ')}]`);
  }

  installed += 1;
  console.log(`[OK] ${label}：${target}（${sourceRelatives.length} 檔，SHA-256 一致）`);
}

if (installed === 0) {
  fail('沒有可用的安裝目標。全域模式只安裝到已存在的 Agent 技能目錄。');
}

console.log('');
console.log('安裝完成。若技能未立即出現，請重開 agent 或開新對話。');
