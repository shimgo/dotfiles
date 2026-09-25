# start: セッションを開始する

## 入力

- PR の URL または番号。無ければ `gh pr view --json number,url` で現在のブランチの PR を探し、見つからなければユーザーに尋ねる。
- リポジトリ固有のレビュースキル名。対象リポジトリの `.claude/skills/` を `ls` し、名前に `review` を含むスキルを候補にする。
  候補が 1 つならそれを `--review-skill` で渡して session.json に残す。複数あってユーザーに選んでもらう必要があるときは、
  difit の起動を先に済ませるため、`--review-skill` を付けずに実行して手順 5 で決める。

## 手順

1. リポジトリのルートで実行する。

```bash
SKILL_DIR=~/.claude/skills/my-pr-review
$SKILL_DIR/scripts/session-start.sh <PR> --review-skill <スキル名>
```

   ケースは `session-start.sh` が決める。Claude は選ばない。
   - PR の作者が `gh` のログイン中のアカウントで、現在のブランチがその PR のブランチなら **ケース 2** (local モード)。
   - それ以外は **ケース 1** (worktree モード)。

   決めたモードは標準エラーの `info: <モード> モードで開始します` の行と、session.json の `mode` に出る。
   ユーザーの意図と違うモードになったら (例: セルフレビューを頼まれたのに worktree モードになった)、この行に出る作者とブランチのどちらが一致しなかったかを伝えて判断を仰ぐ。

2. **最優先で difit の URL を伝える。** 標準エラーに出る `difit ready: <URL>` の行を見つけたら、残りの出力を読むより先に、
   その URL を本文としてユーザーに出す。ユーザーは Claude のレビューを待たずに自分で差分を読み始める。
   `--background` 起動なのでブラウザは自動では開かない。
   local モードでは difit の対象が base と作業ツリー (`.`) の差分になるため、未コミットの変更もそのまま差分に載る。
3. 取り込んだ GitHub スレッドの件数を伝える。既に GitHub 上にレビューがある PR では、それらが difit に表示されている。
4. ケース 1 で現在のディレクトリが worktree でなければ、リポジトリ固有のレビュースキルが worktree を見られるように、
   worktree で Claude Code を起動し直すか `/add-dir` で追加するようユーザーに案内する。
5. レビュースキル名が決まっていなければ、ここでユーザーに選んでもらい session.json に書く。

```bash
jq --arg s '<スキル名>' '.review_skill = $s' <state-dir>/session.json > /tmp/s.json && mv /tmp/s.json <state-dir>/session.json
```

6. 続けてレビューを求められていれば `phases/review.md` に進む。`last_phase` は session-start.sh が `start` にしている。

## 補足

- worktree は `<リポジトリ>-pr-<番号>` という名前でリポジトリの隣に作られ、PR の head に detach で checkout される。
  ブランチは作らないので、他人の PR に誤ってコミットする事故を防げる。
- difit が止まっている状態でセッションを再開する場合も同じコマンドでよい。状態ファイルを引き継ぎ、GitHub 未投稿の指摘を再投入する。
  difit が動いている間は実行を拒否するので、head を更新したいときは `phases/sync.md` を使う。
- セッション終了後に worktree を消すのはユーザーの判断に任せる。状態ファイルは worktree と独立しているので消しても判断は失われない。
