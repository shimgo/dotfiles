# 状態ファイルの設計

## 目次

1. 状態を置く場所と理由
2. session.json
3. threads.jsonl のレコード
4. 照合ロジック (再指摘防止)
5. scope の取得方法
6. status の遷移
7. 削除

## 1. 状態を置く場所と理由

状態は次の 2 か所だけに置く。

| 場所 | 役割 |
| --- | --- |
| GitHub | レビュー送信後の正本。open / resolved の状態は GraphQL で取得する |
| `~/.local/state/claude/review/<owner>/<repo>/pr-<番号>/` | GitHub に記録が残らないもの (対応不要の判断、未投稿の指摘) と、GitHub のスレッドを照合キーに結び付ける索引 |

difit には状態を持たせない。difit のコメントはサーバのメモリとブラウザの localStorage にしか無く、
worktree の削除や head の更新をまたいで信頼できないためである。difit は毎ラウンド `--clean` で作り直す。

`~/.local/state` は XDG Base Directory の `XDG_STATE_HOME` であり、「再起動をまたいで保持したいが設定でもユーザー資産でもない状態」を置く場所として定義されている。
リポジトリ内にコミットしないのは、対応不要の判断がレビュアー個人のものであり、PR ブランチにノイズを乗せないためである。

## 2. session.json

| フィールド | 内容 |
| --- | --- |
| `repo` | `gh repo view --json nameWithOwner` の値 |
| `pr`, `pr_url` | PR 番号と URL |
| `mode` | `worktree` (他人の PR) か `local` (自分のチェックアウト) |
| `worktree` | レビュー対象のディレクトリ |
| `base_ref`, `head_ref` | ブランチ名 |
| `base_sha`, `head_sha` | 現在の diff の両端。`base_sha` は merge-base |
| `reviewed_head_sha` | 最後にレビュースキルを実行したときの head。差分のみの再レビューの起点 |
| `difit` | `{port, url, pid}` |
| `review_skill` | リポジトリ固有のレビュースキル名 |
| `state_dir` | このディレクトリ自身のパス |

## 3. threads.jsonl のレコード

1 行 1 レコード、追記のみ。同じ `key` の行のうち最後の行が有効である。status の変更は新しい行の追記で表す。
追記のみにするのは、複数の worktree で並行してセッションを動かしても互いを上書きしないためである。

```json
{"schema_version":1,"key":"7c1e...","repo":"<owner>/<repo>","pr":1234,"head_sha":"a1b2c3d","file":"internal/point/offset.go","side":"new","line":{"start":42,"end":44},"scope":"func (s *Service) Offset(ctx context.Context, in Input) error","snippet":"\tif user.NewFlag {\n\t\treturn nil\n\t}","snippet_sha256":"9f2a...","perspective":"観点5: 破壊的な変更の確認","summary":"既存ユーザーで NewFlag が暗黙的に false になる","body":"...","reason":"マイグレーション 0042 でバックフィル済み","fingerprint":"7c1e...","origin":"claude","difit_thread_id":"claude-3f9a1c2b7d4e","github_thread_id":null,"github_comment_id":null,"status":"dismissed","created_at":"2026-09-08T17:30:00+09:00","updated_at":"2026-09-08T17:45:00+09:00"}
```

| フィールド | 内容 |
| --- | --- |
| `key` | レコードの識別子。Claude の指摘は `fingerprint`、GitHub 由来は GitHub の thread id、ユーザーが difit に書いたものは difit の thread id |
| `head_sha` | 最後に位置を確認した head |
| `file`, `side`, `line` | 位置。`line` は照合には使わず、difit への再投入にだけ使う |
| `scope` | 指摘箇所を囲む Go 関数のシグネチャ。取得できなければ null |
| `snippet` | 指摘対象行の原文 (複数行は `\n` 区切り) |
| `snippet_sha256` | `snippet` を正規化したものの SHA-256 |
| `perspective`, `summary`, `body` | 観点、要約、difit に表示した本文 |
| `reason` | 対応不要とした理由、または resolve の根拠 |
| `fingerprint` | `perspective` と `summary` を連結して正規化したものの SHA-256 |
| `origin` | `claude` / `user` / `github` |
| `difit_thread_id` | difit 上の thread id。GitHub に投稿された後は GitHub の root comment id に置き換わる |
| `github_thread_id`, `github_comment_id` | GitHub の thread と root comment の node id |
| `status` | `open` / `dismissed` / `posted` / `resolved` / `outdated` |

正規化: 各行の行頭と行末の空白を除去し、連続する空白を 1 つに圧縮する。コメントは指摘対象になりうるので除去しない。

## 4. 照合ロジック (再指摘防止)

`state.py match` が新しい指摘を有効なレコード全件と突き合わせる。status は問わない (open や posted も「既出」として抑止の対象になる)。

| 条件 | decision | 挙動 |
| --- | --- | --- |
| `file` と `snippet_sha256` が一致し、`perspective` も一致 | `suppress` | 投稿しない。過去の判断をユーザーに報告する |
| `file` と `snippet_sha256` が一致するが `perspective` が異なる | `annotate` | 過去の判断を注記して投稿する |
| `snippet_sha256` は不一致だが `file`、`scope`、`fingerprint` が一致 | `annotate` | 同上 |
| 上記以外 | `report` | 通常どおり投稿する |

`perspective` を条件に含めるのは、同じ行に対する別の問題まで握りつぶさないためである。
`perspective` は観点の固定ラベルであり、レビューのたびに同じ語になることを前提にしている。
`summary` は自由記述で毎回変わりうるため、`fingerprint` の一致は補助的にしか効かない。

コードが変われば `snippet_sha256` が変わり、過去の判断は自動抑止から外れる。
「かつて不要と判断したが、その後の修正で有効になった指摘」を握りつぶさないための設計である。

採用しないもの:

- 前後数行を含めたハッシュ: 無関係な近傍の変更で失効する
- 意味的な一致を Claude に判定させる方式: 非決定的で、誤判定が握りつぶしに直結する
- 行番号: rebase や force-push で無意味になる

## 5. scope の取得方法

Go のみ。gofmt 済みで、トップレベル宣言は行頭が非空白、関数本体は字下げされていることを利用する。

1. 指摘行の行頭が非空白なら、それ自体がトップレベル宣言なので null
2. 字下げされていれば、上方向に走査して最初に現れる行頭が非空白の行を探す
3. その行が `func ` で始まればシグネチャ (末尾の `{` を除く) を scope とする。それ以外 (`type`、`var`、`const`、`import` など) は null

Go 以外のファイルは常に null。その場合は照合の 3 段目が成立しないので、1 段目と 2 段目だけで判定する。

## 6. status の遷移

```
open ──(triage: 不要)──▶ dismissed
open ──(triage: ケース1 pending 投稿)──▶ posted ──(sync: GitHub で resolved)──▶ resolved
                                          posted ──(sync: 送信前に削除)──▶ dismissed
open ──(triage: ケース2 実装)──▶ resolved
open ──(sync: 位置を特定できない)──▶ outdated
resolved ──(sync: GitHub で unresolve)──▶ posted
```

GitHub から取り込んだ他人のスレッドは `github` origin で `open` または `resolved` として記録される。
これは Claude の新しい指摘が同じ行に付いたときに注記を出すための索引であり、GitHub の状態を複製する目的ではない。

## 7. 削除

自動削除はしない。クローズ済み PR の判定をレビューのたびに行うと GitHub への問い合わせが増えるためである。

```bash
rm -r ~/.local/state/claude/review/<owner>/<repo>/pr-1234
```
