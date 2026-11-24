"""Genera las hojas de sprites de los gatos tanquistas, con la misma base que Muchi.

Usa muchi.py y pixlib.py (copiados del proyecto de Muchi, mismo autor) y cambia
solo el pelaje, los ojos y el gorro: boina para el batallón británico y casco
acolchado de tanquista (shlemofon) para el soviético.

Cada hoja tiene el mismo formato que la de Muchi (cuadros de 32x32; filas idle,
talk, happy, alert, angry), así que scripts/muchi.gd las anima igual.

Uso (desde la raíz del proyecto):  python tools/gatos/generar_gatos.py
Requiere Pillow. Escribe assets/gatos/<id>.png y tools/vista_previa_gatos.png.
"""

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import muchi  # noqa: E402
import pixlib  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SALIDA = os.path.join(RAIZ, "assets", "gatos")

# ------------------------------------------------------------------ gorros ---
GORROS = {
    # Boina negra del Royal Tank Regiment, caída hacia la derecha, insignia a la izquierda.
    "boina": {
        "colores": {"G": (40, 40, 54), "H": (74, 74, 92), "X": (214, 214, 224)},
        "forma": {3: (13, 20), 4: (10, 23), 5: (8, 25), 6: (7, 26), 7: (7, 27), 8: (9, 27), 9: (23, 27)},
        "luz": {4: (12, 16), 5: (10, 12)},
        "insignia": [(6, 10), (6, 11), (7, 10), (7, 11)],
    },
    # Shlemofon: casco de cuero acolchado con rollos y orejeras. Las orejas del gato asoman.
    "shlemofon": {
        "colores": {"G": (86, 60, 42), "H": (128, 94, 64), "X": (214, 214, 224)},
        "forma": {4: (11, 20), 5: (8, 23), 6: (6, 25), 7: (5, 26), 8: (5, 26), 9: (5, 26),
                  10: [(3, 6), (25, 28)], 11: [(3, 6), (25, 28)], 12: [(3, 6), (25, 28)],
                  13: [(3, 6), (25, 28)], 14: [(4, 6), (25, 27)], 15: [(4, 6), (25, 27)]},
        "luz": {r: [(10, 10), (15, 16), (21, 21)] for r in range(5, 10)},
        "insignia": [],
        # Gafas de tanquista subidas sobre el casco: marco oscuro y vidrio celeste.
        "gafas": {"marco": {5: [(8, 13), (18, 23)], 6: [(8, 8), (13, 13), (18, 18), (23, 23)],
                            7: [(8, 13), (14, 17), (18, 23)]},
                  "vidrio": {6: [(9, 12), (19, 22)]}},
    },
    # Casco M1 estadounidense: casco de acero redondo verde oliva, con ala y barboquejo.
    "casco_m1": {
        "colores": {"G": (92, 102, 60), "H": (124, 134, 84), "X": (60, 66, 38)},
        "forma": {2: (11, 20), 3: (9, 22), 4: (8, 23), 5: (7, 24), 6: (7, 24), 7: (6, 25), 8: (5, 26)},
        "luz": {3: (11, 14), 4: (9, 11)},
        "insignia": [(8, c) for c in range(5, 27)],  # ala del casco, más oscura
        "visera": {},
        # Barboquejo: tiras finas que bajan por las mejillas.
        "gafas": {"marco": {r: [(6, 6), (25, 25)] for r in range(10, 16)}, "vidrio": {}},
    },
    # Gorra de plato de oficial instructora: copa caqui, cinta oscura, visera negra e insignia dorada.
    "gorra": {
        "colores": {"G": (128, 112, 74), "H": (164, 146, 100), "X": (236, 196, 80)},
        "forma": {2: (10, 21), 3: (8, 23), 4: (7, 24), 5: (8, 23), 6: (9, 22), 7: (9, 22)},
        "luz": {2: (12, 15), 3: (10, 12)},
        "insignia": [(4, 15), (4, 16), (5, 15), (5, 16)],
        "visera": {7: (9, 22), 8: (10, 21)},
    },
}

# ------------------------------------------------------------------ gatos ---
# Pelaje: O principal, L luz, D rayas/sombra. I: masa del ojo.
PELAJES = {
    "azul": {"O": (128, 142, 170), "L": (162, 176, 200), "D": (110, 122, 150)},
    "crema": {"O": (240, 212, 166), "L": (252, 234, 202), "D": (216, 180, 128)},
    "naranja": {},  # el de Muchi
    "azul_ruso": {"O": (112, 126, 150), "L": (146, 160, 184), "D": (94, 108, 132)},
    "gris": {"O": (150, 150, 152), "L": (186, 186, 188), "D": (112, 112, 116)},
    "atigrado": {"O": (154, 122, 88), "L": (186, 156, 116), "D": (98, 72, 50)},
    "blanco": {"O": (244, 240, 232), "L": (255, 255, 255), "D": (222, 214, 204), "S": (222, 216, 206)},
    # Maine Coon: grandes y peludos.
    "coon_cafe": {"O": (150, 104, 62), "L": (186, 140, 92), "D": (96, 62, 36)},
    "coon_dorado": {"O": (222, 172, 98), "L": (244, 204, 138), "D": (180, 124, 58)},
    "coon_negro": {"O": (58, 58, 68), "L": (90, 90, 104), "D": (44, 44, 52)},
    # Gris y blanco de pelo largo, como la gata Michi (sin rayas atigradas).
    "gris_blanco": {"O": (122, 128, 140), "L": (154, 160, 172), "D": (110, 116, 128)},
}
OJOS = {"cobre": (112, 58, 30), "verde": (36, 96, 64), "oscuro": (58, 26, 54), "ambar": (150, 104, 20),
        "verde_claro": (70, 150, 110)}

