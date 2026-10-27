#!/usr/bin/env python3
"""
DSD-8 Dashboard Server (run_dashboard.py)
Launches local web server for the interactive DSD-8 Processor Architecture & Verification Dashboard.
"""

import os
import sys
import webbrowser
import subprocess
import json
from http.server import SimpleHTTPRequestHandler, HTTPServer
import socket

PORT = 8080
WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web")

class DSD8DashboardHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def do_GET(self):
        if self.path == "/api/run_tests":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            
            # Execute python scripts/run_all.py
            cmd = [sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "scripts", "run_all.py")]
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            
            data = {
                "success": (res.returncode == 0),
                "stdout": res.stdout,
                "stderr": res.stderr
            }
            self.wfile.write(json.dumps(data).encode("utf-8"))
            return
        
        return super().do_GET()

def is_port_in_use(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('localhost', port)) == 0

def main():
    global PORT
    while is_port_in_use(PORT):
        PORT += 1

    server = HTTPServer(("localhost", PORT), DSD8DashboardHandler)
    url = f"http://localhost:{PORT}"
    print("=" * 70)
    print("     DSD-8 MICROPROCESSOR ARCHITECTURE & VERIFICATION DASHBOARD      ")
    print("=" * 70)
    print(f"Server started at: {url}")
    print("Press Ctrl+C to stop the dashboard server.")
    print("=" * 70)

    try:
        webbrowser.open(url)
    except Exception:
        pass

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping dashboard server...")
        server.server_close()

if __name__ == "__main__":
    main()
