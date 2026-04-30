# リリースノート HTML テンプレート

`release-note-show` スキルでHTML出力（例: `release.html`）を求められた場合に使用するテンプレート。
本ファイルの「テンプレート本体」セクションに記載されたHTMLをコピーし、プレースホルダーを実値に置換して出力する。

---

## プレースホルダー一覧

| プレースホルダー | 用途 | last モード | progress モード |
|---|---|---|---|
| `{{HEADING_TITLE}}` | `<h1>` のテキスト | `リリース内容` | `リリース予定内容` |
| `{{TITLE}}` | `<title>` のテキスト | `リリース内容（#19053 2026-04-26 09:56 JST）` | `リリース予定内容（#19053）` |
| `{{RELEASE_PR_NUMBER}}` | リリースPR番号（数値のみ） | 例: `19053` | 例: `19053` |
| `{{RELEASE_PR_URL}}` | リリースPRの GitHub URL | 例: `https://github.com/owner/repo/pull/19053` | 同左 |
| `{{MERGED_AT_LINE}}` | ヘッダのマージ日時行（前後区切り含む） | `／ マージ日時: 2026-04-26 09:56 JST` | （空文字） |
| `{{PR_COUNT}}` | 機能PRの件数 | 例: `24` | 例: `24` |
| `{{TOC_ITEMS}}` | 「PR一覧」のリストアイテム | 後述のループで生成 | 同左 |
| `{{SUMMARY_FEATURE}}` | 機能ブロックの中身（`<ul><li>...</li></ul>` または `<p>特になし</p>`） | | |
| `{{SUMMARY_GRAPHQL}}` | GraphQLスキーマブロックの中身 | | |
| `{{SUMMARY_SCHEMA}}` | DBスキーマブロックの中身 | | |
| `{{SUMMARY_INFRA}}` | インフラブロックの中身 | | |
| `{{PR_ARTICLES}}` | PR詳細セクションの全 `<article>` を連結したHTML | | |

### 各PRごとに展開する変数

`{{TOC_ITEMS}}` および `{{PR_ARTICLES}}` 内では、機能PRごとに以下を埋める。

| 変数 | 用途 | 例 |
|---|---|---|
| `{{PR_INDEX}}` | 1始まりの通番 | `1` |
| `{{PR_NUMBER}}` | GitHub PR番号 | `18524` |
| `{{PR_URL}}` | GitHub PRのURL | `https://github.com/owner/repo/pull/18524` |
| `{{PR_TITLE}}` | PRタイトル（HTMLエスケープ） | `OmnibusCore PLU連携 syncExecute向けのnew関数を実装する(2/)` |
| `{{PR_BADGES}}` | カテゴリバッジHTML（後述） | 例: `<span class="badge feature">機能</span>` |
| `{{PR_DESCRIPTION}}` | PR詳細の概要本文（HTML） | 2〜4文の段落 |

### バッジHTML

PRが該当するカテゴリ（機能 / GraphQLスキーマ / DBスキーマ / インフラ）すべてを含める。複数該当する場合は連結する。

```html
<span class="badge feature">機能</span>
<span class="badge graphql">GraphQLスキーマ</span>
<span class="badge schema">DBスキーマ</span>
<span class="badge infra">インフラ</span>
```

### TOC アイテム（`{{TOC_ITEMS}}` の各行）

```html
<li><span class="num">{{PR_INDEX}}.</span><a href="#pr-{{PR_NUMBER}}">#{{PR_NUMBER}} {{PR_TITLE}}</a></li>
```

### PR Article（`{{PR_ARTICLES}}` の各要素）

```html
<article class="pr" id="pr-{{PR_NUMBER}}">
  <h3><span class="index">{{PR_INDEX}}.</span><span class="pr-num"><a href="{{PR_URL}}" target="_blank" rel="noopener">#{{PR_NUMBER}}</a></span><span class="pr-title">{{PR_TITLE}}</span></h3>
  <div class="badges">{{PR_BADGES}}</div>
  <p>{{PR_DESCRIPTION}}</p>
</article>
```

---

## モード別の差し替えルール

