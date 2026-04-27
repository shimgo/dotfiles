#!/bin/bash
# Stopフック: 所要時間・単発コスト・コンテキスト使用率を表示する
# stdin から session_id を取得（前回 Stop 時点の累計コストをセッション単位で保存するため）
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "unknown"' 2>/dev/null)
prev_file="/tmp/claude_cost_prev_${session_id}.txt"

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

# このターン単発のコストを「現在の累計 - 前回 Stop 時の累計」で計算する
turn_cost=""
cost_now=$(cat /tmp/claude_cost.txt 2>/dev/null)
cost_prev=$(cat "$prev_file" 2>/dev/null)
if [ -n "$cost_now" ]; then
  diff=$(python3 -c "print(f'{max(0.0, ${cost_now} - ${cost_prev:-0}):.4f}')" 2>/dev/null)
  if [ -n "$diff" ]; then
    turn_cost="cost: \$${diff}"
  fi
  printf "%s" "$cost_now" > "$prev_file"
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
[ -n "$turn_cost" ] && parts="$parts | $turn_cost"
[ -n "$ctx" ] && parts="$parts | $ctx"

echo "{\"systemMessage\": \"$parts\"}"
