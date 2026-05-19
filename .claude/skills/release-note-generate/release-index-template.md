# リリース一覧 HTML テンプレート

`release-note-generate` スキルが生成する各リリースHTMLへのリンク一覧（`<リポジトリ名>-release-index.html`）に使うテンプレート。
本ファイルの「テンプレート本体」セクションのHTMLをコピーし、プレースホルダーを実値に置換して出力する。

---

## プレースホルダー一覧

| プレースホルダー | 用途 | 例 |
|---|---|---|
| `{{REPO_NAME}}` | リポジトリ名（owner/repo の `/` 以降） | `def` |
| `{{REPO_FULL_NAME}}` | `owner/repo` 形式のフルネーム | `abc/def` |
| `{{REPO_URL}}` | リポジトリの GitHub URL | `https://github.com/abc/def` |
| `{{GENERATED_AT}}` | この index を生成した日時（JST、`YYYY-MM-DD HH:MM JST`） | `2026-05-19 10:30 JST` |
| `{{RELEASE_COUNT}}` | `releases/` 配下のリリースHTMLの総数 | `42` |
| `{{RELEASE_ROWS}}` | 各リリース1行ぶんの `<tr>` を改行で連結 | 後述のループで生成 |

### 各リリース行（`{{RELEASE_ROWS}}` の各要素）

```html
<tr class="release-row {{ROW_CLASS}}">
  <td class="col-status"><span class="status-badge {{STATUS_CLASS}}">{{STATUS_LABEL}}</span></td>
  <td class="col-pr"><a class="release-link" href="{{RELEASE_HREF}}">#{{PR_NUMBER}}</a></td>
  <td class="col-title">{{RELEASE_TITLE}}</td>
  <td class="col-date">{{MERGED_AT_JST}}</td>
</tr>
```

各セルの値:

- `{{ROW_CLASS}}`: `merged`（last モード由来＝マージ済み）または `progress`（progress モード由来＝進行中）
- `{{STATUS_CLASS}}` / `{{STATUS_LABEL}}`:
  - マージ済み: `merged` / `マージ済み`
  - 進行中: `progress` / `進行中`
- `{{RELEASE_HREF}}`: そのリリースHTMLへの相対パス（`./releases/<ファイル名>`）
- `{{PR_NUMBER}}`: リリースPRの番号（数値のみ）
- `{{RELEASE_TITLE}}`: そのリリースHTMLの `<title>` から取り出したタイトル（HTMLエスケープ）。`<title>` 例:
  - last: `リリース内容（#19053 2026-04-26 09:56 JST）`
  - progress: `リリース予定内容（#19053）`
- `{{MERGED_AT_JST}}`:
  - マージ済み: `YYYY-MM-DD HH:MM JST` 形式（last モードのファイル名 `...-YYYYMMDD-HHMM.html` から復元、または `<title>` から抽出）
  - 進行中: `—`（emダッシュ）

---

## ソートルール

- 進行中（`progress` 由来）の行を先頭にまとめる。複数あれば PR 番号の降順。
- 続いてマージ済み（`last` 由来）の行を **マージ日時の降順**（新しいリリースが上）。同じ分のマージは PR 番号の降順。

---

## ファイル名からの情報抽出

`releases/` 配下のHTMLは以下のいずれかの命名規則になっている:

- `<REPO_NAME>-release-<PR番号>-<YYYYMMDD>-<HHMM>.html` → マージ済み（last 由来）
- `<REPO_NAME>-release-<PR番号>.html` → 進行中（progress 由来）

正規表現で分類する:

```bash
# 例: ls -1 releases/*.html
# def-release-19053-20260426-0956.html  ← マージ済み
# def-release-19120.html                ← 進行中
```

それぞれのファイルから:

1. PR番号: ファイル名の `release-<N>` 部分
2. 日時（マージ済みのみ）: `release-<N>-<YYYYMMDD>-<HHMM>.html` から `<YYYYMMDD>-<HHMM>` を取り出し、`YYYY-MM-DD HH:MM JST` に整形
3. タイトル: ファイル本体の `<title>...</title>` を読み取り、HTML エンティティをデコードしない素のままで使用（テンプレート埋め込み時に HTML エスケープ済みであることを前提）

`<title>` を取り出す参考:

```bash
grep -oE '<title>[^<]*</title>' releases/<ファイル名>.html \
  | sed -E 's|</?title>||g'
```

---

## HTMLエスケープ

`{{RELEASE_TITLE}}` には `<` `>` `&` `"` `'` をエスケープした文字列を入れる。`<title>` から取り出した文字列がすでにエスケープ済みであればそのまま使ってよい。