- **last モード**:
  - `{{HEADING_TITLE}}` → `リリース内容`
  - `{{TITLE}}` → `リリース内容（#{{RELEASE_PR_NUMBER}} {{MERGED_AT_JST}}）` の形式（`{{MERGED_AT_JST}}` 例: `2026-04-26 09:56 JST`）
  - `{{MERGED_AT_LINE}}` → `／ マージ日時: {{MERGED_AT_JST}}`
- **progress モード**:
  - `{{HEADING_TITLE}}` → `リリース予定内容`
  - `{{TITLE}}` → `リリース予定内容（#{{RELEASE_PR_NUMBER}}）`
  - `{{MERGED_AT_LINE}}` → 空文字（区切りの `／` 含めて出さない）

---

## HTMLエスケープ

PRタイトルや概要本文に `<` `>` `&` `"` `'` が含まれる場合は HTML エスケープすること。バッククォート `` ` `` で囲まれた識別子は `<code>` タグに変換するとよい。

---

## テンプレート本体

以下をそのままコピーし、上記プレースホルダーを実値に置換して出力する。

```html
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<title>{{TITLE}}</title>
<style>
  :root {
    --bg: #ffffff;
    --fg: #1f2328;
    --muted: #57606a;
    --accent: #0969da;
    --accent-bg: #ddf4ff;
    --border: #d0d7de;
    --code-bg: #f6f8fa;
    --feature: #1a7f37;
    --graphql: #b41e8b;
    --schema: #9a6700;
    --infra: #8250df;
    --feature-bg: #dafbe1;
    --graphql-bg: #fde0f3;
    --schema-bg: #fff8c5;
    --infra-bg: #fbefff;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #0d1117;
      --fg: #e6edf3;
      --muted: #8b949e;
      --accent: #58a6ff;
      --accent-bg: #0d2a4a;
      --border: #30363d;
      --code-bg: #161b22;
      --feature: #56d364;
      --graphql: #ff7eb8;
      --schema: #e3b341;
      --infra: #d2a8ff;
      --feature-bg: #0f2417;
      --graphql-bg: #2d1029;
      --schema-bg: #271d08;
      --infra-bg: #21163a;
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
  header .meta {
    color: var(--muted);
    font-size: 14px;
  }
  header .meta a {
    color: var(--accent);
    text-decoration: none;
  }
  header .meta a:hover { text-decoration: underline; }

  nav.toc {
    background: var(--code-bg);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 16px 20px;
    margin-bottom: 32px;
  }
  nav.toc h2 {
    margin: 0 0 8px 0;
    font-size: 14px;
    color: var(--muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }
  nav.toc ul {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  nav.toc li {
    margin: 4px 0;
    font-size: 13px;
    break-inside: avoid;
  }
  nav.toc a {
    color: var(--accent);
    text-decoration: none;
  }
  nav.toc a:hover { text-decoration: underline; }
  nav.toc .num {
    color: var(--muted);
    margin-right: 6px;
    font-variant-numeric: tabular-nums;
  }

  section.summary {
    margin-bottom: 40px;
  }
  section.summary h2 {
    font-size: 22px;
    margin: 0 0 16px 0;
    padding-bottom: 6px;
    border-bottom: 1px solid var(--border);
  }
  .summary-block {
    border-left: 4px solid var(--border);
    padding: 8px 16px;
    margin: 12px 0;
    border-radius: 0 6px 6px 0;
  }
  .summary-block.feature { border-color: var(--feature); background: var(--feature-bg); }
  .summary-block.graphql { border-color: var(--graphql); background: var(--graphql-bg); }
  .summary-block.schema { border-color: var(--schema); background: var(--schema-bg); }
  .summary-block.infra { border-color: var(--infra); background: var(--infra-bg); }
  .summary-block h3 {
    margin: 0 0 8px 0;
    font-size: 16px;
  }
  .summary-block.feature h3 { color: var(--feature); }
  .summary-block.graphql h3 { color: var(--graphql); }
  .summary-block.schema h3 { color: var(--schema); }
  .summary-block.infra h3 { color: var(--infra); }
  .summary-block ul {
    margin: 8px 0;
    padding-left: 20px;
  }
  .summary-block li {
    margin: 4px 0;
  }

  section.prs h2 {
    font-size: 22px;
    margin: 0 0 16px 0;
    padding-bottom: 6px;
    border-bottom: 1px solid var(--border);
  }
  article.pr {
    border: 1px solid var(--border);
    border-radius: 6px;
    margin-bottom: 16px;
    padding: 16px 20px;
    background: var(--bg);
  }
  article.pr h3 {
    margin: 0 0 8px 0;
    font-size: 16px;
    line-height: 1.4;
    display: flex;
    align-items: baseline;
    gap: 8px;
    flex-wrap: wrap;
  }
  article.pr .index {
    color: var(--muted);
    font-weight: 400;
    font-variant-numeric: tabular-nums;
    min-width: 28px;
  }
  article.pr .pr-num a {
    color: var(--accent);
    text-decoration: none;
    font-family: ui-monospace, SFMono-Regular, "SF Mono", Consolas, monospace;
    font-weight: 600;
    background: var(--accent-bg);
    padding: 1px 8px;
    border-radius: 12px;
    font-size: 13px;
  }
  article.pr .pr-num a:hover { text-decoration: underline; }
  article.pr .pr-title {
    font-weight: 600;
  }
  article.pr .badges {
    margin-bottom: 8px;
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
  }
  .badge {
    display: inline-block;
    font-size: 11px;
    font-weight: 600;
    padding: 2px 8px;
    border-radius: 10px;
    line-height: 1.6;
  }
  .badge.feature { color: var(--feature); background: var(--feature-bg); }
  .badge.graphql { color: var(--graphql); background: var(--graphql-bg); }
  .badge.schema { color: var(--schema); background: var(--schema-bg); }
  .badge.infra { color: var(--infra); background: var(--infra-bg); }
  article.pr p {
    margin: 8px 0 0 0;
    color: var(--fg);
  }

  code {
    font-family: ui-monospace, SFMono-Regular, "SF Mono", Consolas, monospace;
    background: var(--code-bg);
    padding: 1px 6px;
    border-radius: 4px;
    font-size: 0.9em;
    border: 1px solid var(--border);
  }
  .summary-block code,
  article.pr code {
    border-color: transparent;
  }
</style>
</head>
<body>
<div class="container">

<header>
  <h1>{{HEADING_TITLE}}</h1>
  <div class="meta">
    リリースPR: <a href="{{RELEASE_PR_URL}}" target="_blank" rel="noopener">#{{RELEASE_PR_NUMBER}}</a>
    {{MERGED_AT_LINE}}
    ／ 機能PR: {{PR_COUNT}}件
  </div>
</header>

<nav class="toc">
  <h2>PR一覧</h2>
  <ul>
{{TOC_ITEMS}}
  </ul>
</nav>

<section class="summary">
  <h2>概要</h2>

  <div class="summary-block feature">
    <h3>機能に関する変更</h3>
    {{SUMMARY_FEATURE}}
  </div>

  <div class="summary-block graphql">
    <h3>GraphQLスキーマに関する変更</h3>
    {{SUMMARY_GRAPHQL}}
  </div>

  <div class="summary-block schema">
    <h3>DBスキーマに関する変更</h3>
    {{SUMMARY_SCHEMA}}
  </div>

  <div class="summary-block infra">
    <h3>インフラに関する変更</h3>
    {{SUMMARY_INFRA}}
  </div>
</section>

<section class="prs">
  <h2>PR詳細</h2>

{{PR_ARTICLES}}

</section>

</div>
</body>
</html>
```

---

## 出力時の注意

- 出力先のファイルパスはユーザーの指定に従う（指定がなければカレントディレクトリの `release.html`）。
- 概要・PR詳細の文章は SKILL.md の本来の出力フォーマット（チャット表示用）と同じ内容で問題ない。HTML 化する際にコードフェンスや見出し記号を取り除き、識別子は `<code>` で囲むこと。
- カテゴリに該当する変更が無い場合は対応する `{{SUMMARY_*}}` を `<p>特になし</p>` にする。セクション自体は省略しない。
- progress モードでは `{{MERGED_AT_LINE}}` を空文字にすること。残った `／ 機能PR: ...` の前の区切りも見栄えのため出さないなら `／ 機能PR:` を直接 `機能PR:` に変えてもよい。
