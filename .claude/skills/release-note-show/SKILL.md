---
name: release-note-show
description: >
  リポジトリのリリース内容を要約して表示するスキル。
  「最新リリースの内容を教えて」「リリースノートを出して」「直近のリリースに何が入った？」
  「release-note-show」「リリース内容を要約して」「最近何がリリースされた？」
  「次のリリースに何が入る？」「今進んでるリリースは？」「リリース予定の内容を教えて」
  「progress」「last」といった依頼のときに使用する。
  releaseブランチへのマージ済み最新リリース（last）と、releaseをbaseとするOpen PR（progress, 次のリリース予定）の
  2モードに対応する。デフォルトは last。指定されたPRの含まれる機能PR一覧と変更内容を抽出し、
  機能・GraphQLスキーマ・DBスキーマ・インフラに分類して規定フォーマットで要約する。
  リリース内容確認、リリースノート生成、直近リリース・次回リリース予定の要約依頼があれば積極的に使うこと。
---

# リリース内容表示スキル

リポジトリのリリース内容を要約し、HTMLにレンダリングして **Claude Code を起動したディレクトリ直下** に書き出す。ファイル名はモードによって異なる:

- `last` モード: `./<リポジトリ名>-release-<リリースPR番号>-<YYYYMMDD-hhmm形式のマージ日時(JST)>.html`（例: `./def-release-1234-20240426-1030.html`。リポジトリが `abc/def` なら `def`）
- `progress` モード: `./<リポジトリ名>-release-<リリースPR番号>.html`（例: `./def-release-1234.html`。マージ前のため日時は付けない）

書き出し後、`cmux browser open "file://$(pwd)/<書き出したファイル名>"` を実行してブラウザペインで表示する。

HTMLテンプレートはスキル同梱の `release-template.md` を使う（プレースホルダー仕様はそのファイル内に記載）。

## 2つのモード

| モード | 対象 | タイトル |
|---|---|---|
| `last` (デフォルト) | release ブランチに **マージ済み** の最新リリース PR | `# リリース内容（…）` |
| `progress` | base が release で **Open** のリリース PR（次のリリース予定） | `# リリース予定内容（…）` |

「リリース」とは、release ブランチへのマージコミット1つに対応する単位。

---

## Step 1: モードを判定する

ユーザーの入力からモードを決める。判定ルール:

- 入力に `progress` / `進行中` / `これからリリース` / `次のリリース` / `リリース予定` / `Open` などが含まれる → **progress**
- それ以外、または明示なし → **last**（デフォルト）

ユーザーがあいまいに「リリースの内容を教えて」と言った場合は last。`last` か `progress` か判断に迷ったら last で進めて、出力後にどちらだったかを伝える。

---

## 共通の前提

- `git` および `gh` (GitHub CLI) が利用できること
- リポジトリは GitHub でホストされていること
- 機能PRは release ブランチに直接マージされるか、release に取り込まれる別ブランチ（dev/main など）にマージされてから一括で release へ取り込まれること

ベースブランチ名やリリース運用はリポジトリごとに違う。コマンドの出力を見て判断すること。先に正解を決めつけない。

---

# 【last モード】既にマージ済みのリリースを表示する

## L-Step 1: 最新の release 系ブランチを特定する

リモートを最新化したうえで、`release` で始まるブランチのうち、最新コミット日時のものを選ぶ。

```bash
git fetch --all --prune

# git for-each-ref のパターンは prefix match なので、'release' で
# 'release', 'release/foo', 'release-foo' すべてにマッチする
git for-each-ref \
  --sort=-committerdate \
  --format='%(committerdate:iso-strict) %(refname:short)' \
  'refs/remotes/origin/release'
```

出力の先頭が「最新のreleaseブランチ」。1件もなければユーザーに対象ブランチ名を確認する。
特定したブランチ名を `<RELEASE_BRANCH>` と表記する（例: `origin/release`）。

