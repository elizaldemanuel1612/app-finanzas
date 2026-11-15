#!/bin/bash
# Compila y publica la web (spec §4.2.2).
#
# Las fuentes (sobre todo MaterialIcons, que Flutter recorta a los íconos que
# usa cada versión) se publican con un nombre que incluye su huella: si el
# navegador guardó la de una versión anterior, la nueva tiene otra dirección y
# no puede reusarla. Sin esto, en el iPhone los íconos nuevos salían en blanco.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --wasm
python3 -I - build/web <<'PY'
import hashlib, json, os, sys
raiz = sys.argv[1]
ruta_manifiesto = os.path.join(raiz, 'assets', 'FontManifest.json')
manifiesto = json.load(open(ruta_manifiesto))
renombradas = {}
for familia in manifiesto:
    for fuente in familia['fonts']:
        asset = fuente['asset']
        if asset not in renombradas:
            local = os.path.join(raiz, 'assets', asset)
            huella = hashlib.sha256(open(local, 'rb').read()).hexdigest()[:10]
            base, ext = os.path.splitext(asset)
            nuevo = f'{base}.{huella}{ext}'
            with open(local, 'rb') as o, open(os.path.join(raiz, 'assets', nuevo), 'wb') as d:
                d.write(o.read())
            renombradas[asset] = nuevo
        fuente['asset'] = renombradas[asset]
json.dump(manifiesto, open(ruta_manifiesto, 'w'), separators=(',', ':'))
for viejo, nuevo in renombradas.items():
    print(f'  {viejo} -> {nuevo}')
PY
firebase deploy --only hosting
