# answer: difit 上の質問に返信する

ユーザーはレビュー中に気になった箇所へ、difit 上で質問を書く。書式は `reference/reply-convention.md` のとおりで、
新しいスレッドの本文、または Claude のスレッドへの返信のどちらでも `質問:` か省略形の `q ` で始まる。

質問の宛先は Claude Code であり PR 作者ではない。質問本文を GitHub に投稿してはならない。
未回答の質問が残っている限り triage の GitHub 投稿には進まず、このフェーズを先に終わらせる。

## 手順

1. 分類結果を取得する。

```bash
$SKILL_DIR/scripts/difit-fetch.sh <state-dir>
```

2. `classification` が `question` のスレッドを対象にする。`text` に質問本文、`file` と `position` に箇所が入っている。
3. worktree のコードを読んで答える。指摘への反論や代替案の相談も多いので、結論だけでなく根拠となるコード箇所を示す。
4. 返信は同じ位置への `reply` として投稿する。`author` を `claude` にすることを忘れない。

```bash
difit comment add --port <port> '{"type":"reply","filePath":"<file>","position":<position>,"body":"<回答>","author":"claude"}'
```

複数件あるときは配列で 1 回にまとめてよい。

`reply` は thread id ではなく filePath と position でスレッドを探し、同じ位置に複数のスレッドがあれば最新のものに付く。
同じ行に複数のスレッドがある場合は、返信の冒頭に「指摘Xについて」のように対象を書いて区別できるようにする。

5. `$SKILL_DIR/scripts/phase-done.sh <state-dir> answer` を実行し、答えた件数と要点を報告する。
   ユーザーが回答を見て `+` か `-` で対応要否を決めるので、threads.jsonl の更新はここでは行わない。
   回答後に未回答の質問が残っていなければ、次の `next` で triage に進む。