注意:
- `release` 系ブランチが複数ある運用（`release/2024-04-26` など日付別）と、単一の `release` ブランチを使い続ける運用、両方が存在する。
- ローカルにしか release が無い場合は `refs/heads/release` を対象にして再検索する。

## L-Step 2: 最新のリリースマージコミットを特定する

`<RELEASE_BRANCH>` の **first-parent** を辿った最新のマージコミットを取得する。これが「リリースPRがマージされたコミット」に当たる。

```bash
git log <RELEASE_BRANCH> --first-parent --merges -1 \
  --format='%H%x09%P%x09%cI%x09%s'
```

出力フィールド:
- `%H`: マージコミットSHA → `<MERGE_SHA>`
- `%P`: 親コミットSHA → 最初を `<P1>`、2番目を `<P2>`
- `%cI`: コミット日時（ISO 8601、オフセット付き）
- `%s`: コミット件名

`--merges` で何も出ない場合はリリースPRが Squash merge されている運用。その場合は `--merges` を外して `--first-parent -1` で取り直し、L-Step 4 後半の Squash merge ロジックに切り替える。

## L-Step 3: リリースPRの番号とマージ日時を取得する

`<MERGE_SHA>` に紐づくPR番号を GitHub API から逆引きする:

```bash
gh api "repos/{owner}/{repo}/commits/<MERGE_SHA>/pulls" \
  --jq '.[] | {number, title, mergedAt: .merged_at, baseRef: .base.ref}'
```

`baseRef` が `<RELEASE_BRANCH>` の短縮ブランチ名と一致するPRが「リリースPR」。複数候補があれば `mergedAt` が最新のものを採用する。

これを `<RELEASE_PR_NUMBER>`、`<MERGED_AT>` (UTC ISO 8601、末尾 `Z`) として保持する。

JST 変換は「共通: 日時の JST 変換」を参照。

## L-Step 4: リリースに含まれる機能PR一覧を取得する

### 通常マージ運用の場合

`<P1>..<P2>` の範囲のコミットメッセージから `#N` を抽出する:

```bash
git log --format='%H%x09%s%n%b' <P1>..<P2> \
  | grep -oE '#[0-9]+' \
  | sort -u
```

得られた番号から `<RELEASE_PR_NUMBER>` を除外したものが機能PR一覧。

### Squash merge運用の場合

`<P1>..<MERGE_SHA>` ではPRがリリースPR1件しか出ない。リリースPRに含まれるコミットから抽出する:

```bash
gh pr view <RELEASE_PR_NUMBER> --json title,body,commits \
  --jq '.commits[].messageHeadline' \
  | grep -oE '#[0-9]+' \
  | sort -u
```

抽出失敗時はリリースPRの本文（`gh pr view --json body`）に手動で書かれたPRリストを確認する。それでも見つからなければユーザーに確認する。憶測で埋めない。

→ 出力タイトルには `<RELEASE_PR_NUMBER>` と `<MERGED_AT>` (JST変換後) を使う。次節「共通: 各機能PRを取得して分類」へ進む。

---

# 【progress モード】Open のリリース予定 PR を表示する

## P-Step 1: Open のリリースPRを取得する

base ブランチが `release` 系で Open の PR を探す:

```bash
# まず base が "release" のものを取る（運用が単一ブランチの場合）
gh pr list --state open --base release \
  --json number,title,body,updatedAt,headRefName,baseRefName

# 上記が空なら、release で始まる base 全般を対象にする
gh pr list --state open \
  --json number,title,body,updatedAt,headRefName,baseRefName \
  --jq '[.[] | select(.baseRefName | startswith("release"))]'
```

該当PRが0件なら「進行中のリリースPRはありません」とユーザーに伝えて終了する。
複数件あれば `updatedAt` 降順で先頭を採用し、その旨をユーザーに伝える（`updatedAt` は表示には使わず、選択にのみ使う）。

採用したPR番号を `<PROGRESS_PR_NUMBER>` として保持する。

