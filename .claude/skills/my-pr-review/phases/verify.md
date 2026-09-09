# verify: 指摘が修正されたかを確認し、resolve する

使う場面: ケース 1 で PR 作者が修正を push し、`phases/sync.md` を実行した後。

## 手順

1. 対象を列挙する。

```bash
python3 $SKILL_DIR/scripts/state.py latest --state <state-dir>/threads.jsonl --status posted
```

GitHub に投稿済みで未解決の指摘が出る。`outdated` も対象に含める (修正で行が消えた可能性がある)。

```bash
python3 $SKILL_DIR/scripts/state.py latest --state <state-dir>/threads.jsonl --status outdated
```

2. 各指摘について、worktree の現在のコードと `git -C <worktree> diff <前回の head_sha>..HEAD -- <file>` を読み、
   指摘の趣旨が満たされているかを判断する。`summary` と `body` に指摘内容がある。
   PR 作者が GitHub 上で返信していれば `difit-fetch.sh --raw` で本文を読み、反論に妥当性があるかも判断する。

3. 判断ごとに扱いを分ける。

| 判断 | 扱い |
| --- | --- |
| 修正されている | GitHub に投稿済みなら `github-resolve.sh` で resolve する (状態は `resolved` になる)。未投稿の `outdated` は `set-status --status resolved --reason "<修正コミット>"` だけを行う。difit 上にスレッドが残っていれば `difit comment resolve` で消す |
| 修正されていない | 何もしない。未対応であることを報告に含める |
| 作者の反論が妥当で対応不要 | ユーザーの判断を仰ぐ。ユーザーが同意したら resolve し、`set-status --reason` で理由を残す |

```bash
$SKILL_DIR/scripts/github-resolve.sh <state-dir> <github_thread_id>...
difit comment resolve <difit_thread_id>... --port <port>
```

4. 修正内容そのものに新たな問題がないかは `phases/review.md` で再レビューする。再指摘防止リストが効くので、
   過去に不要とした指摘は抑止され、修正で変わった箇所だけが新たに指摘される。

5. resolve した件数、未対応の一覧、ユーザーの判断を要するものを報告する。
