#!/usr/bin/env python3
"""scoreboard/server.py -- serve the CTF scoreboard on localhost.

Standard-library only. Binds to 127.0.0.1 (never 0.0.0.0) and auto-selects the
first free TCP port starting at 8888. Serves the static files in this directory,
including the public flags.json (questions + SHA-256 hashes only).

Usage:  python server.py [--port N] [--no-browser]

Security note: this server has NO authentication by design; it is a personal,
local-only lab aid. Do not change the bind address to expose it on a network.
"""
import argparse
import http.server
import os
import socket
import webbrowser
from functools import partial

HOST = "127.0.0.1"
DEFAULT_PORT = 8888
MAX_PORT_SCAN = 50
HERE = os.path.dirname(os.path.abspath(__file__))


def find_free_port(start: int, host: str = HOST) -> int:
    """Return the first bindable port at/after `start` on `host`."""
    for port in range(start, start + MAX_PORT_SCAN):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                s.bind((host, port))
                return port
            except OSError:
                continue
    raise SystemExit(f"No free port found in {start}..{start + MAX_PORT_SCAN}")


class Handler(http.server.SimpleHTTPRequestHandler):
    """Static handler rooted at the scoreboard directory, with no-cache headers."""

    def end_headers(self):
        # never cache flags.json / app assets so edits show up immediately
        self.send_header("Cache-Control", "no-store, must-revalidate")
        super().end_headers()

    def log_message(self, fmt, *args):  # quieter console
        pass


def main() -> int:
    ap = argparse.ArgumentParser(description="CTF scoreboard (localhost by default).")
    ap.add_argument("--port", type=int, default=DEFAULT_PORT,
                    help=f"preferred port (default {DEFAULT_PORT}; scans upward if busy)")
    ap.add_argument("--host", default=HOST,
                    help=f"bind address (default {HOST}). Use your Tailscale IP (100.x.y.z) to "
                         f"reach it from another tailnet device; avoid 0.0.0.0 on untrusted networks.")
    ap.add_argument("--no-browser", action="store_true", help="don't open a browser")
    args = ap.parse_args()

    if not os.path.exists(os.path.join(HERE, "flags.json")):
        print("[scoreboard] flags.json missing — run 'python generate.py' first.")

    if args.host not in ("127.0.0.1", "localhost"):
        print(f"[scoreboard] WARNING: binding to {args.host} — this exposes the (unauthenticated) "
              f"scoreboard beyond localhost. Only do this on a trusted/private network (e.g. a tailnet).")

    port = find_free_port(args.port, args.host)
    url = f"http://{args.host}:{port}/"
    handler = partial(Handler, directory=HERE)

    with http.server.ThreadingHTTPServer((args.host, port), handler) as httpd:
        print(f"[scoreboard] serving {HERE}")
        print(f"[scoreboard] open {url}  (Ctrl+C to stop)")
        if not args.no_browser:
            try:
                webbrowser.open(url)
            except Exception:
                pass
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n[scoreboard] stopped.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
