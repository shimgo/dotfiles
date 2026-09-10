# sync: GitHub の状態を取り込み、difit を作り直す

使う場面:

- ユーザーが GitHub 上でレビューを送信した後
- レビュー依頼者が返信や修正をしてきた後
- ケース 2 で自分がコミットを積み、difit の diff を新しい HEAD に合わせたいとき

GitHub 上のコメント状況が正本になるため、ローカルの状態と difit をそれに合わせる。

## 手順

0. 先に `phases/triage.md` を済ませる。GitHub 由来のスレッドに difit 上で付けた返信は、作り直しのときに GitHub の内容で上書きされて消える。
   Claude の指摘とユーザー自身のスレッドは返信ごと再投入されるので失われない。

1. 実行する。

```bash
$SKILL_DIR/scripts/sync.sh <state-dir>
```

2. 出力を読み、次を報告する。

- `reconciled`: status が変わったレコード。`resolved` は GitHub 上で解決済みになったもの、`dismissed` は pending から送信までの間に削除されたもの (再指摘防止の対象になる)。
- `warnings`: pending review が残っているため判断を保留したものなど。ユーザーが送信を忘れている可能性を伝える。
- `reimported.outdated`: head が変わって位置を特定できなくなった未投稿の指摘。修正で消えた行に対する指摘なら対応済みの可能性が高い。verify で扱う。
- `session.difit.url`: 新しい difit の URL。ポートが変わっていることがあるので必ず伝える。

3. `$SKILL_DIR/scripts/phase-done.sh <state-dir> sync` を実行する。head が変わっていれば、次は `phases/verify.md` で指摘箇所の修正を確認する。

## 補足

- difit のスレッドは head が変わると行番号がずれるため、差分更新はせず `--clean` で作り直している。
  GitHub にあるスレッドは GitHub の行番号で、ローカルにしかないスレッドは snippet の検索で位置を決め直す。
- Viewed の状態は difit のブラウザ側にしか無く API が無いため、同期の対象外である。Viewed は GitHub 上で管理する。
- difit を作り直したくないだけなら `--no-restart` を付ける。GitHub との突き合わせだけを行う。
- **対応要否の判断 (difit 上の返信) は difit にしか無い。** triage を通すまで状態ファイルには残らないため、作り直しで消えると復元できない。
  difit が動いているのにスレッドを 0 件しか取得できないときは、`sync.sh` が中断して返信の消失を防ぐ。
  取得の失敗ではなく本当に 0 件だと確かめたときだけ `--allow-empty-snapshot` を付けて再実行する。
- **local モードでは difit を `difit . origin/<base_ref> --merge-base` で起動する。** 指摘へ対応するたびにコミットしなくても差分へ反映され、
  コミット前に自分で確認できる。worktree モード (他人の PR) は他人の head と base の SHA をそのまま対象にする。
