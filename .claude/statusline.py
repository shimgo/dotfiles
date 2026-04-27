#!/usr/bin/env python3
"""Pattern 1: Minimal dots - colored circles with numbers only"""
import json, sys
from datetime import datetime, timezone
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

data = json.load(sys.stdin)

R = '\033[0m'
DIM = '\033[2m'
BOLD = '\033[1m'

def gradient(pct):
    if pct < 50:
        r = int(pct * 5.1)
        return f'\033[38;2;{r};200;80m'
    else:
        g = int(200 - (pct - 50) * 4)
        return f'\033[38;2;255;{max(g, 0)};60m'

def dot(pct):
    p = round(pct)
    return f'{gradient(pct)}●{R} {BOLD}{p}%{R}'

def reset_time(epoch, include_date=False):
    if epoch is None:
        return None
    dt = datetime.fromtimestamp(epoch, tz=timezone.utc).astimezone()
    if include_date:
        return dt.strftime('%m/%d %H:%M')
    return dt.strftime('%H:%M')

groups = []

model = data.get('model', {}).get('display_name', 'Claude')
effort = data.get('effort', {}).get('level')
group_model = [f'{BOLD}{model}{R}']
if effort:
    group_model.append(f'{DIM}{effort}{R}')
groups.append(' '.join(group_model))

group_cost = []
cost = data.get('cost', {}).get('total_cost_usd')
if cost is not None:
    group_cost.append(f'{BOLD}${cost:.2f}{R}')

duration_ms = data.get('cost', {}).get('total_api_duration_ms')
if duration_ms is not None:
    s = duration_ms / 1000
    if s < 60:
        dur = f'{s:.1f}s'
    elif s < 3600:
        dur = f'{int(s // 60)}m{int(s % 60)}s'
    else:
        dur = f'{int(s // 3600)}h{int((s % 3600) // 60)}m'
    group_cost.append(f'{DIM}{dur}{R}')
if group_cost:
    groups.append(' '.join(group_cost))

ctx = data.get('context_window', {}).get('used_percentage')
if ctx is not None:
    groups.append(f'ctx {dot(ctx)}')

five_info = data.get('rate_limits', {}).get('five_hour', {})
five = five_info.get('used_percentage')
if five is not None:
    reset = reset_time(five_info.get('resets_at'))
    label = f'5h {dot(five)}'
    if reset:
        label += f' {DIM}→{reset}{R}'
    groups.append(label)

week_info = data.get('rate_limits', {}).get('seven_day', {})
week = week_info.get('used_percentage')
if week is not None:
    reset = reset_time(week_info.get('resets_at'), include_date=True)
    label = f'7d {dot(week)}'
    if reset:
        label += f' {DIM}→{reset}{R}'
    groups.append(label)

# Stopフック用にコンテキスト使用率と累計コストをファイルに書き出す
if ctx is not None:
    with open('/tmp/claude_ctx_pct.txt', 'w') as f:
        f.write(str(round(ctx)))
if cost is not None:
    with open('/tmp/claude_cost.txt', 'w') as f:
        f.write(f'{cost:.6f}')

print(f'  {DIM}|{R}  '.join(groups), end='')
