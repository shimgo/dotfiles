# sync: GitHub の状態を取り込み、difit を作り直す

使う場面:

- ユーザーが GitHub 上でレビューを送信した後
- レビュー依頼者が返信や修正をしてきた後
- ケース 2 で自分がコミットを積み、difit の diff を新しい HEAD に合わせたいとき

GitHub 上のコメント状況が正本になるため、ローカルの状態と difit をそれに合わせる。

## 手順

0. 先に `phases/triage.md` を済ませる。作り直すと、GitHub にあるスレッド (他人のスレッドと、GitHub に投稿した指摘) は GitHub の内容に置き換わり、difit 上で付けた返信は消える。
   GitHub に投稿していない Claude の指摘とユーザー自身のスレッドは、`sync.sh` が返信ごと再投入するので、返信も残る。
   ただし、修正で対象の行が書き換わり位置を特定できなくなったスレッドは再投入しない。ユーザーの発言を含むものは手順 2 の `needs_restore` に出るので、`phases/restore.md` で戻す。

1. 実行する。

```bash
$SKILL_DIR/scripts/sync.sh <state-dir>
```

2. 出力を読み、次を報告する。

- `reconciled`: status が変わったレコード。`resolved` は GitHub 上で解決済みになったもの、`dismissed` はレビュアーが pending から送信までの間に削除したもの (再指摘防止の対象になる)。
- `warnings`: pending review が残っているため判断を保留したものなど。ユーザーが送信を忘れている可能性を伝える。
- `reimported.outdated`: head が変わって位置を特定できなくなった未投稿のスレッド。difit には再投入していない。
  Claude の発言だけのスレッドは、修正で消えた行に対する指摘なら対応済みの可能性が高いので verify で扱う。
- `reimported.needs_restore`: `outdated` のうち、ユーザーの発言 (ユーザーが書いたスレッド、または Claude の指摘へのユーザーの返信) を含むもの。
  このままではユーザーの発言が difit から消えたままになる。`sync.sh` が発言を状態ファイルに残しているので、`phases/restore.md` で位置を決め直して difit に戻す。
  件数と各スレッドの元の行・要約をユーザーに伝え、黙って次のフェーズへ進まない。
- `session.difit.url`: 新しい difit の URL。ポートが変わっていることがあるので必ず伝える。
  起動直後に `difit ready: <URL>` として標準エラーへ出るので、残りの出力を読むより先に、また後続のフェーズに進む前に伝える。

3. `$SKILL_DIR/scripts/phase-done.sh <state-dir> sync` を実行し、`scripts/next.sh` を再実行して `phase` が `wait` でなければ同じターンで続ける。
   `needs_restore` があれば `restore` になるので、`phases/restore.md` でスレッドを戻す。head が変わっていれば `verify` になるので、`phases/verify.md` で指摘箇所の修正を確認する。
   review の手順 1 の中で `sync.sh` を実行した場合も、`needs_restore` があれば review に進む前に `phases/restore.md` を済ませる。

## 補足

- difit のスレッドは head が変わると行番号がずれるため、差分更新はせず `--clean` で作り直している。
  GitHub にあるスレッドは GitHub の行番号で、ローカルにしかないスレッドは snippet の検索で位置を決め直す。
  snippet が複数の行に一致したときの絞り込みは `reference/state.md` の 6 章を参照する。
- GitHub に投稿した指摘は GitHub のスレッドとして取り込み、停止前の difit にあった投稿前のスレッドは再投入しない。
  `from-github` がレコードの `difit_thread_id` を GitHub の id へ置き換えた後も、前の id が状態ファイルの履歴に残るため、
  `rebuild` は投稿前のスレッドを状態ファイルに無いスレッドと取り違えない。
- Viewed の状態は difit のブラウザ側にしか無く API が無いため、同期の対象外である。Viewed は GitHub 上で管理する。
- difit を作り直したくないだけなら `--no-restart` を付ける。GitHub との突き合わせだけを行う。
- **対応要否の判断 (difit 上の返信) は difit にしか無い。** triage を通すまで状態ファイルには残らないため、作り直しで消えると復元できない。
  difit が動いているのにスレッドを 0 件しか取得できないときは、`sync.sh` が中断して返信の消失を防ぐ。
  取得の失敗ではなく本当に 0 件だと確かめたときだけ `--allow-empty-snapshot` を付けて再実行する。
- **local モードでは difit を `difit . origin/<base_ref> --merge-base` で起動する。** difit が作業ツリーの変更を差分に含めるので、
  指摘へ対応するたびにコミットしなくても、コミット前に自分で確認できる。github モード (他人の PR) は head と base の SHA をそのまま対象にする。
- **github モードでは、PR の作者が push した head へ現在のブランチを fast-forward で追従させる。** force push で fast-forward できないとき、
  または未コミットの変更があるときは `sync.sh` が中断する。Claude はブランチを書き換えず、エラーの内容をユーザーに伝える。