## P-Step 2: progress PR に含まれる機能PR一覧を取得する

```bash
# PR のコミット一覧から #N を抽出
gh pr view <PROGRESS_PR_NUMBER> --json commits \
  --jq '.commits[].messageHeadline + " " + (.commits[].messageBody // "")' \
  | grep -oE '#[0-9]+' \
  | sort -u
```

`<PROGRESS_PR_NUMBER>` 自身が含まれる場合は除外する。0件ならPR本文を確認:

```bash
gh pr view <PROGRESS_PR_NUMBER> --json body --jq '.body' \
  | grep -oE '#[0-9]+' \
  | sort -u
```

それでも0件ならユーザーに確認する。

→ 出力タイトルには `<PROGRESS_PR_NUMBER>` のみを使う（progress モードは日時を出さない）。次節「共通: 各機能PRを取得して分類」へ進む。

---

# 共通: 各機能PRを取得して分類する

## C-Step 1: 各機能PRの内容を取得する

機能PR番号一覧の各番号 `<N>` について:

```bash
gh pr view <N> --json number,title,body,mergedAt,author,labels,baseRefName,headRefName
gh pr diff <N> --name-only
# 必要に応じて
gh pr diff <N>
```

GraphQLスキーマ または DBスキーマ に該当するPRについては、`gh pr diff <N>` の出力から該当ファイルの diff ブロック（`diff --git a/<path> b/<path>` から次の `diff --git` 直前まで）を切り出して保持する。これは O-Step 1 で `{{SUMMARY_GRAPHQL}}` / `{{SUMMARY_SCHEMA}}` の中に埋め込むのに使う。`gh pr diff` 自体は pathspec フィルタを持たないので、出力をパースして対象パスのブロックを抽出する。

## C-Step 2: 変更を4カテゴリに分類する

各PRが「機能」「GraphQLスキーマ」「DBスキーマ」「インフラ」のどれに該当するかを変更ファイルのパスと内容から判定する。1つのPRが複数該当することもある。

### GraphQLスキーマに関する変更

ファイルパスのヒューリスティック（マッチしたら候補）:

- `**/*.graphql`, `**/*.graphqls`, `**/*.gql`
- `**/schema.graphql`, `**/schema.graphqls`
- `**/graphql/**` 配下のスキーマ定義ファイル
- コード内のスキーマDSL（gqlgenの `schema.go`、graphql-ruby の type 定義、Apollo の `gql` テンプレートリテラル等）でスキーマ構造が変わるもの

判定の基準:
- `type` / `input` / `enum` / `interface` / `union` / `scalar` の追加・変更・削除があれば該当
- フィールドの追加・削除・型変更、引数の変更、`@directive` の追加・変更も該当
- リゾルバ実装のみの変更（スキーマSDL不変）は該当しない

### DBスキーマに関する変更

ファイルパスのヒューリスティック（マッチしたら候補）:

- `**/migrations/**`, `**/migration/**`
- `*.sql`
- `**/schema.rb`, `**/schema.prisma`, `**/structure.sql`
- `**/db/**` 配下の定義ファイル
- ORM のスキーマ定義ファイル（`**/models/**` のうちカラム定義が変わっているもの）

判定の基準:
- テーブル/カラム/インデックス/制約の追加・変更・削除があれば該当
- マイグレーションファイルの追加は基本的に該当
- ORM モデルでも、カラム追加やリレーション変更など物理スキーマに影響するものは該当

### インフラに関する変更

- `**/*.tf`, `**/*.tfvars`, `**/terraform/**`
- `**/Dockerfile*`, `**/docker-compose*.yml`
- `**/k8s/**`, `**/kubernetes/**`, `**/helm/**`, `**/*.yaml`（マニフェスト）
- `.github/workflows/**`, `.gitlab-ci.yml`, `.circleci/**`
- `**/cloudbuild.yaml`, `**/serverless.yml`, `**/cdk/**`, `**/pulumi/**`
- `**/nginx/**`, `**/Caddyfile`
- ランタイム/依存バージョン: `Dockerfile` のベースイメージ、`go.mod` の Go バージョン、`package.json` の `engines`、`.tool-versions`、`.nvmrc`

