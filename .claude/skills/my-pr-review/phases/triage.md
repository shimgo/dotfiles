# triage: 対応要否の返信を処理する

ユーザーは difit 上で Claude の各指摘に `対応` (省略形 `+`) か `不要: 理由` (省略形 `-`) を返信する。ユーザー自身が書いたレビューコメントも difit 上にある。
このフェーズはそれらを状態ファイルと GitHub、またはコードに反映する。

## 手順

### 1. 分類結果を取得する

```bash
$SKILL_DIR/scripts/difit-fetch.sh <state-dir>
```

`classification` ごとの扱い:

| classification | 意味 | 扱い |
| --- | --- | --- |
| `dismiss` | 対応不要 | 手順 2 |
| `fix` | 対応が必要 | ケース 1 は手順 3、ケース 2 は手順 4 |
| `user_finding` | ユーザーが difit 上で直接書いたレビューコメント | ケース 1 では手順 3 で一緒に投稿する。ケース 2 では手順 4 で対応する |
| `question` | 未回答の質問 | `phases/answer.md` に切り替える |
| `pending` | ユーザーがまだ返信していない | 何もしない |
| `unclear` | 書式に合わない返信 | 内容を要約してユーザーに確認する。勝手に解釈しない |
| `github` | GitHub 由来で返信なし | 何もしない |
| `none` | Claude が最後に発言済み | 何もしない |

### 2. 対応不要の記録と resolve

`dismiss` は必ず **記録してから** difit で resolve する。difit の resolve はスレッドの削除であり、先に消すと理由が失われる。

```bash
python3 $SKILL_DIR/scripts/state.py set-status --state <state-dir>/threads.jsonl --difit-id <id> --status dismissed --reason "<text の内容>"
difit comment resolve <id> --port <port>
```

`user_finding` スレッドにユーザーが `不要` と返信した場合も同じ扱いにする。

### 3. ケース 1: GitHub の pending review に反映する

対象は `fix` の Claude スレッドと `user_finding` スレッド。1 スレッドを 1 件の指摘にまとめる。

- Claude の指摘にユーザーが補足を返信していれば、その意図を取り込んで本文を書き直す。
- 本文はレビュー依頼者に向けた文章にする。「Claude の指摘」という体裁は残さず、根拠と修正案を簡潔に書く。
- 本文は Markdown。コードは fenced code block にする。

`[{"difit_thread_id": "...", "body": "..."}]` の配列を作って投稿する。

```bash
$SKILL_DIR/scripts/github-pending.sh <state-dir> < items.json
```

pending review は 1 人につき 1 つしか持てないので、既にあればそれに追加される。
投稿後は GitHub 上で pending コメントの見直しと送信、Viewed の管理をユーザーに任せる。
送信後の同期は `phases/sync.md` で行う。

### 4. ケース 2: 実装する

対象は `fix` の Claude スレッドと `user_finding` スレッド。1 スレッドごとに実装してコミットする。

- コミットは 1 スレッド 1 コミット。メッセージの末尾に `difit: <difit_thread_id>` を入れると、後で verify するときにどのコミットがどの指摘に対応したかを追える。
- 実装後は状態を `resolved` にし、difit のスレッドを消す。

```bash
python3 $SKILL_DIR/scripts/state.py set-status --state <state-dir>/threads.jsonl --difit-id <id> --status resolved --reason "<コミットハッシュ>"
difit comment resolve <id> --port <port>
```

- すべて実装したら `scripts/sync.sh <state-dir>` で difit を新しい HEAD で作り直し、`phases/review.md` に進んで
  `reviewed_head_sha..HEAD` の差分だけを再レビューする。この再レビューは自動で続ける。ユーザーが「対応を依頼する」と言った時点で再レビューまでを 1 つの仕事とみなしている。

### 5. 完了の記録と報告

ケース 1 は `$SKILL_DIR/scripts/phase-done.sh <state-dir> triage` を実行する。
ケース 2 は続けて実行した review フェーズが `last_phase` を `review` にするので、ここでは実行しない。

不要にした件数と理由の一覧、GitHub に投稿した件数 (ケース 1)、コミット一覧と再レビュー結果 (ケース 2) を報告する。
