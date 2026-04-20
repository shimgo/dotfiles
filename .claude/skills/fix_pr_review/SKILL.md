---
name: fix_pr_review
description: >
  現在のブランチのプルリクエストに対する未解決のレビューコメントを取得し、指摘事項を修正するインタラクティブなワークフローを提供するスキル。
  「PRのレビューを修正して」「レビューコメントに対応して」「未解決のレビューを直して」「PRの指摘を修正したい」といった依頼のときに使用する。
  GitHub CLIを使ってGraphQL APIで未解決スレッドを取得し、ユーザーの選択に応じて一括または個別に修正を進める。
  PR修正、レビュー対応、GitHub PRレビューへの対応依頼があれば積極的に使うこと。
---

# PR レビュー修正スキル

現在のブランチに関連するPRの未解決レビューコメントを取得し、ユーザーと対話しながら修正を進める。

## ワークフロー概要

1. PR情報を取得する
2. レビューコメントを3種類すべて取得・表示する（Review thread / Review body / Issue comment）
3. 修正方法をユーザーに確認する（一括 or 個別）
4. 修正を実行する
5. 完了サマリーを提示する

---

## Step 1: PR情報を取得する

```bash
# 現在のブランチ名を取得
git branch --show-current

# 現在のブランチのPR番号とURLを取得
gh pr list --head "$(git branch --show-current)" --json number,url --jq '.[0]'

# リポジトリのowner/nameを取得
gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'
```

PRが見つからない場合は、ユーザーにPR番号を直接尋ねる。

---

## Step 2: レビューコメントを取得する

GitHubのPRには3種類のコメントがある。**必ず3種類すべてを取得する**こと。1種類だけ見ると見逃しが発生する。

| 種類 | フィールド | URL形式 | 解決状態の判定 |
|------|-----------|---------|----------------|
| Review thread (行コメント) | `reviewThreads.nodes` | `#discussion_rXXX` | `isResolved` で機械的に判定 |
| Review body (総評コメント) | `reviews.nodes.body` | `#pullrequestreview-XXX` | 解決の概念なし。bodyが非空なら対応要確認 |
| Issue comment (PR全体コメント) | `comments.nodes.body` | `#issuecomment-XXX` | 解決の概念なし。人のコメントは対応要確認 |

### 1回のクエリで3種類をまとめて取得する

`totalCount`が100を超える場合はページネーション（cursor）で全件取得する。

```bash
gh api graphql -f query='
query {
  repository(owner: "{owner}", name: "{repo}") {
    pullRequest(number: {pr_number}) {
      reviewThreads(first: 100) {
        totalCount
        nodes {
          isResolved
          comments(first: 20) {
            nodes {
              body
              author { login }
              path
              line
              url
            }
          }
        }
      }
      reviews(first: 100) {
        totalCount
        nodes {
          state
          body
          author { login }
          createdAt
          url
        }
      }
      comments(first: 100) {
        totalCount
        nodes {
          body
          author { login }
          createdAt
          url
        }
      }
    }
  }
}'
```

### 取得後の処理

**1. Review thread (行コメント)**
- `isResolved == false` のスレッドのみ抽出
- 各スレッドの全コメントを時系列で表示（最後の発言者の意図を読み取るため）
- 表示項目: コメント原文、コメント者、該当ファイル、該当行番号、URL

**2. Review body (総評コメント)**
- `body`が非空のものを抽出
- PR著者自身のreviewは除外してよい
- ボット（`login`が `[bot]` 終端、`gemini-code-assist`、`vercel`、`dependabot` など）は別枠で表示し、人のコメントと混ぜない
- 解決済みかどうかGitHub側で判別できないため、**全件ユーザーに確認する**
- 表示項目: 本文、author、state（APPROVED/COMMENTED/CHANGES_REQUESTED/DISMISSED）、URL

**3. Issue comment (PR全体コメント)**
- ボット（vercel、gemini-code-assist、CI通知など）は除外または別枠表示
- 人のコメントで、PR著者以外のものを抽出
- 表示項目: 本文、author、URL

### 報告フォーマット

取得後、**3種類を区別して**以下の件数を報告する：

- 総Review thread数、未解決数、取得漏れの有無
- 総Review数、対応要確認のbody数（人のみ）、ボット件数
- 総Issue comment数、対応要確認数（人のみ）、ボット件数

### 終了条件

3種類のいずれにも対応要確認コメントが無い場合のみ「対応すべきコメントはありません」と伝えて終了する。**reviewThreadsだけを見て終了してはいけない**。

---

## Step 3: 修正方法をユーザーに確認する

3種類すべての対応要確認コメントを提示した後、`AskUserQuestionTool`を使って以下の選択肢を提示する：

```
修正方法を選択してください:
  A: すべてのレビューコメントの指摘を一度に修正する
  B: 1つずつ確認しながら修正する
```

---

## Step 3A: すべて一括修正する場合

1. すべてのレビューコメントを分析し、必要な修正を洗い出す
2. 各指摘に対する修正を一度に実行する
3. 修正内容をファイルごとにまとめてユーザーに報告し、確認を求める
4. ユーザーからフィードバックがあれば追加調整する

---

## Step 3B: 1つずつ修正する場合

各コメントに対して以下のサイクルを繰り返す：

1. **コメントを提示する**: コメント詳細と該当コードの現在の状態を表示する
2. **対応方法を確認する**: 以下の選択肢を提示する
   - 修正する
   - スキップして次へ進む
3. **修正を実行する**（「修正する」を選択した場合）:
   - レビューコメントに基づいた修正を実施する
   - 修正内容を提示し「この修正で問題ないですか？」と確認する
   - 問題なければ次のコメントへ進む
   - 修正が必要なフィードバックがあれば追加調整する
4. **スキップする**（「スキップ」を選択した場合）: 次のコメントへ進む

---

## Step 4: 完了サマリーを提示する

すべてのコメント処理が完了したら以下を提示する：

- 修正したファイルの一覧
- 各コメントに対する対応内容のサマリー（修正/スキップ）
- 次のステップの提案（コミット方法など）

> コミットの実行はユーザーの明示的な指示がある場合のみ行う。

---

## 注意事項

- **3種類のコメント（reviewThreads / reviews.body / comments）をすべて取得すること**。`reviewThreads`だけを見ると、レビュー総評（`#pullrequestreview-XXX`）に書かれた設計提案などを見逃す。過去にここで見逃しが発生した。
- レビューコメントの内容を正確に理解し、適切な修正を行う。不明確なコメントはユーザーに確認する。
- 修正が他の部分に影響を与える可能性がある場合は、事前にユーザーに警告する。
- プロジェクトのコーディング規約とコード品質を維持する。
- `git push` は使用しない。