### 機能に関する変更

上記3カテゴリに該当しない、アプリケーション挙動の変更すべて。

### 注意

- パスマッチは候補を絞り込むためのヒント。最終判断はファイルの中身を見て行うこと。たとえば `*.yaml` でも「OpenAPIスキーマ定義」なら機能、「k8sマニフェスト」ならインフラ。
- 1つのPRが複数カテゴリに該当する場合、それぞれのセクションで言及してよい。
- カテゴリに該当する変更が1件もなければ、そのセクションは「特になし」と書く（セクション自体は省略しない）。

---

# 共通: 日時の JST 変換（last モードのみ使用）

`<MERGED_AT>` は GitHub API から取得した `2024-04-26T01:30:00Z` 形式（末尾 `Z` のUTC）。

macOS（BSD date）:
```bash
TZ='Asia/Tokyo' date -j -u -f '%Y-%m-%dT%H:%M:%SZ' '<utc-iso>' '+%Y-%m-%d %H:%M JST'
```

Linux（GNU date）:
```bash
TZ='Asia/Tokyo' date -d '<utc-iso>' '+%Y-%m-%d %H:%M JST'
```

`git log --format='%cI'` を使う場合は `+09:00` のようなオフセット付きISO 8601になるため、BSDのフォーマット指定は `'%Y-%m-%dT%H:%M:%S%z'` にする。

---

# 出力する

## O-Step 1: HTML をレンダリングする

スキル同梱の `release-template.md`（このスキルディレクトリ直下）を読み込み、テンプレート本体のHTMLを取り出す。プレースホルダー仕様もこのファイルに記載されている。

埋め込む値は以下の対応で組み立てる:

- `{{HEADING_TITLE}}` / `{{TITLE}}`: モードに応じて切り替え
  - last: `リリース内容` / `リリース内容（#{番号} {マージ日時 YYYY-MM-DD HH:MM JST}）`
  - progress: `リリース予定内容` / `リリース予定内容（#{番号}）`
- `{{RELEASE_PR_NUMBER}}` / `{{RELEASE_PR_URL}}`: 取得済みのリリースPR番号と GitHub URL（`https://github.com/<owner>/<repo>/pull/<N>`）。owner/repo は `gh repo view --json nameWithOwner --jq .nameWithOwner` で取得する。
- `{{MERGED_AT_LINE}}`:
  - last: `／ マージ日時: YYYY-MM-DD HH:MM JST`
  - progress: 空文字
- `{{PR_COUNT}}`: 機能PRの件数
- `{{TOC_ITEMS}}`: 機能PRごとに以下を生成し改行で連結
  ```html
  <li><span class="num">{{PR_INDEX}}.</span><a href="#pr-{{PR_NUMBER}}">#{{PR_NUMBER}} {{PR_TITLE}}</a></li>
  ```
