"""Exercise real loopback transport with synthetic data on an ephemeral test port."""
import json
import socket
import subprocess
import time

with socket.socket() as reservation:
    reservation.bind(('127.0.0.1', 0))
    port = reservation.getsockname()[1]

server = subprocess.Popen(['build/bridge-test-server', str(port)])
try:
    deadline = time.monotonic() + 10
    while True:
        try:
            probe = socket.create_connection(('127.0.0.1', port), timeout=1)
            probe.close()
            break
        except OSError:
            if time.monotonic() > deadline or server.poll() is not None:
                raise
            time.sleep(0.05)

    def request(parts):
        with socket.create_connection(('127.0.0.1', port), timeout=5) as client:
            for part in parts:
                client.sendall(part.encode())
                # Ensure the server sees incomplete headers before the next fragment.
                if len(parts) > 1:
                    time.sleep(0.05)
            response = bytearray()
            while chunk := client.recv(4096):
                response.extend(chunk)
            return bytes(response).split(b'\r\n\r\n', 1)

    header, body = request(['GET /v1/credits HTTP/1.1\r\n', f'Host: 127.0.0.1:{port}\r\n', '\r\n'])
    assert header.startswith(b'HTTP/1.1 200 OK')
    assert json.loads(body)['snapshot']['remaining'] == 3177.5
    for headers in ['Host: evil.example', f'Host: 127.0.0.1:{port}\r\nOrigin: https://example.com']:
        header, body = request([f'GET /v1/credits HTTP/1.1\r\n{headers}\r\n\r\n'])
        assert b'403 Forbidden' in header and not body
    header, body = request([f'GET /wrong HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\n\r\n'])
    assert b'404 Not Found' in header and not body
    header, body = request(['GET /v1/credits HTTP/1.1\r\nX-Large: ' + 'x' * 9000])
    assert b'431 Request Header Fields Too Large' in header and not body
    print('PASS: live loopback transport, fragmented headers, JSON, Host/Origin, size limit')
finally:
    server.terminate()
    server.wait(timeout=5)
