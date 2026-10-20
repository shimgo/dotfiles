# start: セッションを開始する

## 入力

- PR の URL または番号。無ければ `gh pr view --json number,url` で現在のブランチの PR を探し、見つからなければユーザーに尋ねる。
- リポジトリ固有のレビュースキル名。対象リポジトリの `.claude/skills/` を `ls` し、名前に `review` を含むスキルを候補にする。
  候補が 1 つならそれを `--review-skill` で渡して session.json に残す。複数あってユーザーに選んでもらう必要があるときは、
  difit の起動を先に済ませるため、`--review-skill` を付けずに実行して手順 4 で決める。

## 手順

1. リポジトリのルートで実行する。

```bash
SKILL_DIR=~/.claude/skills/my-pr-review
$SKILL_DIR/scripts/session-start.sh <PR> --review-skill <スキル名>
```

   レビュー対象は常に現在のチェックアウトである。現在のブランチが PR のブランチでなければ、`session-start.sh` は中断する。
   そのときは Claude が checkout せず、`gh pr checkout <PR>` で切り替えてから再実行するようユーザーに案内する
   (ユーザーの作業中のブランチや未コミットの変更を Claude が動かさないため)。

   ケースは `session-start.sh` が決める。Claude は選ばない。
   - PR の作者が `gh` のログイン中のアカウントなら **ケース 2** (local モード)。
   - それ以外は **ケース 1** (github モード)。HEAD が PR の head と一致し、未コミットの変更が無いことも求める。
     満たさなければ中断するので、エラーの内容 (`git pull --ff-only` で揃える、変更を退避する) をユーザーに伝える。

   決めたモードは標準エラーの `info: <モード> モードで開始します` の行と、session.json の `mode` に出る。
   ユーザーの意図と違うモードになったら (例: セルフレビューを頼まれたのに github モードになった)、この行に出る PR の作者と gh のログインを伝えて判断を仰ぐ。

2. **最優先で difit の URL を伝える。** 標準エラーに出る `difit ready: <URL>` の行を見つけたら、残りの出力を読むより先に、
   その URL を本文としてユーザーに出す。ユーザーは Claude のレビューを待たずに自分で差分を読み始める。
   `--background` 起動なのでブラウザは自動では開かない。
   local モードでは difit の対象が base と作業ツリー (`.`) の差分になるため、未コミットの変更もそのまま差分に載る。
3. 取り込んだ GitHub スレッドの件数を伝える。既に GitHub 上にレビューがある PR では、それらが difit に表示されている。
4. レビュースキル名が決まっていなければ、ここでユーザーに選んでもらい session.json に書く。

```bash
jq --arg s '<スキル名>' '.review_skill = $s' <state-dir>/session.json > /tmp/s.json && mv /tmp/s.json <state-dir>/session.json
```

5. 続けてレビューを求められていれば `phases/review.md` に進む。`last_phase` は session-start.sh が `start` にしている。

## 補足

- difit が止まっている状態でセッションを再開する場合も同じコマンドでよい。状態ファイルを引き継ぎ、GitHub 未投稿の指摘を再投入する。
  difit が動いている間は実行を拒否するので、head を更新したいときは `phases/sync.md` を使う。
