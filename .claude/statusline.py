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

model = data.get('model', {}).get('display_name', 'Claude')
parts = [f'{BOLD}{model}{R}']

ctx = data.get('context_window', {}).get('used_percentage')
if ctx is not None:
    parts.append(f'ctx {dot(ctx)}')

five_info = data.get('rate_limits', {}).get('five_hour', {})
five = five_info.get('used_percentage')
if five is not None:
    reset = reset_time(five_info.get('resets_at'))
    label = f'5h {dot(five)}'
    if reset:
        label += f' {DIM}→{reset}{R}'
    parts.append(label)

week_info = data.get('rate_limits', {}).get('seven_day', {})
week = week_info.get('used_percentage')
if week is not None:
    reset = reset_time(week_info.get('resets_at'), include_date=True)
    label = f'7d {dot(week)}'
    if reset:
        label += f' {DIM}→{reset}{R}'
    parts.append(label)

print(f'  {DIM}·{R}  '.join(parts), end='')
