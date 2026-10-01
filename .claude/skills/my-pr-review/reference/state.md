# 状態ファイルの設計

## 目次

1. 状態を置く場所と理由
2. session.json
3. threads.jsonl のレコード
4. 照合ロジック (再指摘防止)
5. scope の取得方法
6. 位置の特定し直し
7. status の遷移
8. 削除

## 1. 状態を置く場所と理由

状態は次の 2 か所だけに置く。

| 場所 | 役割 |
| --- | --- |
| GitHub | レビュー送信後の正本。open / resolved の状態は GraphQL で取得する |
| `~/.local/state/claude/review/<owner>/<repo>/pr-<番号>/` | GitHub に記録が残らないもの (対応不要の判断、未投稿の指摘) と、GitHub のスレッドを照合キーに結び付ける索引 |

difit には状態を持たせない。difit のコメントはサーバのメモリとブラウザの localStorage にしか無く、
worktree の削除や head の更新をまたいで信頼できないためである。difit は毎ラウンド `--clean` で作り直す。

`~/.local/state` は XDG Base Directory の `XDG_STATE_HOME` であり、XDG Base Directory の仕様はこの場所を「再起動をまたいで保持したいが設定でもユーザー資産でもない状態」を置く場所と定めている。
リポジトリ内にコミットしないのは、対応不要の判断がレビュアー個人のものであり、PR ブランチにノイズを乗せないためである。

## 2. session.json

| フィールド | 内容 |
| --- | --- |
| `repo` | `gh repo view --json nameWithOwner` の値 |
| `pr`, `pr_url` | PR 番号と URL |
| `mode` | `local` (PR の作者が `gh` のログイン中のアカウントで、現在のブランチがその PR のブランチ。ケース 2) か `worktree` (それ以外。ケース 1)。`session-start.sh` が決める |
| `worktree` | レビュー対象のディレクトリ |
| `base_ref`, `head_ref` | ブランチ名 |
| `base_sha`, `head_sha` | 現在の diff の両端。`base_sha` は merge-base |
| `reviewed_head_sha` | 最後にレビュースキルを実行したときの head。差分のみの再レビューの起点 |
| `last_phase` | 最後に完了したフェーズ。`next.sh` の判定に使う |
| `difit` | `{port, url, pid}` |
| `review_skill` | リポジトリ固有のレビュースキル名 |
| `state_dir` | このディレクトリ自身のパス |

## 3. threads.jsonl のレコード

1 行 1 レコード、追記のみ。同じ `key` の行のうち最後の行が有効である。status の変更は新しい行の追記で表す。
追記のみにするのは、複数の worktree で並行してセッションを動かしても互いを上書きしないためである。

```json
{"schema_version":1,"key":"claude-3f9a1c2b7d4e","repo":"<owner>/<repo>","pr":1234,"head_sha":"a1b2c3d","file":"internal/point/offset.go","side":"new","line":{"start":42,"end":44},"scope":"func (s *Service) Offset(ctx context.Context, in Input) error","snippet":"\tif user.NewFlag {\n\t\treturn nil\n\t}","snippet_sha256":"9f2a...","perspective":"観点5: 破壊的な変更の確認","summary":"既存ユーザーで NewFlag が暗黙的に false になる","body":"...","reason":"マイグレーション 0042 でバックフィル済み","fingerprint":"7c1e...","origin":"claude","difit_thread_id":"claude-3f9a1c2b7d4e","github_thread_id":null,"github_comment_id":null,"status":"dismissed","created_at":"2026-09-08T17:30:00+09:00","updated_at":"2026-09-08T17:45:00+09:00"}
```

| フィールド | 内容 |
| --- | --- |
| `key` | レコードの識別子。Claude の指摘は `to-difit` が払い出す difit の thread id (`claude-<12 桁の 16 進数>`。difit に投稿しない `overruled` の指摘にも同じ形式で払い出す)、GitHub 由来は GitHub の thread id、ユーザーが difit に書いたものは difit の thread id。`fingerprint` を key にしないのは、観点と要約が同じ別の箇所への指摘で key が重なり、後の行が前の行を上書きして片方の記録が消えるためである。以前の版が作った状態ファイルには `fingerprint` を key に持つ Claude の指摘が残るが、key は識別子としてだけ使うのでそのまま扱える |
| `head_sha` | 最後に位置を確認した head。snippet が複数の位置に一致したときは、このコミットのファイルを前回の位置の比較に使う (6 章) |
| `file`, `side`, `line` | 位置。`line` は照合には使わない。difit への再投入と、snippet が複数の位置に一致したときの絞り込み (6 章) にだけ使う |
| `scope` | 指摘箇所を囲む Go 関数のシグネチャ。取得できなければ null |
| `snippet` | 指摘対象行の原文 (複数行は `\n` 区切り) |
| `snippet_sha256` | `snippet` を正規化したものの SHA-256 |
| `perspective`, `summary`, `body` | 観点、要約、difit に表示した本文 |
| `reason` | 対応不要とした理由、または resolve の根拠 |
| `instruction` | ケース 2 で実装を指示したユーザーの返信の本文 (先頭語を除く)。`+` だけなら空文字。指示で実装していないレコードは null |
| `fix_commit` | ケース 2 でユーザーの指示を実装したコミット。これを持つ `resolved` のレコードを `state.py directives` が「ユーザーの指示で実装した変更」として返す |
| `overrules` | このレコードの指摘が覆そうとした「ユーザーの指示で実装した変更」のレコードの `key`。該当しなければ null |
| `fingerprint` | `perspective` と `summary` を連結して正規化したものの SHA-256 |
| `origin` | `claude` / `user` / `github` |
| `difit_thread_id` | difit 上の thread id。GitHub に投稿した指摘は、sync が GitHub から取り込むときに GitHub の root comment id へ置き換える。置き換える前の id も履歴の行に残るので、difit のスレッドからレコードを引くときは履歴に現れたすべての id を使う (`state.py` の `records_by_difit_id`) |
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

