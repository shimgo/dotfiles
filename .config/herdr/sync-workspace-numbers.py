#!/usr/bin/env python3
"""herdrのワークスペース番号をサイドバー表示用のメタデータへ同期する。

herdrのサイドバーには番号を表示する組み込みトークンが存在しないため、
APIが返すworkspaceのnumberをworkspace.report_metadataでnumトークンとして
報告し、config.tomlの[ui.sidebar.spaces]から$numとして描画する。

報告したメタデータはサーバーに永続化されず、ワークスペースの増減や
並び替えでnumberも振り直されるため、--watchではイベントを購読して
変化のたびに再同期する。

switch_workspaceのバインドはctrl+alt+1..9で9番までしか到達しないため、
10番以降にはトークンを付けず、付いている場合は消去する。
"""

from __future__ import annotations

import argparse
import json
import os
import socket
import sys
import time

SOURCE = "workspace-number"
TOKEN_NAME = "num"

# switch_workspace = "ctrl+alt+1..9" で到達できる上限。
MAX_INDEXED = 9

# 番号が変化しうるイベントのみ購読する。
# workspace.metadata_updated は本スクリプト自身の報告でも発火するため、
# 購読すると同期が際限なく繰り返される。含めてはならない。
SUBSCRIPTIONS = (
    "workspace.created",
    "workspace.closed",
    "workspace.moved",
    "workspace.reordered",
)

REQUEST_TIMEOUT_SECONDS = 5.0
RECONNECT_DELAY_SECONDS = 2.0


def socket_path() -> str:
    return os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser(
        "~/.config/herdr/herdr.sock"
    )


def connect(timeout: float | None) -> socket.socket:
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.settimeout(timeout)
    client.connect(socket_path())
    return client


def call(method: str, params: dict) -> dict:
    """短命の接続でリクエストを1件送り、レスポンスを返す。"""
    payload = {"id": f"{SOURCE}:{method}", "method": method, "params": params}
    with connect(REQUEST_TIMEOUT_SECONDS) as client:
        stream = client.makefile("rwb")
        stream.write((json.dumps(payload) + "\n").encode())
        stream.flush()
        line = stream.readline()
    if not line:
        raise ConnectionError(f"{method} への応答がありません")
    response = json.loads(line)
    error = response.get("error")
    if error:
        raise RuntimeError(f"{method} が失敗しました: {error}")
    return response


def sync() -> int:
    """全ワークスペースのnumトークンを現在のnumberに合わせる。"""
    workspaces = (call("workspace.list", {}).get("result") or {}).get("workspaces") or []
    for workspace in workspaces:
        workspace_id = workspace.get("workspace_id")
        number = workspace.get("number")
        if not workspace_id or not isinstance(number, int):
            continue
        value = str(number) if 1 <= number <= MAX_INDEXED else None
        call(
            "workspace.report_metadata",
            {
                "workspace_id": workspace_id,
                "source": SOURCE,
                "tokens": {TOKEN_NAME: value},
                "seq": time.time_ns(),
            },
        )
    return len(workspaces)


def watch() -> None:
    """イベントを購読し、ワークスペースの構成が変わるたびに同期する。"""
    subscriptions = [{"type": name} for name in SUBSCRIPTIONS]
    # herdrサーバーの停止中は再接続に失敗し続けるため、同じ内容のエラーは
    # 1度しか出力しない。常駐させたときにログが際限なく増えるのを防ぐ。
    last_error: str | None = None
    while True:
        try:
            with connect(None) as client:
                stream = client.makefile("rwb")
                stream.write(
                    (
                        json.dumps(
                            {
                                "id": f"{SOURCE}:subscribe",
                                "method": "events.subscribe",
                                "params": {"subscriptions": subscriptions},
                            }
                        )
                        + "\n"
                    ).encode()
                )
                stream.flush()
                # サーバー再起動でメタデータは失われるため、接続直後に必ず同期する。
                sync()
                last_error = None
                while True:
                    line = stream.readline()
                    if not line:
                        break
                    try:
                        incoming = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    # events.subscribe自体の応答にはidが付き、eventは含まれない。
                    if incoming.get("event"):
                        sync()
        except (OSError, ConnectionError, RuntimeError) as error:
            description = str(error)
            if description != last_error:
                print(f"herdrへの接続が切れました: {description}", file=sys.stderr)
                last_error = description
        time.sleep(RECONNECT_DELAY_SECONDS)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--watch",
        action="store_true",
        help="イベントを購読し、ワークスペースの構成変化に追従し続ける",
    )
    args = parser.parse_args()

    if args.watch:
        watch()
        return 0

    try:
        count = sync()
    except (OSError, ConnectionError, RuntimeError) as error:
        print(f"同期に失敗しました: {error}", file=sys.stderr)
        return 1
    print(f"{count}件のワークスペースに番号を設定しました")
    return 0


if __name__ == "__main__":
    sys.exit(main())
