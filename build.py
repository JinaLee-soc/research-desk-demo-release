#!/usr/bin/env python3
"""Build the standalone, offline macOS presentation demo."""
from pathlib import Path
import shutil, subprocess
from fixtures import generate

root=Path(__file__).resolve().parent
app=root/'dist/Research Desk Demo.app'
resources=app/'Contents/Resources'
binary=app/'Contents/MacOS'
cache=root/'.build/module-cache'
# Recreate only generated bundle resources so removed assets cannot survive a rebuild.
if resources.exists():shutil.rmtree(resources)
resources.mkdir(parents=True);binary.mkdir(parents=True,exist_ok=True);cache.mkdir(parents=True,exist_ok=True)
for path in (root/'Resources').iterdir():
    if path.is_file():shutil.copy2(path,resources/path.name)
for path in [root/'ASSETS.md',root/'LICENSE']:
    shutil.copy2(path,resources/path.name)
generate(resources)
shutil.copy2(root/'Info.plist',app/'Contents/Info.plist')
subprocess.run(['xcrun','swiftc','-swift-version','5','-module-cache-path',str(cache),*[str(p) for p in sorted((root/'Sources').glob('*.swift'))],'-o',str(binary/'ResearchDeskDemo'),'-framework','AppKit','-framework','WebKit','-framework','ServiceManagement','-framework','UserNotifications','-framework','CryptoKit'],check=True)
subprocess.run(['codesign','--force','--sign','-',str(app)],check=True)
print(app)
