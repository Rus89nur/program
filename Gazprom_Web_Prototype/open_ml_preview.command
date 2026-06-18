#!/bin/bash
cd "$(dirname "$0")"
PORT=3000
if ! curl -s -o /dev/null "http://127.0.0.1:${PORT}/" 2>/dev/null; then
  echo "Запуск dev-сервера на порту ${PORT}…"
  python3 dev-server.py &
  sleep 1
fi
open "http://localhost:${PORT}/ml-training-preview.html"