- `{{SUMMARY_FEATURE}}` / `{{SUMMARY_GRAPHQL}}` / `{{SUMMARY_SCHEMA}}` / `{{SUMMARY_INFRA}}`: 各カテゴリの要約を `<ul><li>...</li></ul>` で記述。該当なしは `<p>特になし</p>`。識別子は `<code>...</code>` で囲む。本文中に `#1234` のようなPR番号表記を含める場合は、必ず `<a class="pr-ref" href="https://github.com/{owner}/{repo}/pull/{N}" target="_blank" rel="noopener">#{N}</a>` の形式でリンク化する（同じ番号が複数回出ても全箇所リンク化する）。
  - `{{SUMMARY_GRAPHQL}}` と `{{SUMMARY_SCHEMA}}` は、**変更内容ごとに対応する diff を直後に並べる**。各 `<li>`（変更内容1件）の中に「要約テキスト + 紐づく `<details class="schema-diff">`」を入れ、変更内容1→そのdiff、変更内容2→そのdiff、…の順で配置する。要約とdiffを別の節に分けない。HTML仕様は `release-template.md` の「スキーマ diff の埋め込み」セクション参照。
  - `{{SUMMARY_GRAPHQL}}` は GraphQL スキーマ系ファイル、`{{SUMMARY_SCHEMA}}` は DB スキーマ系ファイルのみを対象にし、混ぜない。`{{SUMMARY_FEATURE}}` と `{{SUMMARY_INFRA}}` には diff を埋め込まない。
  - 1つの変更内容に複数ファイルのdiffが紐づく場合は同じ `<li>` 内に `<details>` を複数並べる。1つのPRが独立した複数の変更内容を持つ場合はPRを複数 `<li>` に分割する。
  - diff 行は HTML エスケープしてから `<span class="line file|hunk|add|del|context">…</span>` でラップする。1ファイルが200行を超える場合は先頭100行 + 中略 + 末尾30行に切り詰め、`<summary>` に `（一部省略）` と書き添える。
- `{{PR_ARTICLES}}`: 機能PRごとに以下を生成し連結
  ```html
  <article class="pr" id="pr-{{PR_NUMBER}}">
    <h3><span class="index">{{PR_INDEX}}.</span><span class="pr-num"><a href="{{PR_URL}}" target="_blank" rel="noopener">#{{PR_NUMBER}}</a></span><span class="pr-title">{{PR_TITLE}}</span></h3>
    <div class="badges">{{PR_BADGES}}</div>
    <p>{{PR_DESCRIPTION}}</p>
  </article>
  ```
- `{{PR_BADGES}}`: 該当カテゴリすべてを連結
  - 機能: `<span class="badge feature">機能</span>`
  - GraphQLスキーマ: `<span class="badge graphql">GraphQLスキーマ</span>`
  - DBスキーマ: `<span class="badge schema">DBスキーマ</span>`
  - インフラ: `<span class="badge infra">インフラ</span>`
- `{{PR_DESCRIPTION}}`: そのPRの変更内容の概要を2〜4文（背景・何を変えたか・影響範囲）。識別子は `<code>...</code>` で囲む。本文中に `#1234` のようなPR番号表記を含める場合は、必ず `<a class="pr-ref" href="https://github.com/{owner}/{repo}/pull/{N}" target="_blank" rel="noopener">#{N}</a>` の形式でリンク化する（同じ番号が複数回出ても全箇所リンク化する）。

## O-Step 2: ファイルに書き出す

ファイル名はモードによって異なる:

- `last` モード: `<REPO_NAME>-release-<RELEASE_PR_NUMBER>-<MERGED_AT_COMPACT>.html`
  - `<MERGED_AT_COMPACT>` は `<MERGED_AT>` (UTC ISO 8601) を JST に変換したうえで `YYYYMMDD-HHMM` 形式（区切りなしの日付 + ハイフン + ゼロ埋め時分）にしたもの。例: `2024-04-26T01:30:00Z` → `20240426-1030`
  - 例: `def-release-1234-20240426-1030.html`
- `progress` モード: `<REPO_NAME>-release-<PROGRESS_PR_NUMBER>.html`（マージ前のため日時を付けない）
  - 例: `def-release-1234.html`

`<REPO_NAME>` は `gh repo view --json nameWithOwner --jq '.nameWithOwner | split("/")[1]'` で取得するリポジトリ名（owner/repo のスラッシュ以降）。レンダリング結果を **Claude Code を起動したディレクトリ直下** に書き出す。既存ファイルは上書きする。

`<MERGED_AT_COMPACT>` の生成例（macOS / BSD date）:

```bash
TZ='Asia/Tokyo' date -j -u -f '%Y-%m-%dT%H:%M:%SZ' '<MERGED_AT>' '+%Y%m%d-%H%M'
```

