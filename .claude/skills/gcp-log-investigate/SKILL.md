---
name: gcp-log-investigate
description: >
  Google Cloud Loggingを使って特定の事象・操作・エラーをgcloud logging readで調査するスキル。
  「GCPのログを調べて」「Cloud Loggingで〇〇を確認して」「proj:xxx のログから〇〇を探して」
  「〇〇のエラーが起きた原因をログから調べて」「〇〇の操作がいつ行われたかログで確認して」
  「ログから〇〇のtraceを追って」といった依頼のときに使用する。
  GCPプロジェクトのログ調査・ログ検索・Cloud Logging調査の依頼があれば積極的に使うこと。
  使用するコマンドは gcloud logging read のみとし、それ以外のコマンドは使用しない。
disable-model-invocation: true
---

# GCP Log 調査スキル

Google Cloud Loggingを `gcloud logging read` コマンドのみで調査し、ユーザーが求める事象・操作・エラーを特定する。

## 基本コマンド形式

```bash
gcloud logging read \
  --project={プロジェクト名} \
  --format=json \
  'SEARCH("`{検索ワード}`")
  AND timestamp>="{開始時刻}"
  AND timestamp<"{終了時刻}"
  AND severity>=DEFAULT'
```

- タイムスタンプは RFC3339 形式（例: `"2026-03-11T00:00:00+09:00"`）
- ログの取得には `gcloud logging read` のみを使用する。結果の解析・絞り込みには `jq`、`grep` 等の読み取り専用ツールを使用してよい
- 複数の検索ワードがある場合は `AND SEARCH(...)` を追加する

## 追加フィルタの例

識別子が判明したら、フィルタに追加して絞り込む：

```
# traceで絞り込む
'SEARCH("`{検索ワード}`")
  AND timestamp>="{開始時刻}"
  AND timestamp<"{終了時刻}"
  AND severity>=DEFAULT
  AND trace="projects/{プロジェクト}/traces/{traceId}"'

# spanIdで絞り込む
'SEARCH("`{検索ワード}`")
  AND timestamp>="{開始時刻}"
  AND timestamp<"{終了時刻}"
  AND severity>=DEFAULT
  AND spanId="{spanId}"'
```

## 調査フロー

### Step 1: ユーザーのリクエストから情報を抽出する

ユーザーのリクエストから以下を抽出する：

| 情報 | 例 | 備考 |
|------|------|------|
| プロジェクト名 | `my-server` | `proj:xxx` や `--project=xxx` で指定されることが多い |
| 検索内容 | `O-1346` | 調べたい事象・ID・エラーメッセージ等 |
| 時間範囲 | `2026/03/01` | 日付のみの場合は 00:00:00〜翌日00:00:00 とする |
| 識別子 | trace, spanId, RequestId等 | 指定されていない場合はStep 2へ |

プロジェクト名が指定されていない場合はユーザーに確認する。

### Step 2: 初回検索（識別子なしの場合）

識別子が指定されていない場合は、まず検索ワードのみで初回検索を実行する。

```bash
gcloud logging read \
  --project={プロジェクト名} \
  --format=json \
  'SEARCH("`{検索ワード}`")
  AND timestamp>="{開始時刻}"
  AND timestamp<"{終了時刻}"
  AND severity>=DEFAULT'
```

### Step 3: 候補IDの抽出と提示

初回検索結果のJSONを解析し、関連する識別子を候補として抽出する。

**抽出すべき識別子の種類：**

- **検索ワードと同じ種別のID** - 例えば "注文" で検索した場合、`OrderID`、`orderId`、`order_id` のようなフィールドに含まれるID
- **trace** - `trace` フィールドの値（例: `projects/my-server/traces/xxxx`）
- **spanId** - `spanId` フィールドの値
- **requestId, correlationId 等** - リクエストやトランザクションを識別するID

**抽出のヒント：**

- 検索ワードが "注文" であれば → `order`, `Order`, `注文` を含むフィールド名を探す
- 検索ワードが "ユーザー" であれば → `user`, `User`, `userId`, `accountId` を含むフィールド名を探す
- 複数の同一traceに紐づくspanIdはそのトレース配下としてグルーピングして提示する
- 各候補にはそのIDが登場したタイムスタンプを付記する

