#!/usr/bin/env python3
"""Resolve one complete published GRETL 5 snapshot for an image build."""
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET

ARTIFACT = 'https://jars.interlis.guru/snapshots/ch/so/agi/gretl-core/5.0.0-SNAPSHOT'
VERSION = re.compile(r'5\.0\.0-\d{8}\.\d{6}-\d+')
CHECKSUM = re.compile(r'[a-f0-9]{64}')


def fetch(url):
    try:
        request = urllib.request.Request(url, headers={'Cache-Control': 'no-cache'})
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.read(65536)
    except OSError as error:
        raise ValueError(f'{url}: {error}') from error


def resolve(version=None):
    if version is None:
        metadata_url = f'{ARTIFACT}/maven-metadata.xml'
        metadata = ET.fromstring(fetch(metadata_url))
        entries = {
            entry.findtext('extension'): entry.findtext('value')
            for entry in metadata.findall('./versioning/snapshotVersions/snapshotVersion')
            if entry.find('classifier') is None
        }
        version = entries.get('jar')
        if not version or entries.get('pom') != version:
            raise ValueError(f'{metadata_url}: inconsistent GRETL JAR and POM versions')
    if not VERSION.fullmatch(version):
        raise ValueError(f'{ARTIFACT}: invalid GRETL snapshot version {version!r}')
    checksum_url = f'{ARTIFACT}/gretl-core-{version}.jar.sha256'
    checksum = fetch(checksum_url).decode('ascii').strip()
    if not CHECKSUM.fullmatch(checksum):
        raise ValueError(f'{checksum_url}: invalid SHA-256')
    return version, checksum


if __name__ == '__main__':
    try:
        print(*resolve(*sys.argv[1:]))
    except (ValueError, ET.ParseError) as error:
        raise SystemExit(f'{ARTIFACT}: {error}')
