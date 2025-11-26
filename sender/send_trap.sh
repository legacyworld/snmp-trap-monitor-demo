#!/bin/bash

# 環境変数から設定を取得（デフォルト値を設定）
TARGET="${TARGET:-logstash}"
PORT="${PORT:-1062}"
COMMUNITY="${COMMUNITY:-public}"

# --- FAKE_IP の自動取得 ---
# 環境変数で指定がなければコンテナのIPを取得
if [ -z "$FAKE_IP" ]; then
  FAKE_IP=$(hostname -i 2>/dev/null | awk '{print $1}')
fi
FAKE_IP="${FAKE_IP:-0.0.0.0}"

# --- SWITCH_NAME の自動生成 ---
# IPアドレスの最後のオクテット（例: 172.18.0.5 -> 5）を取得
# ${FAKE_IP##*.} は「最後のドット(.)までを削除する」という意味
IP_SUFFIX="${FAKE_IP##*.}"

# 環境変数 SWITCH_NAME があればそれをプレフィックスに、なければ "Switch" を使用
BASE_NAME="${SWITCH_NAME:-Switch}"
echo $BASE_NAME

# 最終的な名前を組み立てる (例: Switch-5)
FINAL_SWITCH_NAME="${BASE_NAME}-${IP_SUFFIX}"

echo "Waiting for Logstash..."
sleep 20

echo "Starting SNMP Heartbeat Sender for $FINAL_SWITCH_NAME ($FAKE_IP)..."

while true
do
  echo "--- Sending Heartbeat from $FINAL_SWITCH_NAME ---"

  # 現在時刻
  CURRENT_TIME=$(date "+%H:%M:%S")

  # メッセージ作成
  MESSAGE="System Status: Normal (Keepalive) from $FINAL_SWITCH_NAME ($FAKE_IP)"

  # SNMP TRAP送信
  snmptrap -v 2c -c "$COMMUNITY" "$TARGET:$PORT" "" \
   .1.3.6.1.4.1.8072.2.3.0.1 \
   .1.3.6.1.4.1.8072.2.3.2.2 s "$MESSAGE"

  echo "--- Sent. Waiting 60s for next heartbeat. ---"

  # 60秒間隔で送信
  sleep 60
done
