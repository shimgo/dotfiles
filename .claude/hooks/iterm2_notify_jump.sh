#!/bin/bash
SESSION_ID="$1"
osascript <<APPLESCRIPT
tell application "iTerm2"
    activate
    repeat with w in windows
        repeat with t in tabs of w
            repeat with s in sessions of t
                if id of s is "$SESSION_ID" then
                    select w
                    tell t to select
                    return
                end if
            end repeat
        end repeat
    end repeat
end tell
APPLESCRIPT
