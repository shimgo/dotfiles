# answer: difit 上の Claude Code 宛ての本文に応答する

ユーザーはレビュー中に気になった箇所へ、difit 上で `q ` から始まる本文を書く。書式は `reference/reply-convention.md` のとおりで、
新しいスレッドの本文、または Claude のスレッドへの返信のどちらでも `q ` で始まる。
質問とは限らず、「q この指摘は取り下げて」のような指示も含む。

宛先は Claude Code でありレビュイーではない。`q` の本文と応答を GitHub に投稿してはならない。
未処理の `q` が残っている限り triage の GitHub 投稿には進まず、このフェーズを先に終わらせる。

## 手順

1. 分類結果を取得する。

```bash
$SKILL_DIR/scripts/difit-fetch.sh <state-dir>
```

2. `classification` が `to_claude` のスレッドを対象にする。`text` に `q` を除いた本文、`file` と `position` に箇所が入っている。
3. worktree のコードを読んで応答する。指摘への反論や代替案の相談も多いので、結論だけでなく根拠となるコード箇所を示す。
   指示であればそれを実行し、実行した内容を返信に書く。
4. 返信は同じ位置への `reply` として投稿する。`author` を `claude` にすることを忘れない。

```bash
difit comment add --port <port> '{"type":"reply","filePath":"<file>","position":<position>,"body":"<応答>","author":"claude"}'
```

複数件あるときは配列で 1 回にまとめてよい。

`reply` は thread id ではなく filePath と position でスレッドを探し、同じ位置に複数のスレッドがあれば最新のものに付く。
同じ行に複数のスレッドがある場合は、返信の冒頭に「指摘Xについて」のように対象を書いて区別できるようにする。

5. `$SKILL_DIR/scripts/phase-done.sh <state-dir> answer` を実行し、応答した件数と要点を報告する。
   ユーザーが応答を見て `+` か `-` で対応要否を決めるので、threads.jsonl の更新はここでは行わない。
   応答後に未処理の `q` が残っていなければ、次の `next` で triage に進む。