GNU date:

```bash
TZ='Asia/Tokyo' date -d '<MERGED_AT>' '+%Y%m%d-%H%M'
```

## O-Step 3: PR番号リンク化の自己チェック（必須）

ブラウザで開く前に、書き出したHTMLファイルに「プレーンテキストの `#NNNN` が残っていないか」を必ず確認する。

概要4節（機能 / GraphQLスキーマ / DBスキーマ / インフラ）と各PRの `{{PR_DESCRIPTION}}` の中に出てくる `#NNNN` 表記は、例外なく全てGitHub PRへのリンクにすること。同じ番号が複数回出てきても、機能PR一覧に含まれない過去PR・関連PRであっても、`#NNNN` 形式で書かれていれば全てリンク化対象。唯一の例外は TOC の `<a href="#pr-NNNN">` および PR Article の `<h3>` 内のPR番号リンク（テンプレート既定で既にリンク化済み）。

具体例（PR本文に「#18319 で追加した IsRetailLocationTargetingEnabled フラグの…」と書かれている場合）:

- 誤: `<p>#18319 で追加した <code>IsRetailLocationTargetingEnabled</code> フラグの…</p>`
- 正: `<p><a class="pr-ref" href="https://github.com/owner/repo/pull/18319" target="_blank" rel="noopener">#18319</a> で追加した <code>IsRetailLocationTargetingEnabled</code> フラグの…</p>`

### チェック方法

書き出したファイルに対して以下を実行する。`<OUTPUT_FILENAME>` は O-Step 2 で書き出したファイル名:

```bash
# 既にリンク化されている <a class="pr-ref" ...>#NNNN</a> を伏せ字に置換し、
# 残った #NNNN（プレーンテキスト）を抽出する。
# テンプレート由来の偽陽性（id="pr-NNNN"、href="#pr-NNNN"、URL内の pull/NNNN、h3内の class="pr-num"）は除外。
sed -E 's|<a class="pr-ref"[^>]*>#[0-9]+</a>|__PR_REF__|g' <OUTPUT_FILENAME> \
  | grep -nE '#[0-9]{2,}' \
  | grep -v 'id="pr-' \
  | grep -v 'href="#pr-' \
  | grep -v 'pull/[0-9]' \
  | grep -v 'class="pr-num"'
```

何か出力が出れば、その箇所はプレーンテキストの `#NNNN` が残っている。該当箇所を `<a class="pr-ref" href="https://github.com/{owner}/{repo}/pull/{N}" target="_blank" rel="noopener">#{N}</a>`（`{owner}/{repo}` は `gh repo view --json nameWithOwner --jq .nameWithOwner` で取得）に置換し、ファイルを再書き出ししてから再度チェックする。0件になるまで繰り返す。

## O-Step 4: ブラウザで表示する

書き出し後、以下のコマンドでブラウザペインに表示する（`<OUTPUT_FILENAME>` は O-Step 2 で書き出したファイル名）:

```bash
cmux browser open "file://$(pwd)/<OUTPUT_FILENAME>"
```

成功すると `OK surface=surface:N pane=pane:M placement=split` のような出力が返る。失敗時はエラー文をそのままユーザーに伝え、出力ファイルパスだけ案内する。

## O-Step 5: チャットへは1〜2行のサマリのみ

出力ファイルを開いたあと、チャットには「`./<書き出したファイル名>` に書き出してブラウザで開きました（リリースPR `#<番号>`、機能PR `<件数>` 件）」程度の短い報告だけを返す。HTMLの中身（PR一覧や概要）はチャットに再掲しない。

## フォーマット遵守の注意

