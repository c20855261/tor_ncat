#!/bin/bash

# 用法: ./${script_name}.sh <容器數> [up|down]
NUM_CONTAINERS=$1
ACTION=${2:-up}

# 檢查參數合法性
if ! [[ "$NUM_CONTAINERS" =~ ^[1-9][0-9]*$ ]]; then
  echo "請輸入正整數作為容器數"
  exit 1
fi

BASE_IDX=1
TORRC_FILE="torrc1"
STRESS_SCRIPT="stress-test.sh"
PROXY_FILE="proxychains4.conf"

# 產生 docker-compose.yml
cat > docker-compose.yml <<EOF
version: '3.8'
services:
EOF

for ((i=0; i<$NUM_CONTAINERS; i++)); do
  IDX=$((BASE_IDX + i))
  NET_NAME="tor_net$IDX"
cat >> docker-compose.yml <<EOF
  tor$IDX:
    image: tor-ncat:v1
    container_name: tor$IDX
    volumes:
      - ./$TORRC_FILE:/etc/tor/torrc
      - ./$STRESS_SCRIPT:/opt/stress-test.sh
      - ./$PROXY_FILE:/etc/proxychains4.conf
    networks:
      - $NET_NAME
    deploy:
      resources:
        limits:
          cpus: '0.6'
          memory: 256M
    restart: always
    entrypoint: ["bash", "/opt/stress-test.sh"]

EOF
done

cat >> docker-compose.yml <<EOF
networks:
EOF

for ((i=0; i<$NUM_CONTAINERS; i++)); do
  IDX=$((BASE_IDX + i))
  NET_NAME="tor_net$IDX"
cat >> docker-compose.yml <<EOF
  $NET_NAME:
    driver: bridge
EOF
done

echo "docker-compose.yml 已產生，共 $NUM_CONTAINERS 個容器"

# up/down 容器
if [ "$ACTION" == "up" ]; then
  echo "執行 docker-compose up -d"
  docker-compose up -d
elif [ "$ACTION" == "down" ]; then
  echo "執行 docker-compose down"
  docker-compose down
fi
