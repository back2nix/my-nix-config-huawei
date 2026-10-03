#!/usr/bin/env python3
"""Check independent sing-box consumers against local HTTP proxy fixtures.
Usage: python3 tests/proxy-consumers.py CONFIG_JSON SING_BOX_BINARY [VPN_ROUTE_BINARY]
No production service or remote server is used.
"""
import http.server
import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path


def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def fixture(label):
    class Handler(http.server.BaseHTTPRequestHandler):
        def do_CONNECT(self):
            self.send_response(200)
            self.end_headers()
            while self.rfile.readline().strip():
                pass
            body = label.encode()
            self.wfile.write(b'HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: '
                             + str(len(body)).encode() + b'\r\n\r\n' + body)
            self.wfile.flush()
            self.close_connection = True

        def do_GET(self):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(label.encode())

        def log_message(self, *args):
            pass

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def main():
    config = json.loads(Path(sys.argv[1]).read_text())
    fixtures = {name: fixture(name) for name in ('usa', 'casino', 'fra', 'kz', 'direct')}
    api_port = free_port()
    ports = {}
    for inbound in config['inbounds']:
        inbound['listen_port'] = free_port()
        ports[inbound['tag']] = inbound['listen_port']
    tags = {'ssh-out1': 'usa', 'ssh-out1-via-casino': 'casino', 'ssh-frankfurt': 'fra', 'ssh-astana': 'kz'}
    config['outbounds'] = [
        {'type': 'http', 'tag': outbound['tag'], 'server': '127.0.0.1',
         'server_port': fixtures[tags.get(outbound['tag'], 'usa')].server_port}
        if outbound['type'] == 'ssh' else outbound
        for outbound in config['outbounds']
    ]
    config['experimental']['clash_api']['external_controller'] = f'127.0.0.1:{api_port}'
    config['log']['level'] = 'error'
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    base = f'http://127.0.0.1:{api_port}/proxies/'
    target = f'http://127.0.0.1:{fixtures["direct"].server_port}/'

    def api(selector, tag=None):
        req = urllib.request.Request(base + selector)
        if tag is not None:
            req = urllib.request.Request(base + selector, method='PUT',
                                         data=json.dumps({'name': tag}).encode(),
                                         headers={'Content-Type': 'application/json'})
        with opener.open(req, timeout=2) as response:
            return response.read()

    def cli(group, mode=None, success=True):
        if len(sys.argv) < 4:
            return
        env = dict(os.environ, VPN_ROUTE_API=f'http://127.0.0.1:{api_port}',
                   HTTP_PROXY='http://127.0.0.1:1', HTTPS_PROXY='http://127.0.0.1:1')
        args = [sys.argv[3], group] + ([] if mode is None else [mode])
        result = subprocess.run(args, env=env, text=True, capture_output=True)
        assert (result.returncode == 0) == success, (args, result.stderr)
        return result.stdout.strip()

    def expect(inbound, label):
        scheme = 'socks5h' if inbound.startswith('socks-') else 'http'
        output = subprocess.check_output([
            'curl', '-fsS', '--noproxy', '', '--max-time', '4',
            '--proxy', f'{scheme}://127.0.0.1:{ports[inbound]}', target], text=True)
        assert output == label, (inbound, output, label)

    with tempfile.TemporaryDirectory() as tmp:
        config['experimental']['cache_file']['path'] = str(Path(tmp) / 'cache.db')
        path = Path(tmp) / 'config.json'
        path.write_text(json.dumps(config))
        subprocess.run([sys.argv[2], 'check', '-c', str(path)], check=True)
        process = subprocess.Popen([sys.argv[2], 'run', '-c', str(path)],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        try:
            for _ in range(100):
                try:
                    api('claude-select')
                    break
                except (OSError, urllib.error.URLError):
                    time.sleep(0.02)
            else:
                raise RuntimeError('Test sing-box did not start')
            # Defaults and independent browser profiles.
            expect('http-claude', 'kz')
            expect('http-codex', 'usa')
            expect('socks-nix', 'usa')
            for route in ('usa', 'casino', 'fra', 'kz'):
                expect('socks-browser-' + route, route)
                expect('http-browser-' + route, route)
            if len(sys.argv) >= 4:
                assert cli('claude') == 'kz'
                assert cli('codex') == 'usa'
                cli('claude', 'usa-casino')
                expect('http-claude', 'casino')
                expect('http-codex', 'usa')
                for agent in ('claude', 'codex'):
                    cli(agent, 'direct', success=False)
                cli('unknown', 'usa', success=False)
            api('claude-select', 'ssh-frankfurt')
            expect('http-claude', 'fra')
            expect('http-codex', 'usa')
            expect('socks-nix', 'usa')
            api('codex-select', 'ssh-astana')
            expect('http-codex', 'kz')
            expect('http-claude', 'fra')
            for mode, tag in [('casino', 'ssh-out1-via-casino'), ('fra', 'ssh-frankfurt'), ('kz', 'ssh-astana'),
                              ('direct', 'direct-out'), ('usa', 'ssh-out1')]:
                api('nix-select', tag)
                expect('socks-nix', mode)
                expect('http-claude', 'fra')
                expect('http-codex', 'kz')
            api('usa-select', 'direct-out')
            expect('http-claude', 'fra')
            expect('http-codex', 'kz')
            expect('socks-nix', 'usa')
            for route in ('usa', 'casino', 'fra', 'kz'):
                expect('socks-browser-' + route, route)
            for agent in ('claude', 'codex'):
                try:
                    api(agent + '-select', 'direct-out')
                except urllib.error.HTTPError:
                    pass
                else:
                    raise AssertionError('Agent selector accepted direct-out')
            process.terminate()
            process.communicate(timeout=5)
            process = subprocess.Popen([sys.argv[2], 'run', '-c', str(path)],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            for _ in range(100):
                try:
                    api('claude-select')
                    break
                except (OSError, urllib.error.URLError):
                    time.sleep(0.02)
            else:
                raise RuntimeError('Test sing-box did not restart')
            expect('http-claude', 'fra')
            expect('http-codex', 'kz')
            expect('socks-nix', 'usa')
            print('PASS: independent routes, CLI, agent direct rejection and persisted selectors')
        finally:
            process.terminate()
            process.communicate(timeout=5)
            for server in fixtures.values():
                server.shutdown()
                server.server_close()


if __name__ == '__main__':
    main()
