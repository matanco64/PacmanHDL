#!/usr/bin/env python3
"""Serve web/site locally: python3 web/serve.py [port]  ->  http://localhost:8000

Pins the MIME types the page needs; on Windows, Python's guess for .js comes
from the registry and is often text/plain, which Web Workers refuse to load.
"""
import functools
import http.server
import os
import sys


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      '.js': 'text/javascript', '.wasm': 'application/wasm', '.html': 'text/html'}


port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
site = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'site')
print('serving %s on http://localhost:%d' % (site, port))
http.server.ThreadingHTTPServer(('127.0.0.1', port), functools.partial(Handler, directory=site)).serve_forever()
