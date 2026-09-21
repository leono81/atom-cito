#!/usr/bin/env python3
"""Compara el render QML contra el prototipo aprobado (docs/perro.html).

Saca el SVG de cada pose del prototipo, lo rasteriza con rsvg-convert al
mismo tamaño que usa el banco de pruebas, y arma un montaje: arriba el QML,
abajo el SVG.

    python3 harness/compare-prototype.py      # deja shots/cmp-prototipo.png
"""

import re
import subprocess

HTML = "/home/leono/Projects/atom/docs/perro.html"
SHOTS = "/home/leono/Projects/atom/harness/shots/"
BG, INK = "#12161b", "#e8e2d6"
W, H = 238, 168

CSS = ("<style>"
       ".fill{fill:%s;stroke:%s;stroke-width:1.05;stroke-linejoin:round}"
       ".solid{fill:%s;stroke:none}"
       ".leg{stroke:%s;stroke-width:2.1;stroke-linecap:round;fill:none}"
       ".leg.far{opacity:.45}"
       ".tail{stroke:%s;stroke-width:1.7;stroke-linecap:round;fill:none}"
       ".lid{stroke:%s;stroke-width:.9;stroke-linecap:round;fill:none}"
       "text{fill:%s}</style>") % ((BG,) + (INK,) * 6)

src = open(HTML).read()
chunk = src[src.index("function dogSVG()"):src.index("var POSE_CLASS")]
svg = "".join(re.findall(r"'((?:[^'\\]|\\.)*)'", chunk))
svg = svg.replace(
    '<svg class="dog" viewBox="0 0 34 24" aria-hidden="true">',
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 34 24" '
    'width="%d" height="%d">%s<rect width="34" height="24" fill="%s"/>'
    % (W, H, CSS, BG))
pre = svg[:svg.index('<g class="pose')]

# En el banco, las poses grandes salen de una fila de 5 columnas de 238 px
# con 14 de separación, dentro de una tarjeta con 24/20 de margen.
COLS = {"stand": 0, "walk": 1, "sit": 2, "lie": 3, "sleep": 4}
REF = {"stand": "p-stand", "walk": "p-stand", "sit": "p-sit",
       "lie": "p-lie", "sleep": "p-sleep"}

pairs = []
for name in ("stand", "sit", "lie", "sleep"):
    k = svg.index('<g class="pose %s">' % REF[name])
    nxt = svg.find('<g class="pose', k + 5)
    one = pre + svg[k:nxt if nxt > 0 else svg.index("</svg>")] + "</svg>"
    open("/tmp/ref-%s.svg" % name, "w").write(one)
    subprocess.run(["rsvg-convert", "-w", str(W), "-h", str(H),
                    "-o", "/tmp/ref-%s.png" % name, "/tmp/ref-%s.svg" % name],
                   check=True)
    x = 24 + (W + 14) * COLS[name]
    subprocess.run(["magick", SHOTS + "poses-grande.png",
                    "-crop", "%dx%d+%d+%d" % (W, H, x, 20), "+repage",
                    "/tmp/mine-%s.png" % name], check=True)
    subprocess.run(["magick", "/tmp/mine-%s.png" % name,
                    "/tmp/ref-%s.png" % name, "-append",
                    "/tmp/cmp-%s.png" % name], check=True)
    pairs.append("/tmp/cmp-%s.png" % name)

subprocess.run(["magick"] + pairs + ["+append", SHOTS + "cmp-prototipo.png"],
               check=True)
print("arriba QML, abajo el prototipo →", SHOTS + "cmp-prototipo.png")
