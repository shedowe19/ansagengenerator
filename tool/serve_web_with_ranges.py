#!/usr/bin/env python3
"""Serve a Flutter web release with HTTP byte-range support.

The web offline-audio adapter intentionally requires 206 range responses so it
can read individual Ogg/Opus clips from the ZIP64 archive without downloading
the complete 467-MB archive.
"""
from __future__ import annotations

import argparse
import os
import re
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class RangeHandler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def __init__(self, *args, directory: str | None = None, **kwargs):
        super().__init__(*args, directory=directory, **kwargs)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Range")
        self.send_header("Access-Control-Max-Age", "600")
        self.end_headers()

    def end_headers(self):
        # The server only binds loopback. CORS keeps the optional Chrome test
        # independent from Flutter's ephemeral test-host port.
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header(
            "Access-Control-Expose-Headers",
            "Content-Range, Accept-Ranges, Content-Length",
        )
        super().end_headers()

    def send_head(self):
        path = self.translate_path(self.path)
        self._remaining = None
        if os.path.isdir(path):
            return super().send_head()
        try:
            file = open(path, "rb")
        except OSError:
            self.send_error(404, "File not found")
            return None
        size = os.fstat(file.fileno()).st_size
        range_header = self.headers.get("Range")
        if not range_header:
            self.send_response(200)
            self.send_header("Content-type", self.guess_type(path))
            self.send_header("Content-Length", str(size))
            self.send_header("Accept-Ranges", "bytes")
            self.end_headers()
            return file
        match = re.fullmatch(r"bytes=(\d*)-(\d*)", range_header.strip())
        if not match:
            file.close()
            self.send_error(416, "Invalid byte range")
            return None
        start_text, end_text = match.groups()
        if not start_text and not end_text:
            file.close()
            self.send_error(416, "Invalid byte range")
            return None
        if start_text:
            start = int(start_text)
            end = int(end_text) if end_text else size - 1
        else:
            length = int(end_text)
            start = max(size - length, 0)
            end = size - 1
        if start >= size or end < start:
            file.close()
            self.send_response(416)
            self.send_header("Content-Range", f"bytes */{size}")
            self.end_headers()
            return None
        end = min(end, size - 1)
        length = end - start + 1
        file.seek(start)
        self._remaining = length
        self.send_response(206)
        self.send_header("Content-type", self.guess_type(path))
        self.send_header("Content-Length", str(length))
        self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Accept-Ranges", "bytes")
        self.end_headers()
        return file

    def copyfile(self, source, outputfile):
        if self._remaining is None:
            return super().copyfile(source, outputfile)
        while self._remaining:
            chunk = source.read(min(64 * 1024, self._remaining))
            if not chunk:
                break
            outputfile.write(chunk)
            self._remaining -= len(chunk)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    directory = str(Path(args.directory).resolve())
    handler = lambda *a, **kw: RangeHandler(*a, directory=directory, **kw)
    server = ThreadingHTTPServer((args.host, args.port), handler)
    print(f"Serving {directory} at http://{args.host}:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
