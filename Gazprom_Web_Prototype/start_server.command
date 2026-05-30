#!/bin/bash
cd "$(dirname "$0")"
echo "Сервер: http://localhost:8080/"
echo "Остановка: Ctrl+C"
python3 -m http.server 8080
