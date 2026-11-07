import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    'resolver', Path(__file__).resolve().parents[1]/'bin/resolve-gretl.py')
resolver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(resolver)


def metadata(jar, pom):
    return f"""<metadata><versioning><snapshotVersions>
        <snapshotVersion><extension>jar</extension><value>{jar}</value></snapshotVersion>
        <snapshotVersion><extension>pom</extension><value>{pom}</value></snapshotVersion>
    </snapshotVersions></versioning></metadata>""".encode()


class GretlSnapshot(unittest.TestCase):
    def test_new_build_reads_current_snapshot(self):
        old = '5.0.0-20260904.160229-21'
        new = '5.0.0-20260905.160229-22'
        with patch.object(resolver, 'fetch', side_effect=[
            metadata(old, old), b'a' * 64, metadata(new, new), b'b' * 64,
        ]) as fetch:
            self.assertEqual(resolver.resolve(), (old, 'a' * 64))
            self.assertEqual(resolver.resolve(), (new, 'b' * 64))
        self.assertEqual(fetch.call_args_list[0], fetch.call_args_list[2])
        self.assertIn(new, fetch.call_args_list[3].args[0])

    def test_incomplete_snapshot_fails(self):
        with patch.object(resolver, 'fetch', return_value=metadata(
            '5.0.0-20260905.160229-22', '5.0.0-20260904.160229-21',
        )), self.assertRaisesRegex(ValueError, 'inconsistent GRETL'):
            resolver.resolve()

    def test_selected_ci_version_is_resolved_without_metadata_lookup(self):
        version = '5.0.0-20260904.160229-21'
        with patch.object(resolver, 'fetch', return_value=b'a' * 64) as fetch:
            self.assertEqual(resolver.resolve(version), (version, 'a' * 64))
        fetch.assert_called_once_with(f'{resolver.ARTIFACT}/gretl-core-{version}.jar.sha256')
