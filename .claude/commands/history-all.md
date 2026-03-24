~/.claude/history.jsonl を読み込み、セッション一覧を表示してユーザーが選択した会話をresumeするコマンド。

## 手順

1. Bashツールで以下のPythonスクリプトを実行し、セッション一覧を取得する:

```bash
python3 -c "
import json, os, re
from datetime import datetime

with open('$HOME/.claude/history.jsonl') as f:
    lines = [json.loads(l) for l in f]

cwd = os.getcwd()

sessions = {}
for l in lines:
    sid = l.get('sessionId')
    if not sid:
        continue
    if sid not in sessions:
        sessions[sid] = {
            'messages': [],
            'project': l['project'],
            'timestamp': l['timestamp'],
            'sessionId': sid
        }
    sessions[sid]['messages'].append(l['display'])
    sessions[sid]['last_timestamp'] = l['timestamp']

def has_meaningful_message(messages):
    for msg in messages:
        stripped = msg.strip()
        # スラッシュコマンドのみ（引数なし）はスキップ
        if re.match(r'^/\S+$', stripped):
            continue
        if len(stripped) < 3:
            continue
        return True
    return False

def get_topic(messages):
    for msg in messages:
        if re.match(r'^/(clear|resume|model|history|compact)\s*$', msg):
            continue
        if len(msg.strip()) < 3:
            continue
        cleaned = re.sub(r'\s*\[Pasted text #\d+[^\]]*\]', '', msg).strip()
        if re.match(r'^/\S+$', cleaned):
            continue
        m = re.match(r'^/\S+\s+(.+)', cleaned)
        if m:
            return m.group(1)
        if cleaned:
            return cleaned
    return messages[0] if messages else '(empty)'

sorted_sessions = sorted(sessions.values(), key=lambda x: x['last_timestamp'], reverse=True)
sorted_sessions = [s for s in sorted_sessions if has_meaningful_message(s['messages'])]

print('| No. | 日時 | プロジェクト | トピック | セッションID | 場所 |')
print('|-----|------|-------------|---------|-------------|------|')
for i, s in enumerate(sorted_sessions[:10], 1):
    dt = datetime.fromtimestamp(s['last_timestamp']/1000).strftime('%Y-%m-%d %H:%M')
    proj = s['project'].split('/')[-1]
    topic = get_topic(s['messages'])[:60].replace('|', '/')
    sid = s['sessionId']
    here = 'here' if os.path.realpath(s['project']) == os.path.realpath(cwd) else s['project']
    print(f'| {i} | {dt} | {proj} | {topic} | {sid} | {here} |')
"
```

2. 結果をテーブル形式でユーザーに表示する
   - 「場所」列が `here` のセッションは現在のディレクトリからresumeできる
   - それ以外はパスが表示され、そのディレクトリに移動してresumeする必要がある

3. ユーザーに「どの会話をresumeしますか？番号を入力してください」と質問する

4. ユーザーが番号を選択したら:
   - 場所が `here` の場合: `claude --resume <セッションID>` を実行
   - 場所がパスの場合: ユーザーに `cd <パス> && claude --resume <セッションID>` を案内する（このセッション内ではcdできないため）

注意: ユーザーが番号ではなくセッションIDを直接入力した場合も対応すること。
