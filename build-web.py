#!/usr/bin/env python3
"""Build the static demo from allowlisted resources and fresh synthetic fixtures."""
from pathlib import Path
import tempfile, subprocess, shutil, json
from fixtures import generate
root=Path(__file__).resolve().parent
out=root/'web-dist'
# This directory contains generated site files only. Avoid publishing stale files.
if out.exists(): shutil.rmtree(out)
out.mkdir()
with tempfile.TemporaryDirectory(prefix='research-desk-web-') as tmp:
    base=Path(tmp);res=base/'fixtures';res.mkdir();generate(res)
    subprocess.run(['xcrun','swiftc','-swift-version','5','-module-cache-path',str(base/'cache'),*[str(root/'Sources'/n) for n in ['DeadlineModel.swift','DeskModel.swift','DeskStore.swift','DemoSupport.swift']],str(root/'web/Export.swift'),'-o',str(base/'export'),'-framework','AppKit','-framework','UserNotifications','-framework','CryptoKit'],check=True)
    subprocess.run([str(base/'export'),str(base)],check=True)
    seed=json.loads((base/'seed.json').read_text())
    # Only the freshly generated fixture store is read. Never export dist/Demo Data.
    text=json.dumps(seed,ensure_ascii=True,separators=(',',':'))
    assert '/Users/' not in text and '@gmail.com' not in text
    (out/'web-seed.js').write_text('window.RESEARCH_DESK_SEED='+text+';\n')
for f in (root/'Resources').iterdir():
    if f.is_file() and f.suffix in {'.js','.css','.png','.svg','.txt','.md'}:
        shutil.copyfile(f,out/f.name)
        if f.suffix=='.js':
            text=(out/f.name).read_text().replace('Saved on this Mac','Saved in this browser').replace('Saved on this Mac.','Saved in this browser.').replace('Save to wiki','Save in browser').replace('previous-file backup remain','change log remains').replace('Refreshes at 9 am, on launch and on wake. Quitting stops refreshes and notifications.','Preferences apply inside this browser. System notifications and launch at login are not available.')
            if f.name=='desk.js':
                text=text.replace("${btn('Mini window','mini')}", '')
                text=text.replace("checkbox('Keep mini window on top','alwaysOnTop',s.alwaysOnTop)+checkbox('Enable notifications','reminders',s.reminders)+", '')
                text=text.replace("<div class=\"field\"><span>Launch at login: ${payload.loginEnabled?'On':'Off'}</span>${btn('Toggle launch at login','login','','outline')}</div>", '')
            if f.name=='rewards.js':
                text=text.replace("'Copy image'", "'Download image'")
            (out/f.name).write_text(text)
shutil.copyfile(root/'Resources/styloo-assets.json',out/'styloo-assets.json')
for name in ['LICENSE','ASSETS.md']:
    shutil.copyfile(root/name,out/name)
    if name=='ASSETS.md': (out/name).write_text((out/name).read_text().replace('(Resources/', '('))
for name in ['web-demo.js','web-demo.css']:
    shutil.copyfile(root/'web'/name,out/name)
html=(root/'Resources/index.html').read_text()
html=html.replace('<script src="momo.js">','<script src="web-seed.js"></script><script src="web-demo.js"></script><script src="momo.js">')
html=html.replace('</head>','<link rel="stylesheet" href="web-demo.css"></head>')
html=html.replace('TOY DATA · Fictional research lab — No private research, deadlines or account connections','<span>PLAYABLE DEMO · Fictional data · Changes stay in this browser. Use toy information only.</span> <button id="web-reset" type="button">Reset demo</button> <a href="https://github.com/JinaLee-soc/research-desk-demo-release" target="_blank" rel="noopener noreferrer">Source &amp; Mac app</a> <span id="web-storage" role="status"></span>')
(out/'index.html').write_text(html)
(out/'.nojekyll').touch()
print(out)