### ユーザーの指示で実装した変更を覆す指摘

上の照合とは別に、findings が `overrules` を持つ指摘を `state.py match` は `overruled` と判定する。
`to-difit` はこの指摘を difit に投稿せず、status が `dismissed` で `overrules` に指示のレコードの `key` を持つレコードだけを生成する。
記録が残るので、次回以降は同じ箇所・同じ観点の指摘を上の照合でも抑止できる。

`overrules` を書くかどうかは Claude が `phases/review.md` の基準で判断する。再指摘防止の照合では意味的な一致の判定を採用していないが、ここで採用するのは次の理由による。

- 覆す対象は「ユーザーの指示で実装した変更」に限られ、`state.py directives` が候補を列挙する。`match` は、`overrules` が指す先が `fix_commit` を持つ `resolved` のレコードでなければ中断するので、根拠の無い指摘の握りつぶしには使えない
- 指示を覆す指摘は、コードが変わるたびに `snippet_sha256` も `summary` も変わるため、決定的な照合では捉えられない
- 投稿しなかった指摘は必ずユーザーへの報告に載せるので、判定を誤ってもユーザーが気づける

採用しないもの:

- 前後数行を含めたハッシュ: 無関係な近傍の変更で失効する
- 意味的な一致を Claude に判定させる方式: 非決定的で、誤判定が握りつぶしに直結する
- 行番号: rebase や force-push で無意味になる。ただし位置の特定し直しでは、候補を絞る補助にだけ使う (6 章)

## 5. scope の取得方法

Go のみ。gofmt 済みのコードでは、トップレベル宣言の行頭が非空白になり、関数本体の行は字下げを持つ。この性質を利用する。

1. 指摘行の行頭が非空白なら、それ自体がトップレベル宣言なので null
2. 指摘行が字下げを持てば、上方向に走査して最初に現れる行頭が非空白の行を探す
3. その行が `func ` で始まればシグネチャ (末尾の `{` を除く) を scope とする。それ以外 (`type`、`var`、`const`、`import` など) は null

Go 以外のファイルは常に null。その場合は照合の 3 段目が成立しないので、1 段目と 2 段目だけで判定する。

## 6. 位置の特定し直し

sync が difit を作り直すとき、GitHub に投稿していない open のスレッドの位置を `state.py rebuild` (内部で `relocate_record`) が決め直す。
現在のファイル (`side` が old なら `base_sha` のファイル) から、各行を正規化した snippet と一致する位置を探す。

- 一致が 1 か所なら、その位置にする
- 一致が無ければ `outdated` にする。修正で行が消えた可能性があるので verify で確かめる
- 一致が複数なら、次の順で 1 か所に絞る (`narrow_hits`)
  1. `scope` が同じ候補に絞る
  2. `head_sha` のファイルの `line` に snippet があれば、前後 5 行のうち一致する行が最も多い候補に絞る
  3. `line` に snippet がまだあれば、その候補に絞る
  4. それでも複数なら `outdated` にする

正規化で空白の差が消えるため、1 行の snippet は揃えの空白だけが違う別の行 (例: `PurchasePrice:            1000,` と `PurchasePrice: 1000,`) にも一致する。
一致が複数になるたびに `outdated` にすると、ファイルが変わっていなくても未判断の指摘が difit から消える。これを防ぐために絞り込みを行う。

2 を 3 より先に行うのは、上に行が増えて別の候補が前回の行番号へ移ってきた場合に、行番号だけで選ぶと別の行へ付け替えてしまうためである。
2 は、前回確かめたときのファイルと前後の行を比べて、同じ行がずれた先を選ぶ。

前回の行番号から近い候補を選ぶ方式は採用しない。
`}` のようにどこにでもある行へ付けた指摘を別の行へ付け替えやすく、付け替えを誤ると、ユーザーは別の行への指摘として判断してしまう。
`outdated` にしておけば verify で確かめられる。

## 7. status の遷移

```
open ──(answer: 指示を実行)──▶ resolved
open ──(triage: 不要)──▶ dismissed
open ──(triage: ケース1 pending 投稿)──▶ posted ──(sync: GitHub で resolved)──▶ resolved
                                          posted ──(sync: 送信前に削除)──▶ dismissed
open ──(triage: ケース2 実装)──▶ resolved (instruction と fix_commit を記録する)
(新規) ──(review: ユーザーの指示で実装した変更を覆す指摘)──▶ dismissed (overrules を記録し、difit には投稿しない)
open ──(sync: 位置を特定できない)──▶ outdated
resolved ──(sync: GitHub で unresolve)──▶ posted
```

Claude の指摘とユーザー自身のスレッドのうち、status が `posted` / `resolved` / `dismissed` のレコードは対応要否の返信を処理済みである。
`state.py triage` はそのスレッドの返信を分類し直さず、`processed` に分類する (`reference/reply-convention.md`)。

GitHub から取り込んだ他人のスレッドは、`from-github` が `github` origin の `open` または `resolved` として記録する。
これは Claude の新しい指摘が同じ行に付いたときに注記を出すための索引であり、GitHub の状態を複製する目的ではない。

## 8. 削除

自動削除はしない。クローズ済み PR の判定をレビューのたびに行うと GitHub への問い合わせが増えるためである。

```bash
rm -r ~/.local/state/claude/review/<owner>/<repo>/pr-1234
```
