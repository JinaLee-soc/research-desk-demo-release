#!/usr/bin/env python3
"""Install a local, location-aware Desktop launcher without committing personal paths."""
from pathlib import Path
import argparse,shlex
parser=argparse.ArgumentParser()
parser.add_argument('--desktop',type=Path,default=Path.home()/'Desktop')
args=parser.parse_args()
root=Path(__file__).resolve().parent
app=root/'dist/Research Desk Demo.app'
if not (app/'Contents/MacOS/ResearchDeskDemo').is_file():parser.error('Build first: python3 build.py')
launcher=args.desktop/'Research Desk Demo.command'
text='''#!/bin/zsh
set -euo pipefail
app='''+shlex.quote(str(app))+'''
if [[ ! -d "$app" ]]; then
  print -r -- "Research Desk Demo was moved. Run install-launcher.py again from its new folder."
  read -r "reply?Press Return to close. "
  exit 1
fi
/usr/bin/open "$app"
'''
if launcher.exists() and launcher.read_text()!=text:parser.error(f'Refusing to replace a different launcher: {launcher}')
launcher.write_text(text);launcher.chmod(0o755)
print(launcher)