---

## テンプレート本体

以下をそのままコピーし、プレースホルダーを実値に置換して出力する。

```html
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<title>{{REPO_NAME}} リリース一覧</title>
<style>
  :root {
    --bg: #ffffff;
    --fg: #1f2328;
    --muted: #57606a;
    --accent: #0969da;
    --accent-bg: #ddf4ff;
    --border: #d0d7de;
    --code-bg: #f6f8fa;
    --merged: #1a7f37;
    --merged-bg: #dafbe1;
    --progress: #9a6700;
    --progress-bg: #fff8c5;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #0d1117;
      --fg: #c9d1d9;
      --muted: #7d8590;
      --accent: #58a6ff;
      --accent-bg: #0d2a4a;
      --border: #30363d;
      --code-bg: #161b22;
      --merged: #56d364;
      --merged-bg: #0f2417;
      --progress: #e3b341;
      --progress-bg: #271d08;
    }
  }
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Hiragino Kaku Gothic ProN", "Yu Gothic", sans-serif;
    background: var(--bg);
    color: var(--fg);
    line-height: 1.7;
    margin: 0;
    padding: 0;
  }
  .container {
    max-width: 980px;
    margin: 0 auto;
    padding: 32px 24px 80px;
  }
  header {
    border-bottom: 2px solid var(--border);
    padding-bottom: 16px;
    margin-bottom: 32px;
  }
  header h1 {
    font-size: 28px;
    margin: 0 0 8px 0;
    line-height: 1.3;
  }
  header h1 a {
    color: var(--fg);
    text-decoration: none;
  }
  header h1 a:hover { text-decoration: underline; }
  header .meta {
    color: var(--muted);
    font-size: 14px;
  }
  table.release-list {
    width: 100%;
    border-collapse: collapse;
    font-size: 14px;
  }
  table.release-list th,
  table.release-list td {
    text-align: left;
    padding: 10px 12px;
    border-bottom: 1px solid var(--border);
    vertical-align: top;
  }
  table.release-list thead th {
    font-size: 12px;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: var(--muted);
    background: var(--code-bg);
  }
  table.release-list .col-status { width: 110px; }
  table.release-list .col-pr { width: 110px; white-space: nowrap; }
  table.release-list .col-date { width: 180px; white-space: nowrap; color: var(--muted); font-variant-numeric: tabular-nums; }
  table.release-list .col-title { word-break: break-word; }
  table.release-list tr.release-row.progress {
    background: var(--progress-bg);
  }
  table.release-list a.release-link {
    color: var(--accent);
    text-decoration: none;
    font-family: ui-monospace, SFMono-Regular, "SF Mono", Consolas, monospace;
    font-weight: 600;
    background: var(--accent-bg);
    padding: 1px 8px;
    border-radius: 12px;
    font-size: 13px;
  }
  table.release-list a.release-link:hover { text-decoration: underline; }
  .status-badge {
    display: inline-block;
    font-size: 11px;
    font-weight: 600;
    padding: 2px 8px;
    border-radius: 10px;
    line-height: 1.6;
  }
  .status-badge.merged { color: var(--merged); background: var(--merged-bg); }
  .status-badge.progress { color: var(--progress); background: var(--progress-bg); }
  .empty {
    color: var(--muted);
    padding: 24px 0;
    text-align: center;
    font-style: italic;
  }
</style>
</head>
<body>
<div class="container">

<header>
  <h1><a href="{{REPO_URL}}" target="_blank" rel="noopener">{{REPO_FULL_NAME}}</a> リリース一覧</h1>
  <div class="meta">
    全 {{RELEASE_COUNT}} 件 ／ 生成日時: {{GENERATED_AT}}
  </div>
</header>

<table class="release-list">
  <thead>
    <tr>
      <th class="col-status">状態</th>
      <th class="col-pr">PR</th>
      <th class="col-title">タイトル</th>
      <th class="col-date">マージ日時</th>
    </tr>
  </thead>
  <tbody>
{{RELEASE_ROWS}}
  </tbody>
</table>

</div>
</body>
</html>
```

---

## 出力時の注意

- `{{RELEASE_ROWS}}` が0件の場合は、`<tbody>` の中身を `<tr><td colspan="4" class="empty">リリースHTMLがまだありません</td></tr>` にする。
- 既存のリリースHTML（`releases/` 配下）のうち、命名規則に一致しないファイルは無視する。
- 並び順は「ソートルール」セクションを厳守する。
