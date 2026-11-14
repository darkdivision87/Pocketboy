#!/usr/bin/env python3
"""Lists game files that are neither registered in Library.swift nor excluded in Package.swift.
Run before committing: any file listed here would break the build while it is half written.
Helper files that belong to a registered game (no Cartridge of their own) are listed as 'helper' for manual review."""
import re, glob, os
lib = open('Sources/PocketCore/Library.swift').read()
reg = set(re.findall(r'\.(\w+)', lib))
pk = open('Package.swift').read()
excluded = set(re.findall(r'"Games/([^"]+)"', pk))
for f in sorted(glob.glob('Sources/PocketCore/Games/*.swift')):
    b = os.path.basename(f)
    s = open(f).read()
    names = re.findall(r'static let (\w+) = Cartridge\(', s)
    if names and all(n in reg for n in names):
        continue
    if b in excluded:
        continue
    print(('helper? ' if not names else 'UNREGISTERED: ') + b)
