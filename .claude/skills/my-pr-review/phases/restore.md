# restore: 位置を特定できずに difit から外したスレッドを戻す

使う場面: `next.sh` が `restore` を返したとき、または `sync.sh` の出力の `reimported.needs_restore` が空でないとき。

`sync.sh` は difit を作り直すとき、GitHub に投稿していないスレッドの位置を snippet で探し直す (`reference/state.md` の 6 章)。
修正で対象の行が書き換わると snippet が見つからず、そのスレッドを `outdated` にして difit に再投入しない。
Claude の発言だけのスレッドなら verify で確かめればよい。しかしユーザーが書いたスレッドや、ユーザーの返信を含む指摘を外したままにすると、
ユーザーは自分の質問や判断を difit 上で見られなくなる。

スクリプトは行の候補を推測しない。誤った行へ付け替えると、ユーザーは別の行への発言として読んでしまうためである。
代わりに `sync.sh` が発言 (root と返信) を状態ファイルに残し、Claude が修正の差分を読んで行を決め、`difit-restore.sh` で戻す。

## 手順

1. 対象を列挙する。

```bash
python3 $SKILL_DIR/scripts/state.py latest --state <state-dir>/threads.jsonl --needs-restore
```

各レコードの `file`、`line` (前回の位置)、`snippet` (前回の位置のコード)、`head_sha` (前回の位置を確かめたコミット)、
`messages` (difit 上の発言。先頭が root) を読む。`messages` が無いレコードは `body` が root の本文である。

2. スレッドごとに、戻す行を決める。

```bash
git -C <worktree> diff <レコードの head_sha> -- <file>
```

local モードでは difit が作業ツリーを表示するので、`HEAD` ではなく作業ツリーと比べる。
差分の中で、`snippet` の行を置き換えた行を探し、その行 (複数行ならその範囲) を戻す先にする。

- **書き換えた行がある**: 置き換えた先の行にする。発言が指していたコードと同じ役割の行を選ぶ (例: 変数への代入を `if` の条件に書き換えたなら、その `if` の行)。
- **行を削除しただけで、置き換えた行が無い**: 削除した位置のすぐ上か下にある、同じ関数の中の差分の行にする。
  発言が指していたコードはもう無いことを、手順 4 の報告に書く。
- **ファイルごと無くなった、または移動した**: 移動先のファイルで同じコードを探し、手順 3 の第 4 引数に移動先のファイルを渡す。見つからなければ戻さず、ユーザーに判断を仰ぐ (手順 4)。

戻す先は、PR の差分 (`git -C <worktree> diff <session.json の base_sha> -- <file>`) に現れる行から選ぶ。
ユーザーは difit の画面で差分を読むため、差分から離れた行に戻すとスレッドを見つけにくい。

3. 戻す。

```bash
$SKILL_DIR/scripts/difit-restore.sh <state-dir> <key> <行 (12 または 12-14)> [<移動先のファイル>]
```

`difit-restore.sh` はスレッドを元の id のまま、root と返信の順に difit へ再投入し、レコードを `open` に戻す。
移動先のファイルを渡すと、レコードの `file` もそのファイルに置き換える。
レコードの `snippet` は指定した行のコードに置き換わるので、次の `sync.sh` はその位置からスレッドを探し直す。

**戻したスレッドに、位置を移したことを知らせる返信を足さない。** Claude の返信が最後の発言になると、未処理の `q` を `none` に分類してしまい、
answer フェーズがその `q` に応答しなくなる (`reference/reply-convention.md`)。移した事実は手順 4 の報告で伝える。

4. 報告する。戻したスレッドごとに、次を 1 行で書く。

- ファイルと、前回の行 → 戻した行
- root の本文の要約 (ユーザーのスレッドなら質問や指示の内容)
- その行を選んだ理由 (どのコードをどう書き換えたか)。発言が指していたコードが無くなった場合はその旨

戻さなかったスレッドは、発言の全文と戻さなかった理由を書き、扱いをユーザーに確かめる。
ユーザーが不要と判断したら `state.py set-status --status dismissed --reason "<理由>"` で記録する。

5. `$SKILL_DIR/scripts/phase-done.sh <state-dir> restore` を実行し、`scripts/next.sh` を再実行して `phase` が `wait` でなければ同じターンで続ける。
   戻したスレッドに未処理の `q` があれば、`next.sh` は `answer` を返す。