- HTMLテンプレートは `release-template.md` のものを **改変せず** 使う。CSSや見出し構造を勝手に変えない。
- PR一覧と本文見出しの両方で、PR番号の後ろにPRタイトルを半角スペース区切りで併記する。タイトルは改変・要約せず GitHub の原文ママ（HTMLエスケープのみ）。
- last モードのタイトル日時は JST に変換したうえで `YYYY-MM-DD HH:MM JST` 形式。秒は出さない。progress モードはタイトルに日時を含めない。
- 「概要」4節（機能 / GraphQLスキーマ / DBスキーマ / インフラ）は順序固定。該当なしでも節を省略しない。
- HTMLエスケープ: PRタイトルや概要本文に `<` `>` `&` `"` `'` が含まれる場合はエスケープすること。
- リリースPR自身の番号は機能PR一覧から除外する。
- 概要・PR詳細本文中の `#NNNN` 表記は **すべて** GitHub PR へのリンクにする（`<a class="pr-ref" href="https://github.com/{owner}/{repo}/pull/{N}" target="_blank" rel="noopener">#{N}</a>`）。プレーンテキストの `#NNNN` を残さない。TOC とPR Article の `<h3>` 内のリンクはテンプレート既定のままでよい。書き出し後・ブラウザ表示前に **O-Step 3 の自己チェックを必ず実施** し、プレーン `#NNNN` が0件になっていることを確認する。
- GraphQLスキーマ／DBスキーマ概要は、変更内容ごとにdiffを直後に並べる構造（`<li>` 内に要約 + 該当 `<details class="schema-diff">`）にする。要約だけまとめて出してdiffを末尾にまとめる構造にしない。HTML仕様は `release-template.md` の「スキーマ diff の埋め込み」セクション参照。diffは要約・改変せず原文ママを行クラス分けして出す。

---

# 出力後のユーザーへの補足

チャットへの報告（O-Step 5 のサマリ）に続けて、以下のいずれかに該当する場合のみ簡潔に書き添える。該当しなければ何も書き足さない。

- モード判定があいまいで `last` を採用した場合 → 「`progress` モードを使う場合は『リリース予定の内容を教えて』のように指定してください」
- progress モードで複数 Open PR があり1件に絞り込んだ場合 → 採用したPR番号と理由（`updatedAt` 最新）
- last モードで release ブランチが複数候補あり絞り込んだ場合 → 採用したブランチ名
- 機能PR一覧の取得方法（通常マージ／Squash merge）で分岐があった場合 → 採用したロジック
- `cmux browser open` がエラーになった場合 → エラー内容と書き出したファイル（last: `<リポジトリ名>-release-<番号>-<YYYYMMDD-hhmm>.html` / progress: `<リポジトリ名>-release-<番号>.html`）のフルパスを案内

不要な前置きは省く。HTMLの中身をチャットに再掲しない。

---

# やってはいけないこと

- HTMLテンプレート（`release-template.md`）の改変・要約。CSS や見出し構造を変更しない。
- 出力フォーマットの改変（見出し追加・順序変更・JSTを別タイムゾーンに変える等）
- 推測で「概要」を埋めること。PR本文・変更内容から読み取れない場合は「PR本文に記載なし」と書く。
- 概要・PR詳細本文中に **プレーンテキストの `#NNNN` を残すこと**。PR本文をそのまま転記して `#NNNN` がリンク化されないまま出力するのは仕様違反。書き出し後・ブラウザ表示前に O-Step 3 のセルフチェックを必ず通す。
- スキーマ diff の要約・改変。`gh pr diff` で得られた diff は行クラス分けと HTML エスケープ・上限超過時の中略以外の編集を加えない。
- HTML本体の中身（PR一覧・概要）をチャットに再掲すること。チャットへは O-Step 5 の短いサマリのみ。
- O-Step 2 で定めたファイル名（last: `<リポジトリ名>-release-<PR番号>-<YYYYMMDD-hhmm>.html` / progress: `<リポジトリ名>-release-<PR番号>.html`）以外への書き出し（ユーザーが明示的に別パスを指定した場合のみ従う）。
- `git push` の使用、コミット履歴の改変
- リポジトリ外のファイルへのアクセス
