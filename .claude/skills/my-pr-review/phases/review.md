# review: リポジトリ固有のレビュースキルで指摘を出し、difit に投稿する

## 前提

- `session.json` が存在し、difit が起動していること。無ければ `phases/start.md` から。
- `session.json` の `review_skill` にスキル名があること。無ければ start と同じ基準で決める。

## 手順

### 1. レビュー範囲を決める

| 状況 | 範囲 |
| --- | --- |
| 初回、または PR 作者が修正した後 (ケース 1) | `base_sha..head_sha` の PR 全体 |
| ケース 2 で自分が指摘対応のコミットを積んだ後 | `reviewed_head_sha..HEAD` の差分のみ |

`reviewed_head_sha` は前回のレビュー時の head であり、session.json に入っている。null なら初回である。
ケース 2 でコミットを積んだ後は、先に `scripts/sync.sh <state-dir>` を実行して difit と session.json の head を新しい HEAD に合わせる。

### 2. リポジトリ固有のレビュースキルを実行する

Skill ツールでスキルを起動する。スキルは現在のディレクトリを対象にするので、`session.json` の `worktree` と一致していることを先に確認する。
差分のみをレビューさせたい場合は、そのスキルが対応している引数で範囲を渡す
(コミット群やベースコミットを指定する引数を持つスキルが多い)。対応していなければ、
プロンプトで「次のコミット範囲だけを対象にしてください」と明示する。

リポジトリ固有のスキルは多くの開発者が共有しているので、**このスキルの都合で変更しない**。
出力形式が何であれ、次の手順で変換する。

### 3. 指摘を findings JSON に変換する

スキルのレポートを読み、`reference/findings.schema.json` の形式に変換して `<state-dir>/findings-<日時>.json` に書く。

- `file` はリポジトリルートからの相対パス。
- `line` は指摘対象の行。範囲なら `{"start","end"}`。行を特定できない全体的な指摘は、PR 本文や設計に関するものなので difit には投稿せず、ユーザーへの報告に含める。
- `side` は追加・変更行なら `new`、削除された行への指摘なら `old`。
- `perspective` はスキルが使っている観点名をそのまま使う。観点の無いスキルなら指摘の種別 (例: `バグ`、`命名`) を短く付ける。
  再レビュー時に「同じ箇所・同じ観点」を判定する鍵になるので、毎回同じ語を使うことが重要である。
- `summary` は 1 行の要約。`body` は difit に表示する本文で、根拠と修正案を含める。

### 4. 投稿する

```bash
$SKILL_DIR/scripts/difit-post.sh <state-dir> <findings.json>
```

出力の意味:

- `suppressed`: 同じ箇所・同じ観点で過去に判断済みのため投稿しなかった指摘。件数と過去の判断理由をユーザーに伝える。
- `annotated`: 同じ箇所だが観点が違う、または同じ関数内で同じ指摘が別の行に移った。過去の判断を注記して投稿した。
- `posted`: 投稿した件数。

### 5. session.json を更新する

```bash
jq '.reviewed_head_sha = .head_sha' <state-dir>/session.json > /tmp/s.json && mv /tmp/s.json <state-dir>/session.json
```

### 6. 報告

投稿件数、抑止件数、difit の URL を伝える。ユーザーは difit 上で各指摘に対応要否を返信するので、
`reference/reply-convention.md` の書式を一言添える。
