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
   ただし、ケース 1 で PR の body の編集を指示されたら実行しない (SKILL.md「ケース 1 では PR の body を編集しない」)。
   実行しなかったことと理由を返信に書き、スレッドは open のまま残す。
   指示がコードの修正なら、`phases/triage.md` の手順 4 と同じく同じ修正が必要な他の箇所を探し、差分内のものは併せて直して返信に書く。
4. 返信は同じ位置への `reply` として投稿する。`author` を `claude` にすることを忘れない。

```bash
difit comment add --port <port> '{"type":"reply","filePath":"<file>","position":<position>,"body":"<応答>","author":"claude"}'
```

複数件あるときは配列で 1 回にまとめてよい。

`reply` は thread id ではなく filePath と position でスレッドを探し、同じ位置に複数のスレッドがあれば最新のものに付く。
同じ行に複数のスレッドがある場合は、返信の冒頭に「指摘Xについて」のように対象を書いて区別できるようにする。

5. 実行を終えた指示のスレッドを resolve する。

`q` の中身が **質問** なら open のまま残す。ユーザーが応答を読んで `+` か `-` で対応要否を決めるためである。
`q` の中身が **指示** で、手順 3 でその実行を終えたなら、ユーザーの判断を待つものが無いのでここで閉じる。

difit のスレッドは resolve すると消えるため、必ず記録を先に残す。

```bash
python3 $SKILL_DIR/scripts/state.py set-status --state <state-dir>/threads.jsonl --difit-id <difit の thread id> --status resolved --reason "<実行した内容>"
difit comment resolve <difit の thread id>... --port <port>
```

- `--difit-id` には `difit-fetch.sh` の `difit_thread_id` を渡す。ユーザーが書いたスレッドも Claude の指摘のスレッドも同じように指定できる。
- `--reason` には実行した内容を書く。難しい判断をした指示ほど、後から経緯を辿れる価値が高い。
- ケース 2 で指示がコードの修正で、コミットまで終えたなら、`--instruction "<q を除いた指示の本文>" --fix-commit "<コミットハッシュ>"` も付ける。
  triage の実装と同じく「ユーザーの指示で実装した変更」の記録になり、再レビューがこの変更を覆す指摘を投稿しないために使う (`phases/review.md` の手順 4)。
- **`set-status` の出力を `append` へパイプしない。** `set-status` は自身で状態ファイルへ追記し、追記したレコードを標準出力へ整形して出す。パイプすると二重に追記しようとして、複数行 JSON のためパースにも失敗する。
- `difit comment resolve` は thread id を複数渡せるので、記録を全件終えてから 1 回で resolve してよい。

6. `$SKILL_DIR/scripts/phase-done.sh <state-dir> answer` を実行する。

7. `$SKILL_DIR/scripts/next.sh <state-dir>` を再実行し、`phase` が `wait` でなければ同じターンでそのフェーズに進む。
   `+` や `-` の返信が残っていれば `phase` は `triage` になる。**ここでターンを終えず、`phases/triage.md` を続けて実行する。**
   `q` への応答だけを終えて `+` の返信を次のターンに残すと、ユーザーは同じ `next` をもう一度打つことになる。

   `wait` に到達したら、応答した件数・resolve した件数・要点と、続けて実行したフェーズの結果をまとめて報告する。
   open のまま残したスレッドは、ユーザーが `+` か `-` で対応要否を決める。
