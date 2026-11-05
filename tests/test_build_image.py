"""The prepared image build accepts only the current complete provenance contract."""
import json
import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class PreparedImage(unittest.TestCase):
    def test_missing_hpi_digest_refuses_to_call_docker(self):
        with tempfile.TemporaryDirectory() as directory:
            root=pathlib.Path(directory)
            command=root/'docker'
            marker=root/'called'
            command.write_text('#!/bin/sh\ntouch "$TEST_CALLED"\n')
            command.chmod(0o755)
            data=dict(JENKINS_IMAGE='jenkins/jenkins:base',IMAGE_VERSION='test',PLUGIN_VERSION='0.2.0',
                      GRETL_VERSION='fixed',THEMEN_REPO_REVISION='topics',PLUGIN_REPO_REVISION='plugin',
                      G0_TOOLCHAIN_IMAGE='fixed')
            (root/'build-args.json').write_text(json.dumps(data))
            env={**os.environ,'PATH':str(root)+':'+os.environ['PATH'],
                 'IMAGE_NAME':'delivery-fixture:local','TEST_CALLED':str(marker)}
            result=subprocess.run([str(ROOT/'bin/build-image.sh'),'--prepared-context',directory],
                                  env=env,capture_output=True,text=True)
            self.assertNotEqual(result.returncode,0)
            self.assertIn('Invalid explicit build metadata',result.stderr)
            self.assertFalse(marker.exists())

if __name__=='__main__':
    unittest.main()
