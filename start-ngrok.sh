#!/usr/bin/env bash
# Public link via ngrok (uses the account's free static dev domain). Requires `ngrok config add-authtoken` done once.
cd "$(dirname "$0")"
pkill -f "ngrok http 8000" 2>/dev/null; sleep 1
nohup ngrok http 8000 --url=https://unbundle-kindling-essential.ngrok-free.dev --log=stdout --log-format=logfmt > ngrok.log 2>&1 &
sleep 6; curl -s http://127.0.0.1:4040/api/tunnels | python3 -c "import sys,json;[print(t['public_url']) for t in json.load(sys.stdin)['tunnels']]"
