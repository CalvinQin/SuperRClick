"""Policy regression tests with a mocked codesign, not macOS signature validation."""
import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]

class PreviewSignatures(unittest.TestCase):
    def check_policy(self, details, verify_exit=0):
        with tempfile.TemporaryDirectory() as directory:
            mock = pathlib.Path(directory) / 'codesign'
            mock.write_text('#!/bin/bash\nif [[ "$1" == "--verify" ]]; then exit "$VERIFY_EXIT"; fi\nprintf "%s\\n" "$DETAILS" >&2\n')
            mock.chmod(0o755)
            env = dict(os.environ, PATH=directory+':'+os.environ['PATH'], DETAILS=details, VERIFY_EXIT=str(verify_exit))
            return subprocess.run(['bash', str(ROOT/'scripts/verify_preview_signatures.sh'), '/fixture app.app'], env=env, capture_output=True).returncode

    def test_accepts_adhoc_without_runtime(self):
        self.assertEqual(self.check_policy('Signature=adhoc\nCodeDirectory flags=0x2(adhoc)'), 0)

    def test_rejects_runtime(self):
        self.assertNotEqual(self.check_policy('Signature=adhoc\nCodeDirectory flags=0x10002(adhoc,runtime)'), 0)

    def test_rejects_non_preview_signature(self):
        self.assertNotEqual(self.check_policy('Authority=Developer ID Application'), 0)

    def test_propagates_invalid_signature(self):
        self.assertNotEqual(self.check_policy('Signature=adhoc', 1), 0)

if __name__ == '__main__':
    unittest.main()
