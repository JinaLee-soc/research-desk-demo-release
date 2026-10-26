#!/usr/bin/env python3
"""Bounded source/privacy checks and isolated native demo behavior tests."""
from pathlib import Path
import subprocess, re, hashlib
root=Path(__file__).resolve().parents[1]
resources=root/'Resources';sources=root/'Sources'
for path in list(sources.glob('*.swift'))+list(resources.glob('*.js'))+[root/'fixtures.py']:
    text=path.read_text()
    for forbidden in ['/Users/','#Reading','CLAUDE CRAB','Claude Crab','crab.webp','127.0.0.1','URLSession','Process()']:
        assert forbidden not in text, f'{path.name}: forbidden dependency: {forbidden}'
assert not (resources/'crab.webp').exists()
for name in ['office-room.webp','office-desk.webp','office-license.md','office-owner-bookish-fine.png']:
    assert not (resources/name).exists(), f'Obsolete artwork: {name}'
assert not list(resources.glob('reward-*.webp')) and not list(resources.glob('reward-*.png'))
for name,expected in {
    'PixelOfficeAssets.png':'797bec77277d0e1144ed6dd536758deef6cabb84d3a0df42b6866c205c146598',
}.items():
    assert hashlib.sha256((resources/name).read_bytes()).hexdigest()==expected, f'Changed third-party original: {name}'

assert hashlib.sha256((resources/'momo-poses.png').read_bytes()).digest()==b"\x1e\x04\xcc>\x9c\xa0\xcdm\xef\xa8\x91/\xe8j\xdf\x0fX'\xa4u\xc8\xf6qa\xdd\xb5\x8a\xd1[.\x93\x8a"
for path in resources.glob('*.js'):subprocess.run(['node','--check',str(path)],check=True)
main=(sources/'main.swift').read_text()
assert 'appendingPathComponent("Demo Data")' in main
assert 'ProcessInfo.processInfo.environment' not in main
assert 'externalActions.contains' in main
assert not any((resources/name).exists() for name in ['seed.json','demo-calendar.json','portfolio-source.json'])
build=root/'.build';build.mkdir(exist_ok=True)
subprocess.run(['xcrun','swiftc','-swift-version','5','-module-cache-path',str(build/'module-cache'),*[str(sources/name) for name in ['DeadlineModel.swift','DeskModel.swift','DeskStore.swift','DemoSupport.swift']],str(root/'tests/Verify.swift'),'-o',str(build/'verify'),'-framework','AppKit','-framework','UserNotifications','-framework','CryptoKit'],check=True)
subprocess.run([str(build/'verify'),str(root/'dist')],check=True)
print('PASS: source privacy boundaries, original cat asset, generated-data exclusion, all JavaScript syntax and native behavioral checks')
