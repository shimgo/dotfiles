#!/bin/bash
INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name')

# 起動時のiTerm2セッションIDを取得（TERM_SESSION_IDはiTerm2が自動設定する環境変数）
# w0t1p0:UUID 形式なのでUUID部分のみ抽出
SESSION_ID="${TERM_SESSION_ID##*:}"

# クリック時にジャンプするexecuteオプションを組み立て
# iTerm2 → Settings → General → Magic → Enable Python API をオンにしておく必要がある
if [[ -n "$SESSION_ID" ]]; then
  EXECUTE="-execute \"~/.claude/hooks/iterm2_notify_jump.sh '$SESSION_ID'\""
else
  EXECUTE=""
fi

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
