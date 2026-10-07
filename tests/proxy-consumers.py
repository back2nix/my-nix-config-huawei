#!/usr/bin/env python3
"""Check independent sing-box consumers against local HTTP proxy fixtures.
Usage: python3 tests/proxy-consumers.py CONFIG_JSON SING_BOX_BINARY [VPN_ROUTE_BINARY]
No production service or remote server is used.
"""
import http.server
import json
import os
import re
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
            self.send_header('Content-Length', str(len(label.encode())))
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(label.encode())
            self.close_connection = True

        def log_message(self, *args):
            pass

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def main():
    template = Path(sys.argv[1]).read_text()
    # Numeric SOPS placeholders are unquoted until activation renders secrets.
    template = re.sub(r'"server_port":<SOPS:[^>]+>', '"server_port":1', template)
    config = json.loads(template)
    isp = next(o for o in config['outbounds'] if o['tag'] == 'isp-kazakhstan')
    assert isp['type'] == 'socks' and isp['version'] == '5'
    assert isp['detour'] == 'ssh-astana'
    fixtures = {name: fixture(name) for name in ('usa', 'casino', 'fra', 'kz', 'isp-kz', 'direct')}
    local_rules = [rule for rule in config['route']['rules']
                   if rule.get('outbound') == 'direct-out'
                   and 'http-claude' in rule.get('inbound', [])]
    assert len(local_rules) == 2, local_rules
    ip_rule, domain_rule = local_rules
    assert ip_rule['ip_cidr'] == ['10.0.0.1/32']
    assert domain_rule['override_address'] == '10.0.0.1'
    assert 'casino.local' in domain_rule['domain']
    assert 'domain_suffix' not in domain_rule
    assert all(config['route']['rules'].index(rule) < next(
        i for i, item in enumerate(config['route']['rules']) if item.get('action') == 'resolve')
        for rule in local_rules)
    # Exercise the real routing rules with a loopback fixture instead of requiring
    # production services or adding 10.0.0.1 to the test host.
    for rule in local_rules:
        rule['override_address'] = '127.0.0.1'
    api_port = free_port()
    ports = {}
    for inbound in config['inbounds']:
        inbound['listen_port'] = free_port()
        ports[inbound['tag']] = inbound['listen_port']
    tags = {'ssh-out1': 'usa', 'ssh-out1-via-casino': 'casino', 'ssh-frankfurt': 'fra', 'ssh-astana': 'kz', 'isp-kazakhstan': 'isp-kz'}
    config['outbounds'] = [
        {'type': 'http', 'tag': outbound['tag'], 'server': '127.0.0.1',
         'server_port': fixtures[tags.get(outbound['tag'], 'usa')].server_port}
        if outbound['type'] == 'ssh' or outbound['tag'] in tags else outbound
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

    def expect(inbound, label, url=None, tunnel=False):
        scheme = 'socks5h' if inbound.startswith('socks-') else 'http'
        output = subprocess.check_output([
            'curl', '-fsS', '--noproxy', '', '--max-time', '4',
            '--proxy', f'{scheme}://127.0.0.1:{ports[inbound]}',
            *(['--proxytunnel'] if tunnel else []), url or target], text=True)
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
            expect('socks-telegram', 'kz')
            expect('http-telegram', 'kz')
            for inbound in ip_rule['inbound']:
                for host in ('10.0.0.1', 'casino.local', 'grafana.casino.local'):
                    expect(inbound, 'direct', f'http://{host}:{fixtures["direct"].server_port}/')
                    expect(inbound, 'direct', f'http://{host}:{fixtures["direct"].server_port}/', tunnel=True)
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
            for mode, tag in tags.items():
                api('telegram-select', mode)
                expect('socks-telegram', tag)
                expect('http-telegram', tag)
                expect('http-codex', 'usa')
                if len(sys.argv) >= 4:
                    assert cli('telegram') == tag
                    cli('telegram', tag)
            cli('telegram', 'direct', success=False)
            for browser, default in [('usa', 'usa'), ('fra', 'fra'), ('kz', 'kz')]:
                for mode, tag in [('casino', 'ssh-out1-via-casino'), ('fra', 'ssh-frankfurt'),
                                  ('kz', 'ssh-astana'), ('direct', 'direct-out'), ('usa', 'ssh-out1')]:
                    api('browser-' + browser + '-select', tag)
                    expect('socks-browser-' + browser, mode)
                    expect('http-browser-' + browser, mode)
                    expect('http-codex', 'usa')
                    expect('socks-telegram', 'isp-kz')
                    for other in ('usa', 'fra', 'kz'):
                        if other != browser:
                            expect('socks-browser-' + other, other)
                    if len(sys.argv) >= 4:
                        assert cli('browser-' + browser) == mode
                        cli('browser-' + browser, mode)
                api('browser-' + browser + '-select', {'usa': 'ssh-out1', 'fra': 'ssh-frankfurt', 'kz': 'ssh-astana'}[default])
                cli('browser-' + browser, 'isp-kz', success=False)
            for agent, other, other_route in [('claude', 'codex', 'usa'), ('codex', 'claude', 'isp-kz')]:
                api(agent + '-select', 'isp-kazakhstan')
                expect('http-' + agent, 'isp-kz')
                expect('http-' + other, other_route)
                if len(sys.argv) >= 4:
                    assert cli(agent) == 'isp-kz'
                    cli(agent, 'isp-kz')
            api('codex-select', 'ssh-out1')
            api('claude-select', 'ssh-frankfurt')
            expect('http-claude', 'fra')
            expect('http-codex', 'usa')
            expect('socks-nix', 'usa')
            api('codex-select', 'ssh-astana')
            expect('http-codex', 'kz')
            for inbound in ('http-claude', 'http-codex'):
                expect(inbound, 'direct', f'http://casino.local:{fixtures["direct"].server_port}/')
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
            api('browser-usa-select', 'ssh-frankfurt')
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
            expect('socks-telegram', 'isp-kz')
            expect('socks-browser-usa', 'fra')
            expect('http-browser-usa', 'fra')
            expect('socks-browser-fra', 'fra')
            expect('socks-browser-kz', 'kz')
            print('PASS: local services, independent routes, CLI, agent direct rejection and persisted selectors')
        finally:
            process.terminate()
            process.communicate(timeout=5)
            for server in fixtures.values():
                server.shutdown()
                server.server_close()


if __name__ == '__main__':
    main()
