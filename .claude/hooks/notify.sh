#!/bin/bash
INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name')

# cmux環境ならcmux claude-hookで通知、それ以外はiTerm2 + terminal-notifierで通知
# 通知対象はpermission_promptとStopのみ（iTerm2側と揃える）
if [[ -n "$CMUX_BUNDLED_CLI_PATH" ]]; then
  SHOULD_NOTIFY=0
  if [ "$EVENT" = "Notification" ]; then
    NTYPE=$(echo "$INPUT" | jq -r '.notification_type // ""')
    if [ "$NTYPE" = "permission_prompt" ]; then
      SHOULD_NOTIFY=1
    fi
  elif [ "$EVENT" = "Stop" ]; then
    SHOULD_NOTIFY=1
  fi

  if [ "$SHOULD_NOTIFY" = "1" ]; then
    EVENT_LOWER=$(echo "$EVENT" | tr '[:upper:]' '[:lower:]')
    echo "$INPUT" | "$CMUX_BUNDLED_CLI_PATH" claude-hook "$EVENT_LOWER"
  fi
  exit 0
fi

# --- iTerm2 + terminal-notifier ---
# TERM_SESSION_IDはiTerm2が自動設定する環境変数（w0t1p0:UUID 形式）
SESSION_ID="${TERM_SESSION_ID##*:}"

if [ "$EVENT" = "Notification" ]; then
  NTYPE=$(echo "$INPUT" | jq -r '.notification_type // ""')
  if [ "$NTYPE" = "permission_prompt" ]; then
    if [[ -n "$SESSION_ID" ]]; then
      terminal-notifier \
        -title "Claude Code" \
        -message "実行許可の確認が必要です" \
        -sound "Sosumi" \
        -execute "~/.claude/hooks/iterm2_notify_jump.sh '$SESSION_ID'"
    else
      terminal-notifier \
        -title "Claude Code" \
        -message "実行許可の確認が必要です" \
        -sound "Sosumi"
    fi
  fi
elif [ "$EVENT" = "Stop" ]; then
  MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // "タスクが完了しました"' \
    | sed 's/\*\*//g; s/`//g; s/^- //g' \
    | tr '\n' ' ' \
    | cut -c1-80)
  if [[ -n "$SESSION_ID" ]]; then
    terminal-notifier \
      -title "Claude Code" \
      -message "$MESSAGE" \
      -sound "Morse" \
      -execute "~/.claude/hooks/iterm2_notify_jump.sh '$SESSION_ID'"
  else
    terminal-notifier \
      -title "Claude Code" \
      -message "$MESSAGE" \
      -sound "Morse"
  fi
fi
