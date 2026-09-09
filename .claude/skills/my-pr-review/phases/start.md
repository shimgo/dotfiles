# start: セッションを開始する

## 入力

- PR の URL または番号。無ければ `gh pr view --json number,url` で現在のブランチの PR を探し、見つからなければユーザーに尋ねる。
- ケースの区別。次の基準で決め、迷ったらユーザーに確認する。
  - 自分の PR (`gh pr view --json author -q .author.login` が `gh api user -q .login` と一致) で、現在のチェックアウトがその PR のブランチなら **ケース 2** (`--local`)。
  - それ以外は **ケース 1** (worktree を作る)。
- リポジトリ固有のレビュースキル名。対象リポジトリの `.claude/skills/` を `ls` し、名前に `review` を含むスキルを候補にする。
  候補が 1 つならそれを使い、複数ならユーザーに選んでもらう。決まった名前は `--review-skill` で渡して session.json に残す。

## 手順

1. リポジトリのルートで実行する。

```bash
SKILL_DIR=~/.claude/skills/my-pr-review
$SKILL_DIR/scripts/session-start.sh <PR> [--local] --review-skill <スキル名>
```

2. 出力された session.json の `difit.url` をユーザーに伝える。`--background` 起動なのでブラウザは自動では開かない。
3. 取り込んだ GitHub スレッドの件数を伝える。既に GitHub 上にレビューがある PR では、それらが difit に表示されている。
4. ケース 1 で現在のディレクトリが worktree でなければ、リポジトリ固有のレビュースキルが worktree を見られるように、
   worktree で Claude Code を起動し直すか `/add-dir` で追加するようユーザーに案内する。
5. 続けてレビューを求められていれば `phases/review.md` に進む。`last_phase` は session-start.sh が `start` にしている。

## 補足

- worktree は `<リポジトリ>-pr-<番号>` という名前でリポジトリの隣に作られ、PR の head に detach で checkout される。
  ブランチは作らないので、他人の PR に誤ってコミットする事故を防げる。
- difit が止まっている状態でセッションを再開する場合も同じコマンドでよい。状態ファイルを引き継ぎ、GitHub 未投稿の指摘を再投入する。
  difit が動いている間は実行を拒否するので、head を更新したいときは `phases/sync.md` を使う。
- セッション終了後に worktree を消すのはユーザーの判断に任せる。状態ファイルは worktree と独立しているので消しても判断は失われない。