**候補の提示フォーマット：**

```
以下の識別子が見つかりました。絞り込みに使用したい候補を選択してください（複数可）：

【検索ワードと同種のID】
1. O-1346（検索ワードと一致）
2. xxxxx-xxxx-xxx_Order（2026-03-01T10:30:00+09:00、2026-03-01T11:30:00+09:00）
3. xxxxx-xxxx-xxx_FulfillmentOrder（2026-03-01T10:15:00+09:00）

【trace / spanId】
4. trace: projects/my-server/traces/x1（2026-03-01T10:30:00+09:00）
   - spanId: aaa111（2026-03-01T10:30:00+09:00）
   - spanId: bbb222（2026-03-01T10:31:00+09:00）
5. trace: projects/my-server/traces/x2（2026-03-01T11:00:00+09:00）
   - spanId: ccc333（2026-03-01T11:01:00+09:00）
   - spanId: ddd444（2026-03-01T11:02:00+09:00）
```

候補が多い場合は、出現頻度が高いものや時間的に集中しているものを優先して表示する。

### Step 4: 識別子を指定した絞り込み検索

ユーザーが選択した識別子を使って、より絞り込んだ検索を実行する。

traceやspanIdの場合はフィルタに追加する。独自IDの場合はSEARCHに追加する。

```bash
# 例: traceで絞り込み
gcloud logging read \
  --project={プロジェクト名} \
  --format=json \
  'SEARCH("`{検索ワード}`")
  AND timestamp>="{開始時刻}"
  AND timestamp<"{終了時刻}"
  AND severity>=DEFAULT
  AND trace="projects/{プロジェクト}/traces/{traceId}"'
```

### Step 5: 調査結果の報告

調査結果を以下の観点でまとめて報告する：

- **発生した操作・事象の時系列** - タイムスタンプ順に何が起きたか
- **関連するエラー・警告** - severity が ERROR や WARNING のログ
- **重要なフィールド値** - リクエストID、ユーザーID、処理結果等
- **未解明な点・追加調査が必要な点** - さらに絞り込むべき候補があれば提示

**イベントを説明する際は必ず時刻・spanId・traceを併記する。**

また、時系列でイベントを説明する際は、ログに記録されたリクエスト内容（エンドポイント・メソッド・パラメータ等）とコードベースの知識を組み合わせ、**そのリクエストによってどのテーブルのどんなレコードが作成・更新・削除されるか**も説明する。コードベースを参照する場合は、対象のファイルパスと行番号を読み取って根拠として示す。

例：
```
- 2026-03-01T10:30:15+09:00 [trace: projects/my-server/traces/x1 / spanId: aaa111]
  POST /orders リクエストを受信（OrderID: O-1346）
  → orders テーブルに新規レコードが作成される（status: "pending"）

- 2026-03-01T10:30:16+09:00 [trace: projects/my-server/traces/x1 / spanId: bbb222]
  在庫引き当て処理を開始
  → inventory_reservations テーブルに引き当てレコードが挿入される

- 2026-03-01T10:30:17+09:00 [trace: projects/my-server/traces/x1 / spanId: bbb222]
  ERROR: 在庫不足により引き当て失敗
  → inventory_reservations への挿入はロールバック、orders.status は "failed" に更新される
```

コードベースが参照できない・処理内容が不明な場合は「（コードベース未参照）」と付記し、ログから読み取れる情報のみで説明する。

trace や spanId が存在しないログの場合は「trace: なし / spanId: なし」と明記する。

## 注意事項

- **ログ取得は gcloud logging read のみを使用する** - ログ取得に他のコマンドは使わない
- **結果の解析には読み取り専用ツールを使用してよい** - `jq`、`grep` 等でJSONを絞り込んだり整形したりすることは許容される
- ログのJSONはClaudeが読み取って解析するか、jq等で整形して解析する
- 結果が多すぎる場合は `--limit` オプションで件数を制限する（デフォルトは1000件）
- 時間範囲が広すぎてヒット件数が多い場合は、より狭い範囲で再検索を提案する
- 日本標準時（JST, +09:00）で時刻を扱う
