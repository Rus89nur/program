#!/usr/bin/env python3
"""Локальный dev-сервер для веб-прототипа «Газпром — акты проверок».

Раздаёт статические файлы текущей папки на http://localhost:3000/ и
отключает кэширование, чтобы изменения подхватывались сразу (без необходимости
вручную чистить кэш браузера). Service Worker всё равно может кэшировать —
при проблемах используйте жёсткую перезагрузку (Cmd+Shift+R).
"""

import http.server
import os
import socketserver
import sys

PORT = int(os.environ.get("PORT", "3000"))


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    class ReusableTCPServer(socketserver.TCPServer):
        allow_reuse_address = True

    try:
        with ReusableTCPServer(("", PORT), NoCacheHandler) as httpd:
            print(f"Dev-сервер (без кэша): http://localhost:{PORT}/")
            print("Остановка: Ctrl+C")
            httpd.serve_forever()
    except OSError as exc:
        print(f"Не удалось занять порт {PORT}: {exc}")
        print("Возможно, старый сервер ещё работает. Закройте его (Ctrl+C) и повторите,")
        print(f"или запустите на другом порту: PORT=3001 python3 dev-server.py")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nСервер остановлен.")


if __name__ == "__main__":
    main()
