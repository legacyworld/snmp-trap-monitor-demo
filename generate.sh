#!/bin/bash

# 設定
OUTPUT_FILE="docker-compose.yml"
SWITCH_COUNT=10
# IPアドレスの衝突(ゲートウェイ .1 等)を避けるため、開始番号をずらす
START_OFFSET=10 
# 使用するサブネット
SUBNET_PREFIX="172.25.0"

echo "Generating $OUTPUT_FILE with $SWITCH_COUNT switch containers (Static IPs)..."

# ---------------------------------------------------------
# 1. ヘッダー部分
# ---------------------------------------------------------
cat > $OUTPUT_FILE <<EOF
services:
  setup-mibs:
    image: alpine:latest
    container_name: snmp_setup
    command: >
      sh -c "apk add --no-cache net-snmp-tools &&
             mkdir -p /shared-mibs &&
             cp -r /usr/share/snmp/mibs/* /shared-mibs/ &&
             chown -R 1000:1000 /shared-mibs"
    volumes:
      - mib-data:/shared-mibs
    networks:
      - snmp-net

  logstash:
    image: docker.elastic.co/logstash/logstash:9.2.1
    container_name: snmp_logstash
    ports:
      - "1062:1062/udp"
      - "9600:9600"
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline
      - mib-data:/usr/share/logstash/vendor/mibs
    networks:
      snmp-net:
        # Logstashにも固定IPを振っておくと分かりやすい（必須ではない）
        ipv4_address: ${SUBNET_PREFIX}.5
    depends_on:
      - setup-mibs

EOF

# ---------------------------------------------------------
# 2. スイッチ定義をループで追記 (固定IP設定を追加)
# ---------------------------------------------------------
for i in $(seq 1 $SWITCH_COUNT); do
  # 番号を計算 (例: i=1 -> NUM=11)
  NUM=$((START_OFFSET + i))
  
  # コンテナ名とIPアドレスの末尾を一致させる
  # 例: switch-11
  SERVICE_NAME="switch-${NUM}"
  # 例: 172.25.0.11
  FIXED_IP="${SUBNET_PREFIX}.${NUM}"

  cat >> $OUTPUT_FILE <<EOF
  $SERVICE_NAME:
    image: snmp-sender-local
    build: ./sender
    container_name: $SERVICE_NAME
    hostname: $SERVICE_NAME
    environment:
      - TARGET=logstash
      - PORT=1062
      - COMMUNITY=public
      # ここで明示的に渡しても良いですが、前回のスクリプトの自動取得に任せてもOK
      - SWITCH_NAME=Switch
    networks:
      snmp-net:
        ipv4_address: $FIXED_IP
    depends_on:
      - logstash
    restart: unless-stopped

EOF
done

# ---------------------------------------------------------
# 3. フッター部分 (Network定義にIPAMを追加)
# ---------------------------------------------------------
cat >> $OUTPUT_FILE <<EOF
networks:
  snmp-net:
    driver: bridge
    ipam:
      config:
        - subnet: ${SUBNET_PREFIX}.0/16

volumes:
  mib-data:
EOF

echo "Done! Created $OUTPUT_FILE"
echo "  - Subnet: ${SUBNET_PREFIX}.0/16"
echo "  - Logstash IP: ${SUBNET_PREFIX}.5"
echo "  - Switches start from: ${SUBNET_PREFIX}.$((START_OFFSET + 1))"
