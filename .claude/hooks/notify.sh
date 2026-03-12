#!/bin/bash
INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name')

if [ "$EVENT" = "Notification" ]; then
  NTYPE=$(echo "$INPUT" | jq -r '.notification_type // ""')
  if [ "$NTYPE" = "permission_prompt" ]; then
    terminal-notifier -title "Claude Code" -message "実行許可の確認が必要です" -sound "Sosumi"
  fi
elif [ "$EVENT" = "Stop" ]; then
  MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // "タスクが完了しました"' \
    | sed 's/\*\*//g; s/`//g; s/^- //g' \
    | tr '\n' ' ' \
    | cut -c1-80)
  terminal-notifier -title "Claude Code" -message "$MESSAGE" -sound "Morse"
fi
