#!/bin/bash
cd "$(dirname "$0")"
chmod +x dev-server.py 2>/dev/null
echo "Dev-сервер (без кэша): http://localhost:3000/"
echo "Остановка: Ctrl+C"
python3 dev-server.py
