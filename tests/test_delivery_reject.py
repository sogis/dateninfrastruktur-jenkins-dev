"""Run the CSV job with published GRETL and a loopback OAuth/Delivery endpoint."""
import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory
from threading import Thread
import unittest
from uuid import uuid4


class RejectTest(unittest.TestCase):
    def exercise(self, unavailable=False):
        calls = []
        submission = uuid4()

        class Handler(BaseHTTPRequestHandler):
            def respond(self, status, body=b'', media_type='application/json'):
                self.send_response(status)
                self.send_header('Content-Type', media_type)
                self.end_headers()
                self.wfile.write(body)

            def do_POST(self):
                self.rfile.read(int(self.headers.get('Content-Length', '0')))
                auth = self.headers.get('Authorization')
                calls.append((self.path, auth if self.path != '/token' else None))
                if self.path == '/token':
                    second = sum(path == '/token' for path, _ in calls) > 1
                    if second and unavailable:
                        self.respond(503)
                    else:
                        token = 'probe-fresh-token' if second else 'probe-start-token'
                        self.respond(200, json.dumps({'access_token': token, 'token_type': 'Bearer'}).encode())
                elif self.path == f'/{submission}/start' and auth == 'Bearer probe-start-token':
                    self.respond(200, b'{"mode":"replace","schemaModelName":"Probe",'
                                      b'"baseCsvKey":null,"candidatePrefix":"unused/","columns":[]}')
                elif self.path == f'/{submission}/reject' and auth == 'Bearer probe-fresh-token':
                    self.respond(200, b'{}')
                else:
                    self.respond(401)

            def do_GET(self):
                calls.append((self.path, self.headers.get('Authorization')))
                self.respond(200, b'INTERLIS 2.4;\nMODEL Probe (en) AT "https://example.test" VERSION "1" =\n'
                                  b'TOPIC Snapshot = CLASS Row = code : MANDATORY 0 .. 100;\n'
                                  b'UNIQUE code; END Row; END Snapshot; END Probe.\n', 'text/plain')

            def log_message(self, *_):
                pass

        with TemporaryDirectory() as directory, HTTPServer(('127.0.0.1', 0), Handler) as server:
            thread = Thread(target=server.serve_forever)
            thread.start()
            try:
                root = Path(directory)
                (root / 'input.csv').write_text('code\n7\n7\ninvalid\n')
                endpoint = f'http://127.0.0.1:{server.server_port}'
                params = dict(submissionId=str(submission), inputFile='input.csv', adminUrl=endpoint,
                              tokenUrl=endpoint + '/token', localHttp='true', s3Endpoint=endpoint,
                              s3AccessKey='unused', clickhouseUrl=endpoint, clickhouseUser='unused')
                (root / 'params.json').write_text(json.dumps(params))
                (root / 'oauth').write_text('probe-oauth-secret')
                (root / 'runtime.json').write_text(json.dumps({
                    'schemaVersion': 1, 'secrets': {'oauthClientSecret': {'file': 'oauth'}},
                }))
                job = Path(__file__).resolve().parents[1] / 'jobs/csv-delivery/job.groovy'
                result = subprocess.run([GRETL, 'run', str(job), '--params-file', 'params.json',
                                         '--config', 'runtime.json', '--work-dir', 'work', '--report', 'run.json'],
                                        cwd=root, capture_output=True, timeout=60)
                for secret in (b'probe-oauth-secret', b'probe-start-token', b'probe-fresh-token'):
                    self.assertNotIn(secret, result.stdout)
                    self.assertNotIn(secret, result.stderr)
                self.assertTrue((root / 'run.json').is_file(), result.stderr.decode())
                report = (root / 'run.json').read_bytes()
                for secret in (b'probe-oauth-secret', b'probe-start-token', b'probe-fresh-token'):
                    self.assertNotIn(secret, report)
                tasks = {task['taskId']: task['status'] for task in json.loads(report)['execution']['tasks']}
                self.assertEqual(tasks['validate'], 'SUCCEEDED')
                self.assertNotEqual(tasks['authorizeComplete'], 'SUCCEEDED')
                expected = [('/token', None), (f'/{submission}/start', 'Bearer probe-start-token'),
                            (f'/{submission}/model.ili', 'Bearer probe-start-token'), ('/token', None)]
                if unavailable:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(tasks['authorizeReject'], 'FAILED')
                else:
                    self.assertEqual(result.returncode, 0)
                    self.assertEqual(tasks['reject'], 'SUCCEEDED')
                    expected.append((f'/{submission}/reject', 'Bearer probe-fresh-token'))
                self.assertEqual(calls, expected)
                log = (root / 'validation.log').read_text()
                self.assertIn('is not a number in attribute code', log)
                self.assertIn('Unique constraint Probe.Snapshot.Row.Constraint1 is violated!', log)
            finally:
                server.shutdown()
                thread.join()

    def test_reject_uses_fresh_token(self):
        self.exercise()

    def test_reject_token_failure(self):
        self.exercise(unavailable=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('gretl', type=lambda value: str(Path(value).resolve()))
    GRETL = parser.parse_args().gretl
    unittest.main(argv=[__file__])
