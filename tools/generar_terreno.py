"""Genera las losetas de terreno con estética de cartas pixeladas (estilo Balatro):
cada casilla es una carta sobre el tapete, con color plano, borde negro grueso,
esquinas redondeadas, una franja diagonal de sombra y un "palo" en las esquinas.
La roca (intransitable) es una carta boca abajo.

Arte propio hecho por código: no usa imágenes de terceros.

Uso (desde la raíz del proyecto):  python tools/generar_terreno.py
Escribe assets/terreno/<tipo>_<n>.png (64×64, 3 variantes por tipo) y
tools/vista_previa_terreno.png.
"""

import os

from generar_sprites import _escribir_png

TAM = 64
VARIANTES = 3
MARGEN = 2          # hueco entre cartas: ahí se ve el tapete
RADIO_ESQUINA = 4
BORDE = (28, 26, 36)

# Cada palo es un icono de 9 px de ancho. "X" = borde, el resto según la paleta del tipo.
PALOS = {
    "llano": [
        "....X....",
        ".X.XGX.X.",
        "XGXXGXXGX",
        "XGXGgGXGX",
        ".XGGgGGX.",
        "..XXXXX..",
    ],
    "bosque": [
        "...XXX...",
        "..XGGGX..",
        ".XGgGGGX.",
        ".XGGGGGX.",
        "XGGGGGgGX",
        ".XXGGGXX.",
        "...XTX...",
        "..XXXXX..",
    ],
    "ruinas": [
        "XXXX.....",
        "XBBX.....",
        "XXXXXXX..",
        "XBBXBbX..",
        "XXXXXXXXX",
        "XBbXBBXBX",
        "XXXXXXXXX",
    ],
    "roca": [
        "...XXXX....",
        "..XRRrRX...",
        ".XRRRRRRXX.",
        "XRRRRRRRRRX",
        "XRRRRRRRRRX",
        ".XXXXXXXXX.",
    ],
}

TIPOS = {
    # cara: color plano; sombra: franja diagonal; luz: brillo del borde superior.
    "llano": {"cara": (206, 230, 184), "sombra": (184, 212, 162), "luz": (230, 244, 214),
              "G": (96, 150, 78), "g": (150, 196, 112)},
    "bosque": {"cara": (166, 206, 168), "sombra": (144, 186, 148), "luz": (196, 228, 196),
               "G": (46, 110, 64), "g": (96, 160, 96), "T": (110, 78, 52)},
    "ruinas": {"cara": (232, 220, 202), "sombra": (212, 198, 178), "luz": (246, 238, 226),
               "B": (184, 96, 78), "b": (220, 140, 112)},
}
DORSO = {"cara": (70, 80, 128), "patron": (92, 104, 158), "marco": (214, 220, 236),
         "R": (150, 150, 168), "r": (196, 196, 212)}


class Carta:
    def __init__(self):
        self.px = [[None] * TAM for _ in range(TAM)]

    def poner(self, x, y, c):
        if 0 <= x < TAM and 0 <= y < TAM:
            self.px[y][x] = c

    def dentro(self, x, y, inset=0):
        """¿El píxel cae dentro del rectángulo redondeado de la carta (reducido en `inset`)?"""
        a, b = MARGEN + inset, TAM - 1 - MARGEN - inset
        if not (a <= x <= b and a <= y <= b):
            return False
        r = max(RADIO_ESQUINA - inset, 0)
        cx = a + r if x < a + r else b - r if x > b - r else x
        cy = a + r if y < a + r else b - r if y > b - r else y
        return (x - cx) ** 2 + (y - cy) ** 2 <= r * r + r

    def icono(self, filas, x0, y0, colores, espejo=False):
        filas = [f[::-1] for f in reversed(filas)] if espejo else filas  # el de abajo va girado
        for j, fila in enumerate(filas):
            for i, ch in enumerate(fila):
                if ch == "X":
                    self.poner(x0 + i, y0 + j, BORDE)
                elif ch != ".":
                    self.poner(x0 + i, y0 + j, colores[ch])

    def filas(self, escala=1, fondo=None):
        out = []
        for fila in self.px:
            linea = b""
            for c in fila:
                c = c or fondo
                linea += (bytes((*c, 255)) if c else b"\0\0\0\0") * escala
            out += [linea] * escala
        return out


def _cuerpo(carta, cara, sombra=None, luz=None, desfase=0):
    for y in range(TAM):
        for x in range(TAM):
            if not carta.dentro(x, y):
                continue
            if not carta.dentro(x, y, 2):
                carta.poner(x, y, BORDE)  # borde de 2 px, como en las cartas de referencia
            elif luz and not carta.dentro(x, y - 1, 2):
                carta.poner(x, y, luz)  # brillo en el canto superior
            elif sombra and 0 <= (x - y) - desfase <= 22 and x + y > 52:
                carta.poner(x, y, sombra)  # franja diagonal que cae desde el palo
            else:
                carta.poner(x, y, cara)


def carta_de_terreno(tipo, variante):
    t = TIPOS[tipo]
    carta = Carta()
    _cuerpo(carta, t["cara"], t["sombra"], t["luz"], desfase=-4 + variante * 4)
    palo = PALOS[tipo]
    carta.icono(palo, 6, 6, t)
    alto = len(palo)
    carta.icono(palo, TAM - 6 - len(palo[0]), TAM - 6 - alto, t, espejo=True)
    return carta


def carta_boca_abajo(variante):
    d = DORSO
    carta = Carta()
    _cuerpo(carta, d["cara"])
    # Marco claro interior y rombos, como el dorso de una baraja.
    for y in range(TAM):
        for x in range(TAM):
            if carta.dentro(x, y, 5) and not carta.dentro(x, y, 6):
                carta.poner(x, y, d["marco"])
            elif carta.dentro(x, y, 7) and (abs((x + variante) % 8 - 4) + abs(y % 8 - 4)) == 3:
                carta.poner(x, y, d["patron"])
    palo = PALOS["roca"]
    x0, y0 = (TAM - len(palo[0])) // 2, (TAM - len(palo)) // 2
    for y in range(y0 - 3, y0 + len(palo) + 3):  # medallón central
        for x in range(x0 - 3, x0 + len(palo[0]) + 3):
            carta.poner(x, y, d["cara"])
    carta.icono(palo, x0, y0, d)
    return carta


def generar(raiz):
    carpeta = os.path.join(raiz, "assets", "terreno")
    os.makedirs(carpeta, exist_ok=True)
    hoja = []
    for nombre in ("llano", "bosque", "ruinas", "roca"):
        fila = []
        for v in range(VARIANTES):
            carta = carta_boca_abajo(v) if nombre == "roca" else carta_de_terreno(nombre, v)
            _escribir_png(os.path.join(carpeta, f"{nombre}_{v}.png"), carta.filas(), TAM, TAM)
            fila.append(carta)
        hoja.append(fila)
    # Vista previa ×3 sobre el tapete: una fila por tipo, una columna por variante.
    esc, tapete = 3, (36, 70, 64)
    filas = []
    for fila in hoja:
        partes = [c.filas(esc, tapete) for c in fila]
        filas += [b"".join(p[i] for p in partes) for i in range(TAM * esc)]
    _escribir_png(os.path.join(raiz, "tools", "vista_previa_terreno.png"), filas,
                  TAM * esc * VARIANTES, TAM * esc * 4)


if __name__ == "__main__":
    generar(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