# Michi: franja blanca que baja por la frente hasta la nariz, mejillas blancas y
# mechones de pelo largo a los costados de la cara.
MARCAS_MICHI = [
    (8, 15, 16, "W"), (9, 14, 17, "W"), (10, 14, 17, "W"), (11, 14, 17, "W"), (12, 13, 18, "W"),
    (13, 13, 18, "W"),
    (14, 4, 4, "W"), (15, 4, 4, "W"), (14, 27, 27, "W"), (15, 27, 27, "W"),
]

# Maine Coon: mechones a los costados de la cara (melena). Donut: esmoquin, con pechera
# y hocico blancos.
MARCAS_MELENA = [(13, 4, 4, "L"), (14, 4, 4, "L"), (15, 4, 4, "L"), (13, 27, 27, "L"), (14, 27, 27, "L"), (15, 27, 27, "L")]
MARCAS_ESMOQUIN = MARCAS_MELENA + [(12, 13, 18, "W"), (13, 12, 19, "W")]

# id: (pelaje, ojos, gorro, marcas, carácter). Carácter "mañosa": en reposo frunce el ceño.
GATOS = {
    "earl_grey": ("azul", "cobre", "boina", [], "normal"),
    "crumpet": ("crema", "cobre", "boina", [], "normal"),
    "marmalade": ("naranja", "oscuro", "boina", [], "normal"),
    "boris": ("azul_ruso", "verde", "shlemofon", [], "normal"),
    "kasha": ("gris", "verde", "shlemofon", [], "normal"),
    "mishka": ("atigrado", "verde", "shlemofon", [], "normal"),
    "pelmeni": ("blanco", "verde", "shlemofon", [], "normal"),
    "michi": ("gris_blanco", "verde_claro", "gorra", MARCAS_MICHI, "mañosa"),
    "pancake": ("coon_cafe", "ambar", "casco_m1", MARCAS_MELENA, "normal"),
    "waffles": ("coon_dorado", "verde", "casco_m1", MARCAS_MELENA, "normal"),
    "donut": ("coon_negro", "ambar", "casco_m1", MARCAS_ESMOQUIN, "normal"),
}


def _segmentos(v):
    return v if isinstance(v, list) else [v]


def fx_gorro(nombre):
    """Efecto para muchi.build(): dibuja el gorro siguiendo la cabeza (head_dy)."""
    g = GORROS[nombre]

    def f(cv, head_dy, _body_dy):
        celdas = set()
        for r, v in g["forma"].items():
            for c0, c1 in _segmentos(v):
                for c in range(c0, c1 + 1):
                    celdas.add((r + head_dy, c))
        # Contorno: primero el gorro engordado 1 px en tinta, después el relleno.
        for r, c in celdas:
            for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (r + dr, c + dc) not in celdas:
                    cv.px(r + dr, c + dc, "K")
        for r, c in celdas:
            cv.px(r, c, "G")
        for r, v in g["luz"].items():
            for c0, c1 in _segmentos(v):
                cv.span(r + head_dy, c0, c1, "H")
        for r, c in g["insignia"]:
            cv.px(r + head_dy, c, "X")
        gafas = g.get("gafas", {})
        for clave, color in (("marco", "K"), ("vidrio", "C")):
            for r, v in gafas.get(clave, {}).items():
                for c0, c1 in _segmentos(v):
                    cv.span(r + head_dy, c0, c1, color)
        if gafas:
            cv.span(6 + head_dy, 10, 10, "E")  # brillo en el vidrio
            cv.span(6 + head_dy, 20, 20, "E")
        for r, (c0, c1) in g.get("visera", {}).items():
            cv.span(r + head_dy, c0, c1, "K")
    return f


def fx_marcas(celdas):
    """Manchas propias de un gato, en coordenadas de la cabeza: [(fila, col0, col1, color)]."""
    def f(cv, head_dy, _body_dy):
        for r, c0, c1, ch in celdas:
            cv.span(r + head_dy, c0, c1, ch)
    return f


def _sparkles(pts):
    def f(cv, *_):
        for r, c in pts:
            for dr, dc in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)):
                cv.px(r + dr, c + dc, "Y")
    return f


def _bang(r, c):
    def f(cv, *_):
        for dr in (0, 1, 2, 4):
            cv.px(r + dr, c, "Y")
    return f


def _anger(r, c):
    def f(cv, *_):
        for dr, dc in ((0, 0), (0, 2), (1, 1), (2, 0), (2, 2)):
            cv.px(r + dr, c + dc, "R")
    return f


