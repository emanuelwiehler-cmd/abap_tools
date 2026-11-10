#!/usr/bin/env python3
"""
Benennt die Objekte eines Tools aus dem Z-Namensraum in einen Kundennamensraum um.

Ersetzt in Dateinamen und Dateiinhalten (Gross- und Kleinschreibung):
    ZCL_<KÜRZEL>_  ->  <NS>CL_<KÜRZEL>_
    Z<KÜRZEL>_     ->  <NS><KÜRZEL>_
und prüft danach die SAP-Längenbeschränkungen der Objektnamen.

Beispiele (im Repo-Wurzelverzeichnis ausführen):
    python tools/rename_namespace.py --ns /ABC/            # ZRRI_10 -> /ABC/RRI_10, ZCL_RRI_DYN_SRV -> /ABC/CL_RRI_DYN_SRV
    python tools/rename_namespace.py --ns Y                # ZRRI_10 -> YRRI_10
    python tools/rename_namespace.py --ns /ABC/ --dry-run  # nur anzeigen

Standard: Kürzel RRI, Verzeichnis src/rri_dyn. Das Skript ändert die Dateien direkt,
deshalb vorher einen eigenen Branch oder eine Kopie anlegen.
"""
import argparse
import os
import re
import sys

# Maximale Namenslängen je abapGit-Objekttyp
MAX_LEN = {'tabl': 16, 'view': 16, 'vcls': 16, 'doma': 30, 'dtel': 30,
           'clas': 30, 'intf': 30, 'enho': 30, 'fugr': 26, 'tobj': 20, 'devc': 30}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--ns', required=True, help='Ziel-Präfix, z. B. Z, Y oder /ABC/')
    ap.add_argument('--abbr', default='RRI', help='Kürzel des Tools (Standard: RRI)')
    ap.add_argument('--path', default=os.path.join('src', 'rri_dyn'), help='Verzeichnis mit den abapGit-Dateien')
    ap.add_argument('--dry-run', action='store_true', help='nur anzeigen, nichts ändern')
    a = ap.parse_args()

    ns = a.ns.upper()
    if not re.fullmatch(r'[ZY]|/[A-Z0-9_]{1,8}/', ns):
        sys.exit('Ungültiger Namensraum: erlaubt sind Z, Y oder /NAMESPACE/')
    abbr = a.abbr.upper()

    rules = [(f'ZCL_{abbr}_', f'{ns}CL_{abbr}_'), (f'Z{abbr}_', f'{ns}{abbr}_')]
    rules += [(o.lower(), n.lower()) for o, n in rules]

    def conv_text(s):
        # Platzhalter verhindern, dass ZCL_RRI_ anschliessend nochmals von ZRRI_ erfasst wird
        for i, (o, _) in enumerate(rules):
            s = s.replace(o, f'\x00{i}\x00')
        for i, (_, n) in enumerate(rules):
            s = s.replace(f'\x00{i}\x00', n)
        return s

    def conv_filename(fn):
        # abapGit kodiert "/" in Dateinamen als "#"
        return conv_text(fn).replace('/', '#')

    if not os.path.isdir(a.path):
        sys.exit(f'Verzeichnis nicht gefunden: {a.path}')

    errors = []
    for root, _, files in os.walk(a.path):
        for fn in sorted(files):
            src = os.path.join(root, fn)
            with open(src, encoding='utf-8') as f:
                old = f.read()
            new = conv_text(old)
            new_fn = conv_filename(fn)
            dst = os.path.join(root, new_fn)

            parts = new_fn.split('.')
            if len(parts) >= 3 and parts[0] != 'package':
                obj, typ = parts[0].replace('#', '/'), parts[1]
                if typ in MAX_LEN and len(obj) > MAX_LEN[typ]:
                    errors.append(f'{obj.upper()} ({typ.upper()}): {len(obj)} > {MAX_LEN[typ]} Zeichen')

            if new != old or dst != src:
                print(f'{fn:40s} -> {new_fn}')
                if not a.dry_run:
                    with open(dst, 'w', encoding='utf-8', newline='\n') as f:
                        f.write(new)
                    if dst != src:
                        os.remove(src)

    if errors:
        print('\nACHTUNG, Namen zu lang:\n  ' + '\n  '.join(errors))
        sys.exit(1)
    print('\nFertig.' if not a.dry_run else '\nTestlauf, nichts geändert.')


if __name__ == '__main__':
    main()
