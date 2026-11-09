#!/usr/bin/env bash
# Keeps Chispa and the ngrok tunnel alive; checks every 30s.
cd "$(dirname "$0")"
while true; do
  if ! curl -s -o /dev/null --max-time 5 http://127.0.0.1:8000/login; then
    nohup ./run-public.sh > server.log 2>&1 &
    sleep 10
  fi
  body=$(curl -s --max-time 15 -w "\n%{http_code}" -H "ngrok-skip-browser-warning: 1" https://unbundle-kindling-essential.ngrok-free.dev/login)
  code=$(echo "$body" | tail -n1)
  if echo "$body" | grep -q "ERR_NGROK_725"; then
    sleep 600; continue
  fi
  if [ "$code" != "200" ]; then
    echo "$(date) tunnel check got $code, restarting ngrok" >> watchdog.log
    ./start-ngrok.sh >> watchdog.log 2>&1
  fi
  sleep 15
done
