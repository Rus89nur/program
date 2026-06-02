#!/bin/bash
cd "$(dirname "$0")"
echo "Запуск сервера. Откройте в браузере: http://localhost:8080"
echo "Для остановки нажмите Ctrl+C"
python3 -m http.server 8080
