# triage: 対応要否の返信を処理する

ユーザーは difit 上で Claude の各指摘に `+` (対応が必要) か `-` (対応不要) を返信する。`q` も `+` も `-` も付かない本文はレビュイーへのコメントであり、
対応が必要なものとして扱う。ユーザー自身が書いたレビューコメントも difit 上にある。
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
| `fix` | 対応が必要。`+` の返信と、レビュイーへのコメント | ケース 1 は手順 3、ケース 2 は手順 4 |
| `user_finding` | ユーザーが difit 上で直接書いたレビューコメント | ケース 1 では手順 3 で一緒に投稿する。ケース 2 では手順 4 で対応する |
| `to_claude` | 未処理の Claude Code 宛ての本文 (`q ...`) | `phases/answer.md` に切り替える。応答が済むまで手順 3 の GitHub 投稿を行わない |
| `pending` | ユーザーがまだ返信していない | 何もしない |
| `github` | GitHub 由来で返信なし | 何もしない |
| `none` | Claude が最後に発言済み | 何もしない |
| `processed` | 対応要否を処理済み (GitHub に投稿した、実装した、または対応不要と記録した) | 何もしない。GitHub に投稿した指摘の議論は GitHub で続ける |

### 2. 対応不要の記録と resolve

`dismiss` は必ず **記録してから** difit で resolve する。difit の resolve はスレッドの削除であり、先に消すと理由を失う。

```bash
python3 $SKILL_DIR/scripts/state.py set-status --state <state-dir>/threads.jsonl --difit-id <id> --status dismissed --reason "<text の内容>"
difit comment resolve <id> --port <port>
```

`user_finding` スレッドにユーザーが `不要` と返信した場合も同じ扱いにする。

### 3. ケース 1: GitHub の pending review に反映する

**前提**: `classification` が `to_claude` のスレッドが 1 件でも残っていたら、この手順に入らない。
`q` の本文はレビュイーではなく Claude Code に向けたものなので、先に `phases/answer.md` で応答し、
ユーザーが `+` / `-` を付けて `to_claude` が 0 件になってから投稿する。

対象は `fix` の Claude スレッドと `user_finding` スレッド。1 スレッドを 1 件の指摘にする。

本文は `difit-fetch.sh` の出力にある `github_body` をそのまま使う。組み立て方は次のとおりで、Claude が書き直したり要約したりしない。

- Claude の指摘へのユーザーの返信を先頭に置き、`---` で区切って、その下に Claude の指摘本文を原文のまま載せる。
- `+` や `対応` だけの返信は本文に含めない (指摘本文だけになる)。「ここは仕様の変更が必要では？」のように文があれば含める。
- Claude Code 宛ての本文 (`q ...`) とその応答は含めない。
- 再指摘防止の注記 (`> 過去の判断: ...`) は取り除く。
- ユーザー自身のスレッドは本文をそのまま使う。スレッドへの返信は載せないので、追記したいときは difit 上で本文を編集する。
  本文が `q ...` だけのスレッドは `github_body` が空になる。投稿対象にせず、
  GitHub の指摘にしたいならレビューコメントとして本文を書き直すようユーザーに伝える。

例:

```
ここは仕様の変更が必要では？

---

#1 [重要度] 中🟡

[修正案]

...
```

`[{"difit_thread_id": "...", "body": <github_body>}]` の配列を作って投稿する。

```bash
$SKILL_DIR/scripts/github-pending.sh <state-dir> < items.json
```

pending review は 1 人につき 1 つしか持てないので、既にあれば `github-pending.sh` はそこへ追加する。
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

#### 同じ修正が必要な他の箇所も探す

**指摘された箇所だけを直して終わりにしない。** 同じ問題は他の箇所にもあることが多く、残すと次のレビューで同じ指摘を受ける。
1 件実装するたびに次の手順で同種の箇所を探す。

1. 指摘が指す問題を一般化する (例: 「この関数の戻り値のエラーを無視している」→「同じ関数を呼んでいる箇所すべて」)。
2. `Grep` で探す。修正前のコードにあった識別子、呼び出し、リテラル、構文の形を手がかりにする。
   指摘されたファイルの中だけで終わらせず、リポジトリ全体を対象にする。
3. 見つかった箇所を、この PR の差分内か差分外かで分ける (`git diff --name-only <base_sha>..HEAD` と実際の行で判断する。`base_sha` は session.json の値)。
   - **差分内**: この PR が持ち込んだ問題なので、指摘のコミットに含めて同じ修正を行う。
   - **差分外**: 既存コードの問題であり、直すと PR の目的から外れた差分が増える。修正せず、場所と内容を報告してユーザーの判断を仰ぐ。
4. 探した範囲 (検索に使った語と対象) と、同じ修正を行った箇所、行わなかった箇所を報告に含める。
   同種の箇所が無かった場合もその旨を伝える。省くと、探した結果無かったのか探していないのかをユーザーが区別できない。

### 5. 完了の記録と報告

ケース 1 は `$SKILL_DIR/scripts/phase-done.sh <state-dir> triage` を実行し、`scripts/next.sh` を再実行して `phase` が `wait` でなければ同じターンで続ける。
ケース 2 は続けて実行した review フェーズが `last_phase` を `review` にするので、ここでは実行しない。

不要にした件数と理由の一覧、GitHub に投稿した件数 (ケース 1)、コミット一覧と再レビュー結果 (ケース 2) を報告する。
ケース 2 では、指摘された箇所以外に同じ修正を行った箇所と、差分外にあるため直さなかった同種の箇所も併せて報告する。