def _mover(cv, dc):
    if dc == 0:
        return cv
    n = pixlib.Canvas(cv.w, cv.h, cv.pal, cv.fills)
    for r in range(cv.h):
        for c in range(cv.w):
            if cv.g[r][c] != pixlib.T:
                n.px(r, c + dc, cv.g[r][c])
    return n


def animaciones(gorro, marcas=(), caracter="normal"):
    """Mismas animaciones que Muchi (anim.frames_a), con marcas y gorro encima.
    Con carácter "mañosa" el reposo y el habla van con el ceño fruncido."""
    extras = ([fx_marcas(marcas)] if marcas else []) + [fx_gorro(gorro)]
    ceño = caracter == "mañosa"

    def b(**k):
        k["fx"] = k.get("fx", []) + extras
        return muchi.build(**k)

    A = {}
    br = [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0]
    tl = [0, 0, 1, 1, 2, 2, 1, 1, 0, 0, -1, -1, 0, 0, 1, 1]
    ojos = "angry" if ceño else "open"
    A["idle"] = [b(head_dy=br[i], body_dy=br[i], tail=tl[i], eyes="blink" if i == 12 else ojos,
                   mouth="flat" if ceño else "closed")
                 for i in range(16)]
    mo = ["closed", "small", "open", "wide", "open", "small"]
    hb = [0, 0, -1, -1, 0, 0]
    A["talk"] = [b(head_dy=hb[i], tail=[0, 1, 2, 2, 1, 0][i] - 1, mouth=mo[i], eyes=ojos) for i in range(6)]
    A["happy"] = [b(**k) for k in [
        dict(squash=1, head_dy=1, eyes="happy", mouth="smile", ear="up"),
        dict(squash=2, head_dy=1, eyes="happy", mouth="smile", ear="up"),
        dict(head_dy=-3, body_dy=-3, eyes="happy", mouth="open", ear="up", tail=2),
        dict(head_dy=-4, body_dy=-4, eyes="happy", mouth="open", ear="up", tail=2,
             fx=[_sparkles([(6, 2), (7, 29), (12, 1)])]),
        dict(head_dy=-3, body_dy=-3, eyes="happy", mouth="open", ear="up", tail=1,
             fx=[_sparkles([(4, 3), (9, 28)])]),
        dict(head_dy=-1, body_dy=-1, eyes="happy", mouth="smile", ear="up", tail=1),
        dict(squash=1, head_dy=1, eyes="happy", mouth="smile", ear="up"),
        dict(eyes="happy", mouth="smile", ear="up", tail=1),
    ]]
    A["alert"] = [b(**k) for k in [
        dict(eyes="shock", mouth="wide", ear="up", head_dy=-2, body_dy=-1, tail=2),
        dict(eyes="shock", mouth="wide", ear="up", head_dy=-2, body_dy=-1, tail=2, fx=[_bang(2, 29)]),
        dict(eyes="shock", mouth="open", ear="up", head_dy=-1, tail=2, fx=[_bang(2, 29)]),
        dict(eyes="shock", mouth="open", ear="up", tail=1, fx=[_bang(3, 29)]),
        dict(eyes="wide", mouth="open", ear="up", tail=1),
        dict(eyes="wide", mouth="small", tail=0),
    ]]
    A["angry"] = [_mover(b(eyes="angry", mouth="frown" if i % 2 == 0 else "flat", ear="down",
                           tail=-1 if i % 2 else 1, fx=[_anger(1, 26)] if i < 4 else []),
                         (1, -1, 1, -1, 0, 0)[i]) for i in range(6)]
    return A


def paleta(pelaje, ojos, gorro):
    p = dict(muchi.PAL)
    p.update(PELAJES[pelaje])
    p["I"] = OJOS[ojos]
    p.update(GORROS[gorro]["colores"])
    return p


def generar():
    os.makedirs(SALIDA, exist_ok=True)
    vistas = []
    for id_gato, (pelaje, ojos, gorro, marcas, caracter) in GATOS.items():
        anims = animaciones(gorro, marcas, caracter)
        pal = paleta(pelaje, ojos, gorro)
        columnas = max(len(v) for v in anims.values())
        hoja = Image.new("RGBA", (columnas * 32, len(anims) * 32), (0, 0, 0, 0))
        for fila, cuadros in enumerate(anims.values()):
            for col, cv in enumerate(cuadros):
                cv.pal = pal
                hoja.paste(cv.image(1, {"B": 90}), (col * 32, fila * 32))
        hoja.save(os.path.join(SALIDA, f"{id_gato}.png"))
        vistas.append(anims["idle"][0].image(1, {"B": 90}))
    # Vista previa ×6 sobre fondo claro.
    previa = Image.new("RGBA", (len(vistas) * 32 * 6, 32 * 6), (214, 222, 200, 255))
    for i, im in enumerate(vistas):
        previa.alpha_composite(im.resize((192, 192), Image.NEAREST), (i * 192, 0))
    previa.save(os.path.join(RAIZ, "tools", "vista_previa_gatos.png"))
    print("ok:", ", ".join(GATOS))


if __name__ == "__main__":
    generar()
