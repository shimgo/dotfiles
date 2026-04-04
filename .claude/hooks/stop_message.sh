#!/bin/bash
# Stopフック: 所要時間とコンテキスト使用率を表示する
# 所要時間を計算する
start=$(cat /tmp/claude_task_start.txt 2>/dev/null)
now=$(date +%s)
duration=""
if [ -n "$start" ]; then
  elapsed=$((now - start))
  min=$((elapsed / 60))
  sec=$((elapsed % 60))
  duration="所要時間: ${min}分${sec}秒"
fi

# ステータスラインが書き出したコンテキスト使用率を読み取る
ctx=""
ctx_pct=$(cat /tmp/claude_ctx_pct.txt 2>/dev/null)
if [ -n "$ctx_pct" ]; then
  ctx="ctx: ${ctx_pct}%"
fi

# メッセージを組み立てる
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
parts="$timestamp"
[ -n "$duration" ] && parts="$parts | $duration"
[ -n "$ctx" ] && parts="$parts | $ctx"

echo "{\"systemMessage\": \"$parts\"}"
