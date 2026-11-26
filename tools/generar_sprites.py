"""Genera los sprites de tanques en pixel art (vista lateral, mirando a la derecha).

Escala realista: 1 px = 0,13 m, a partir de las medidas reales de cada tanque.
Referencias usadas (solo para proporciones; el dibujo es propio):
  - M4 Sherman: TM 9-731B "Medium Tank M4A2" (1943), US War Department, dominio público.
    https://commons.wikimedia.org/wiki/File:TM_9-731B_Medium_Tank_M4A2_(1943).djvu
  - Centurion: foto "Centurion Mk VII (Panzer 57) pic05.JPG", CC0 (casco y tren de rodaje
    iguales al Mk1; el cañón se dibuja como el 17 libras del Mk1).
    https://commons.wikimedia.org/wiki/File:Centurion_Mk_VII_(Panzer_57)_pic05.JPG
  - Carro Armato P26/40: foto "Ansaldo P40 01.jpg", dominio público.
    https://commons.wikimedia.org/wiki/File:Ansaldo_P40_01.jpg
  - M13/40 y Semovente da 75/18: medidas públicas generales (largo ~4,9-5,0 m, alto
    2,4 m y 1,85 m); el dibujo es propio, sin calcar fotos ni planos.

Uso (desde la raíz del proyecto):  python tools/generar_sprites.py
Escribe assets/<tanque>.png, assets/<tanque>_enemigo.png y tools/vista_previa.png.
Sin dependencias: escribe los PNG a mano con zlib.
"""

import os
import struct
import zlib

ANCHO, ALTO = 80, 28  # lienzo simétrico: el casco queda centrado en x = 40
SUELO = ALTO - 1

# Paletas: mismas claves para todos, así el bando enemigo es un cambio de colores.
COMUNES = {
    "tdk": (34, 34, 32), "t": (62, 62, 58), "tlt": (98, 98, 92),
    "goma": (40, 40, 38), "sombra": (26, 26, 24), "borde": (20, 20, 16),
    "estrella": (222, 222, 210),
    "vidrio": (150, 196, 214), "helice": (150, 150, 140),
}
PALETAS = {
    "verde_oliva": {"dk": (52, 58, 33), "b": (86, 92, 52), "lt": (118, 124, 74), "hl": (152, 158, 100)},
    "verde_britanico": {"dk": (40, 50, 36), "b": (64, 78, 54), "lt": (92, 108, 76), "hl": (126, 142, 104)},
    "arena": {"dk": (138, 116, 76), "b": (184, 160, 108), "lt": (210, 190, 138), "hl": (232, 216, 170)},
    "verde_sovietico": {"dk": (56, 70, 40), "b": (90, 110, 62), "lt": (122, 142, 88), "hl": (160, 178, 120)},
    "gris_enemigo": {"dk": (50, 52, 58), "b": (82, 86, 94), "lt": (116, 120, 130), "hl": (154, 158, 168)},
    # Encalado de invierno soviético: cal blanca gastada sobre el verde 4BO.
    "invierno": {"dk": (138, 144, 146), "b": (196, 202, 204), "lt": (220, 224, 226), "hl": (240, 242, 244),
                 "parche": (84, 96, 54)},
}


class Lienzo:
    def __init__(self, paleta, con_estrella=True):
        self.px = {}
        self.pal = {**COMUNES, **PALETAS[paleta]}
        self.con_estrella = con_estrella

    def poner(self, x, y, c):
        if 0 <= x < ANCHO and 0 <= y < ALTO:
            self.px[(x, y)] = self.pal[c]

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.poner(x, y, c)

    def poligono(self, puntos, c):
        """Rellena los píxeles cuyo centro cae dentro del polígono."""
        xs = [p[0] for p in puntos]
        ys = [p[1] for p in puntos]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            for x in range(int(min(xs)), int(max(xs)) + 1):
                if _dentro(x + 0.5, y + 0.5, puntos):
                    self.poner(x, y, c)

    def circulo(self, cx, cy, r, c):
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                    self.poner(x, y, c)

    def linea_h(self, x0, x1, y, c, paso=1):
        for x in range(x0, x1 + 1, paso):
            self.poner(x, y, c)

    def linea_v(self, x, y0, y1, c):
        for y in range(y0, y1 + 1):
            self.poner(x, y, c)

    def contorno(self):
        """Borde oscuro de 1 px alrededor de la silueta, para que se lea sobre cualquier terreno."""
        borde = set()
        for (x, y) in self.px:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                v = (x + dx, y + dy)
                if v not in self.px and 0 <= v[0] < ANCHO and 0 <= v[1] < ALTO:
                    borde.add(v)
        for (x, y) in borde:
            self.px[(x, y)] = self.pal["borde"]

    def rueda(self, cx, cy, r):
        self.circulo(cx, cy, r, "goma")
        self.circulo(cx, cy, r - 0.9, "b")
        self.circulo(cx, cy, 0.7, "hl")

    def piñon(self, cx, cy, r):
        self.circulo(cx, cy, r, "t")
        for i, (dx, dy) in enumerate(((0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1))):
            if i % 2 == 0:
                self.poner(int(cx + dx * r), int(cy + dy * r), "tlt")
        self.circulo(cx, cy, r - 1.4, "dk")
        self.circulo(cx, cy, 0.8, "lt")

    def oruga(self, contorno, interior):
        self.poligono(contorno, "tdk")
        self.poligono(interior, "sombra")
        # Eslabones: puntos claros en el tramo que apoya en el suelo.
        xs = [p[0] for p in contorno]
        self.linea_h(int(min(xs)) + 4, int(max(xs)) - 4, SUELO, "t", 2)

    def estrella(self, cx, cy):
        """Estrella aliada de 5×3 px."""
        if self.con_estrella:
            for dx, dy in ((0, -1), (-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0), (-1, 1), (1, 1)):
                self.poner(cx + dx, cy + dy, "estrella")

    def desgaste(self):
        """Manchas de verde donde la cal se gastó (solo paletas con "parche")."""
        if "parche" not in self.pal:
            return
        base = self.pal["b"]
        for (x, y), c in list(self.px.items()):
            if c == base and ((x // 3) * 3 + (y // 2) * 5) % 13 == 0:
                self.px[(x, y)] = self.pal["parche"]

    def png(self, ruta, escala=1, fondo=None):
        filas = []
        for y in range(ALTO):
            fila = b""
            for x in range(ANCHO):
                c = self.px.get((x, y))
                rgba = bytes((*c, 255)) if c else (bytes((*fondo, 255)) if fondo else b"\0\0\0\0")
                fila += rgba * escala
            filas += [fila] * escala
        _escribir_png(ruta, filas, ANCHO * escala, ALTO * escala)


def _dentro(x, y, pts):
    dentro = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            dentro = not dentro
        j = i
    return dentro


def _escribir_png(ruta, filas, w, h):
    crudo = b"".join(b"\0" + f for f in filas)

    def bloque(tipo, datos):
        return (struct.pack(">I", len(datos)) + tipo + datos
                + struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF))

    with open(ruta, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(bloque(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)))
        f.write(bloque(b"IDAT", zlib.compress(crudo, 9)))
        f.write(bloque(b"IEND", b""))


# ---------------------------------------------------------------------------
# M4 Sherman temprano: 5,84 m de largo, 2,74 m de alto. Casco x 18-62.
# Suspensión VVSS: 3 bogies de 2 ruedas con rodillo de retorno encima.
# Piñón de tracción adelante (alto), rueda tensora atrás. Torreta fundida redondeada.
# ---------------------------------------------------------------------------
def sherman(l):
    l.oruga([(17, 23), (20, 20), (57, 19), (60, 17), (63, 19), (63, 23), (59, 27), (21, 27), (17, 25)],
            [(21, 22), (57, 21), (60, 20), (61, 23), (58, 25), (22, 25)])
    for c in (28, 39, 50):
        l.rect(c - 3, 21, c + 3, 22, "dk")
        l.rueda(c - 2.5, 24.5, 2.4)
        l.rueda(c + 2.5, 24.5, 2.4)
        l.circulo(c + 0.5, 20.5, 1.1, "tlt")
    l.circulo(20.5, 23.5, 2.6, "t")
    l.circulo(20.5, 23.5, 1.0, "dk")
    # Casco: cubierta plana, glacis inclinado y caja de transmisión redondeada al frente.
    l.poligono([(17, 12), (49, 12), (60, 17), (60, 20), (17, 20)], "b")
    l.poligono([(56, 16), (61, 17), (63, 19), (62, 21), (58, 21)], "b")
    l.linea_h(17, 49, 12, "hl")
    for i in range(11):
        l.poner(49 + i, 12 + i // 2, "lt")
    l.linea_h(17, 58, 19, "dk")
    l.linea_v(17, 12, 19, "dk")
    l.poligono([(50, 11), (54, 11), (56, 13), (50, 13)], "lt")  # capota del conductor
    l.linea_h(22, 40, 15, "dk")  # herramientas en el costado
    l.estrella(29, 16)
    l.piñon(59.5, 21, 3.2)
    # Torreta fundida, mantelete y cañón M3 de 75 mm (L/40).
    for y in range(6, 12):
        for x in range(28, 47):
            if ((x + 0.5 - 37) / 8.5) ** 2 + ((y + 0.5 - 11.5) / 5.6) ** 2 <= 1:
                l.poner(x, y, "b")
    l.linea_h(31, 42, 6, "hl")
    l.linea_h(29, 45, 11, "dk")
    l.rect(32, 5, 35, 5, "dk")  # escotilla del comandante
    l.rect(44, 8, 46, 11, "lt")
    l.linea_v(46, 8, 11, "dk")
    l.linea_h(47, 66, 8, "lt")
    l.linea_h(47, 66, 9, "dk")


# ---------------------------------------------------------------------------
# Centurion Mk1: casco 7,6 m, alto 3,0 m. Casco x 11-68.
# Faldones laterales sobre la oruga, 6 ruedas grandes (Horstmann, en pares).
# Tracción atrás, rueda tensora adelante. Torreta larga y baja; cañón de 17 libras con freno de boca.
# ---------------------------------------------------------------------------
def centurion(l):
    l.oruga([(10, 21), (14, 17), (64, 17), (68, 20), (66, 24), (62, 27), (16, 27), (10, 24)],
            [(13, 21), (64, 21), (63, 24), (17, 25)])
    for x in (21, 27, 35, 41, 49, 55):
        l.rueda(x, 24, 2.8)
    l.piñon(14, 21.5, 3.2)
    l.circulo(64.5, 21.5, 2.8, "t")
    l.circulo(64.5, 21.5, 1.0, "dk")
    # Casco con glacis largo.
    l.poligono([(9, 11), (55, 11), (69, 17), (69, 19), (9, 19)], "b")
    l.linea_h(9, 55, 11, "hl")
    for i in range(14):
        l.poner(55 + i, 11 + (i * 6) // 14, "lt")
    l.rect(8, 9, 14, 11, "dk")  # cajón trasero
    # Faldones (bazooka plates) en paneles.
    l.poligono([(12, 13), (65, 13), (67, 17), (67, 20), (12, 20)], "b")
    l.linea_h(12, 65, 13, "lt")
    l.linea_h(12, 67, 20, "dk")
    for x in range(21, 66, 9):
        l.linea_v(x, 14, 19, "dk")
    # Torreta: frente redondeado, bustle trasero con cajones.
    l.poligono([(22, 11), (23, 8), (27, 5), (46, 5), (51, 7), (53, 10), (53, 11)], "b")
    l.linea_h(27, 46, 5, "hl")
    l.linea_h(23, 53, 11, "dk")
    l.rect(25, 8, 33, 9, "dk")  # cajones de la torreta
    l.linea_h(26, 32, 8, "lt", 2)
    l.rect(30, 3, 34, 4, "lt")  # cúpula
    l.rect(52, 6, 55, 10, "lt")
    l.linea_v(55, 6, 10, "dk")
    # 17 libras: largo, con freno de boca.
    l.linea_h(56, 77, 7, "lt")
    l.linea_h(56, 77, 8, "dk")
    l.rect(77, 6, 79, 9, "b")
    l.linea_v(79, 6, 9, "dk")


# ---------------------------------------------------------------------------
# Carro Armato P26/40: 5,8 m de largo, 2,5 m de alto. Casco x 20-59.
# 8 ruedas chicas en 4 bogies con ballestas, 3 rodillos de retorno.
# Tracción adelante. Superestructura remachada, torreta facetada, cañón 75/34.
# ---------------------------------------------------------------------------
def p40(l):
    l.oruga([(20, 22), (23, 19), (54, 18), (57, 17), (60, 19), (60, 23), (56, 27), (23, 27), (20, 25)],
            [(23, 21), (55, 20), (57, 22), (55, 25), (24, 25)])
    for a in (27, 34, 41, 48):
        l.rect(a - 1, 22, a + 4, 23, "dk")
        for x in (a + 0.5, a + 3.5):  # ruedas chicas: goma y centro oscuro
            l.circulo(x, 25, 2.0, "goma")
            l.circulo(x, 25, 1.0, "dk")
    for x in (31, 39, 47):
        l.circulo(x, 19.5, 1.0, "tlt")
    l.circulo(22.5, 22.5, 2.5, "t")
    l.circulo(22.5, 22.5, 0.9, "dk")
    # Guardabarros y superestructura.
    l.poligono([(20, 14), (51, 14), (58, 17), (58, 19), (20, 19)], "b")
    l.linea_h(19, 60, 19, "dk")
    l.linea_h(20, 51, 14, "hl")
    for i in range(8):
        l.poner(51 + i, 14 + (i * 3) // 8, "lt")
    l.linea_h(22, 50, 16, "dk", 3)  # remaches
    l.linea_h(21, 29, 15, "dk", 2)  # rejillas del motor
    l.piñon(56, 20.5, 3.0)
    # Torreta facetada y 75/34.
    l.poligono([(31, 14), (33, 10), (36, 8), (46, 8), (49, 10), (50, 14)], "b")
    l.linea_h(36, 46, 8, "hl")
    l.linea_h(32, 49, 13, "dk")
    l.poner(35, 11, "dk")
    l.poner(41, 11, "dk")
    l.rect(49, 10, 51, 13, "lt")
    l.linea_v(51, 10, 13, "dk")
    l.linea_h(52, 66, 11, "lt")
    l.linea_h(52, 66, 12, "dk")


# ---------------------------------------------------------------------------
# Tren de rodaje italiano (M13/40 y sus semoventi): dos bogies de 4 ruedas chicas
# con ballestas encima, piñón adelante, rueda tensora atrás y 3 rodillos de retorno.
# Casco x 21-59 (4,9 m).
# ---------------------------------------------------------------------------
def _tren_m13(l):
    l.oruga([(21, 22), (24, 19), (55, 19), (58, 20), (59, 22), (56, 27), (24, 27), (21, 25)],
            [(24, 21), (55, 21), (56, 23), (55, 25), (25, 25)])
    for x0 in (27, 41):
        l.rect(x0, 22, x0 + 10, 23, "dk")  # ballesta
        for x in (x0 + 1, x0 + 4, x0 + 7, x0 + 10):
            l.circulo(x, 25, 1.6, "goma")
            l.circulo(x, 25, 0.7, "dk")
    for x in (31, 40, 49):
        l.circulo(x, 20, 0.9, "tlt")
    l.circulo(23.5, 23, 2.2, "t")
    l.circulo(23.5, 23, 0.8, "dk")
    l.piñon(56, 21.5, 2.6)


# ---------------------------------------------------------------------------
# Carro Armato M13/40: casco remachado de caja con el frente inclinado, torreta chica
# para dos con el cañón de 47/32 (corto y fino).
# ---------------------------------------------------------------------------
def m13_40(l):
    _tren_m13(l)
    l.poligono([(22, 13), (46, 13), (52, 15), (57, 18), (57, 19), (22, 19)], "b")
    l.linea_h(22, 46, 13, "hl")
    for i in range(6):
        l.poner(46 + i, 13 + i // 3, "lt")
    l.linea_h(23, 45, 15, "dk", 3)  # remaches
    l.linea_h(23, 31, 17, "dk", 2)  # rejillas del motor
    l.linea_h(22, 57, 19, "dk")
    # Torreta remachada y 47/32 con su máscara.
    l.poligono([(32, 13), (33, 9), (43, 9), (45, 11), (45, 13)], "b")
    l.linea_h(34, 42, 9, "hl")
    l.linea_h(33, 44, 12, "dk", 2)
    l.rect(45, 9, 46, 12, "lt")
    l.linea_v(46, 9, 12, "dk")
    l.linea_h(47, 57, 10, "lt")
    l.linea_h(47, 57, 11, "dk")


# ---------------------------------------------------------------------------
# Semovente da 75/18: el mismo chasis sin torreta, con una casamata baja (1,85 m)
# y el obús corto de 75/18 montado en la plancha delantera, un poco a un costado.
# ---------------------------------------------------------------------------
def semovente(l):
    _tren_m13(l)
    l.poligono([(22, 15), (26, 13), (45, 13), (54, 17), (57, 19), (22, 19)], "b")
    l.linea_h(26, 45, 13, "hl")
    for i in range(9):
        l.poner(45 + i, 13 + (i * 4) // 9, "lt")  # plancha delantera inclinada
    l.linea_h(24, 44, 16, "dk", 3)  # remaches
    l.linea_h(23, 29, 18, "dk", 2)
    l.linea_h(22, 57, 19, "dk")
    l.rect(33, 12, 38, 12, "dk")  # escotilla del jefe
    l.circulo(50.5, 15.5, 1.6, "lt")  # máscara del obús
    l.linea_h(52, 61, 15, "lt")
    l.linea_h(52, 61, 16, "dk")
    l.rect(61, 14, 62, 16, "b")  # boca


# ---------------------------------------------------------------------------
# Sherman Firefly (británico): el mismo casco del Sherman con el 17 libras,
# mucho más largo y con freno de boca, y la caja de la radio atrás de la torreta.
# ---------------------------------------------------------------------------
def firefly(l):
    sherman(l)
    l.rect(25, 7, 28, 10, "b")  # caja de la radio (bustle)
    l.linea_v(25, 7, 10, "dk")
    l.linea_h(25, 28, 7, "hl")
    l.linea_h(47, 76, 8, "lt")
    l.linea_h(47, 76, 9, "dk")
    l.rect(76, 7, 78, 10, "b")
    l.linea_v(78, 7, 10, "dk")


# ---------------------------------------------------------------------------
# Churchill Mk VII: 7,4 m de largo, 2,5 m de alto. Casco x 11-68.
# La oruga envuelve todo el costado (sube hasta el techo), 11 bogies de ruedas chicas,
# cajones con salidas de barro y puerta lateral. Torreta fundida y 75 mm corto.
# ---------------------------------------------------------------------------
def churchill(l):
    l.poligono([(10, 14), (13, 11), (66, 11), (69, 14), (69, 21), (65, 27), (15, 27), (10, 22)], "tdk")
    l.linea_h(14, 65, 11, "t", 2)  # eslabones del tramo superior
    l.linea_h(16, 64, SUELO, "t", 2)
    for i in range(11):
        l.circulo(16.5 + i * 4.6, 25, 1.7, "goma")
        l.circulo(16.5 + i * 4.6, 25, 0.7, "dk")
    l.piñon(13.5, 18.5, 2.8)  # tracción atrás, en alto
    l.circulo(66, 18.5, 2.4, "t")
    l.circulo(66, 18.5, 0.9, "dk")
    # Cajón lateral entre los tramos de oruga.
    l.rect(16, 13, 63, 22, "b")
    l.linea_h(16, 63, 13, "lt")
    l.linea_h(16, 63, 22, "dk")
    for x in range(19, 62, 6):
        l.rect(x, 20, x + 2, 21, "sombra")  # salidas de barro
    l.rect(37, 14, 42, 19, "lt")  # puerta de escape
    l.rect(38, 15, 41, 18, "b")
    # Techo y torreta.
    l.rect(15, 10, 64, 10, "b")
    l.linea_h(15, 64, 10, "hl")
    l.rect(58, 9, 63, 10, "lt")  # visor del conductor
    l.poligono([(32, 10), (33, 7), (36, 5), (47, 5), (50, 7), (51, 10)], "b")
    l.linea_h(36, 47, 5, "hl")
    l.linea_h(33, 50, 9, "dk")
    l.rect(37, 3, 41, 4, "lt")  # cúpula
    l.rect(50, 6, 52, 9, "lt")
    l.linea_v(52, 6, 9, "dk")
    l.linea_h(53, 63, 7, "lt")
    l.linea_h(53, 63, 8, "dk")


# ---------------------------------------------------------------------------
# T-34-85: casco 6,1 m, alto 2,7 m. Casco x 16-64.
# Suspensión Christie: 5 ruedas grandes sin rodillos de retorno, con hueco entre la 2ª
# y la 3ª. Tracción atrás. Planchas inclinadas, torreta grande y 85 mm largo.
# ---------------------------------------------------------------------------
def t34_85(l):
    l.oruga([(14, 22), (17, 19), (61, 19), (65, 21), (64, 24), (60, 27), (18, 27), (14, 24)],
            [(18, 22), (61, 21), (61, 24), (19, 25)])
    for x in (24, 31, 40, 47, 54):
        l.rueda(x, 23.6, 3.0)
    l.piñon(18, 22.5, 3.0)
    l.circulo(61, 22.5, 2.4, "t")
    l.circulo(61, 22.5, 0.9, "dk")
    l.poligono([(14, 19), (17, 13), (51, 13), (64, 19), (64, 20), (14, 20)], "b")
    l.linea_h(17, 51, 13, "hl")
    for i in range(13):
        l.poner(51 + i, 13 + (i * 6) // 13, "lt")
    l.linea_h(14, 64, 19, "dk")
    l.rect(21, 15, 25, 17, "lt")  # tanques de combustible externos
    l.linea_v(23, 15, 17, "dk")
    l.linea_h(28, 48, 16, "dk", 4)
    l.poligono([(27, 13), (28, 9), (31, 6), (48, 6), (51, 8), (52, 13)], "b")
    l.linea_h(31, 48, 6, "hl")
    l.linea_h(28, 51, 12, "dk")
    l.rect(31, 4, 35, 5, "lt")  # cúpula del comandante
    l.rect(51, 8, 53, 11, "lt")
    l.linea_v(53, 8, 11, "dk")
    l.linea_h(54, 79, 9, "lt")
    l.linea_h(54, 79, 10, "dk")
    l.desgaste()


# ---------------------------------------------------------------------------
# IS-2: casco 6,8 m, alto 2,7 m. Casco x 13-66.
# 6 ruedas por lado, 3 rodillos de retorno, tracción atrás. Glacis escalonado,
# torreta fundida enorme y cañón de 122 mm con freno de boca de doble cámara.
# ---------------------------------------------------------------------------
def is2(l):
    l.oruga([(12, 22), (15, 19), (63, 19), (67, 21), (66, 24), (62, 27), (16, 27), (12, 24)],
            [(16, 22), (63, 21), (63, 24), (17, 25)])
    for x in (21, 28, 35, 42, 49, 56):
        l.rueda(x, 24.4, 2.4)
    for x in (26, 38, 50):
        l.circulo(x, 20.5, 1.0, "tlt")
    l.piñon(15.5, 22, 2.8)
    l.circulo(63.5, 22, 2.4, "t")
    l.circulo(63.5, 22, 0.9, "dk")
    l.poligono([(12, 19), (14, 14), (55, 14), (60, 16), (61, 16), (66, 19), (66, 20), (12, 20)], "b")
    l.linea_h(14, 55, 14, "hl")
    for x in range(55, 61):
        l.poner(x, 14 + (x - 55) // 3, "lt")
    l.linea_h(60, 61, 16, "lt")
    for i in range(6):
        l.poner(61 + i, 16 + i // 2, "lt")
    l.linea_h(12, 66, 19, "dk")
    l.rect(18, 15, 22, 17, "lt")
    l.linea_v(20, 15, 17, "dk")
    l.poligono([(24, 14), (25, 10), (29, 6), (46, 6), (51, 9), (53, 14)], "b")
    l.linea_h(29, 46, 6, "hl")
    l.linea_h(25, 52, 13, "dk")
    l.rect(28, 4, 32, 5, "lt")
    l.rect(52, 8, 56, 12, "lt")  # mantelete grande
    l.linea_v(56, 8, 12, "dk")
    l.linea_h(57, 74, 9, "lt")
    l.linea_h(57, 74, 10, "dk")
    l.rect(75, 7, 79, 12, "b")  # freno de boca de doble cámara
    l.linea_v(77, 7, 12, "sombra")
    l.linea_v(79, 7, 12, "dk")
    l.desgaste()


# ---------------------------------------------------------------------------
# M18 Hellcat: cazatanques estadounidense, 5,4 m, muy bajo y el más rápido de la guerra.
# Casco x 19-61. 5 ruedas por lado con 4 rodillos de retorno, tracción adelante.
# Torreta abierta arriba y cañón de 76 mm largo con freno de boca.
# ---------------------------------------------------------------------------
def hellcat(l):
    l.oruga([(17, 22), (20, 19), (57, 19), (61, 20), (63, 22), (60, 27), (21, 27), (17, 25)],
            [(21, 22), (58, 21), (60, 23), (22, 25)])
    for x in (26, 32, 38, 44, 50):
        l.rueda(x, 24.4, 2.4)
    for x in (29, 35, 41, 47):
        l.circulo(x, 20.4, 0.9, "tlt")
    l.circulo(21, 22.5, 2.2, "t")
    l.circulo(21, 22.5, 0.8, "dk")
    l.piñon(58.5, 21.5, 2.8)
    # Casco bajo con glacis muy inclinado y costados en pendiente.
    l.poligono([(17, 19), (19, 15), (49, 15), (61, 18), (61, 20), (17, 20)], "b")
    l.linea_h(19, 49, 15, "hl")
    for i in range(12):
        l.poner(49 + i, 15 + (i * 3) // 12, "lt")
    l.linea_h(17, 61, 19, "dk")
    l.linea_h(21, 29, 17, "dk", 2)  # rejillas del motor (atrás)
    l.estrella(39, 17)
    # Torreta abierta: borde alto, sin techo (se ve el hueco oscuro).
    l.poligono([(30, 15), (31, 11), (34, 10), (45, 10), (47, 12), (48, 15)], "b")
    l.linea_h(34, 45, 10, "hl")
    l.rect(34, 11, 44, 11, "sombra")  # torreta abierta
    l.linea_h(31, 47, 14, "dk")
    l.rect(47, 11, 49, 14, "lt")
    l.linea_v(49, 11, 14, "dk")
    l.linea_h(50, 73, 12, "lt")
    l.linea_h(50, 73, 13, "dk")
    l.rect(73, 11, 75, 14, "b")  # freno de boca
    l.linea_v(75, 11, 14, "dk")


# ---------------------------------------------------------------------------
# M26 Pershing: tanque pesado estadounidense de 1945, 6,3 m. Casco x 15-64.
# 6 ruedas con 5 rodillos de retorno, tracción atrás. Torreta grande y cañón de 90 mm
# con freno de boca.
# ---------------------------------------------------------------------------
def pershing(l):
    l.oruga([(13, 22), (16, 19), (61, 19), (65, 21), (64, 24), (60, 27), (17, 27), (13, 24)],
            [(17, 22), (61, 21), (61, 24), (18, 25)])
    for x in (21, 28, 35, 42, 49, 56):
        l.rueda(x, 24.4, 2.5)
    for x in (24, 31, 38, 45, 52):
        l.circulo(x, 20.4, 0.9, "tlt")
    l.piñon(16.5, 22, 2.8)
    l.circulo(61.5, 22, 2.4, "t")
    l.circulo(61.5, 22, 0.9, "dk")
    l.poligono([(13, 19), (15, 14), (52, 14), (64, 18), (64, 20), (13, 20)], "b")
    l.linea_h(15, 52, 14, "hl")
    for i in range(12):
        l.poner(52 + i, 14 + (i * 4) // 12, "lt")
    l.linea_h(13, 64, 19, "dk")
    l.linea_h(17, 27, 16, "dk", 2)
    l.estrella(40, 16)
    l.poligono([(24, 14), (25, 10), (29, 7), (46, 7), (50, 9), (52, 14)], "b")
    l.linea_h(29, 46, 7, "hl")
    l.linea_h(25, 51, 13, "dk")
    l.rect(29, 5, 33, 6, "lt")  # cúpula
    l.rect(51, 8, 54, 12, "lt")
    l.linea_v(54, 8, 12, "dk")
    l.linea_h(55, 76, 10, "lt")
    l.linea_h(55, 76, 11, "dk")
    l.rect(76, 8, 79, 12, "b")  # freno de boca
    l.linea_v(79, 8, 12, "dk")


# nombre: (función, paleta, con estrella, genera variante gris _enemigo)
TANQUES = {
    "sherman": (sherman, "verde_oliva", True, True),
    "centurion": (centurion, "verde_britanico", True, True),
    "p40": (p40, "arena", False, True),
    "m13_40": (m13_40, "arena", False, False),
    "semovente": (semovente, "arena", False, False),
    "firefly": (firefly, "verde_britanico", False, False),
    "churchill": (churchill, "verde_britanico", False, False),
    "t34_85": (t34_85, "invierno", False, False),
    "is2": (is2, "invierno", False, False),
    "hellcat": (hellcat, "verde_oliva", True, False),
    "pershing": (pershing, "verde_oliva", True, False),
}


# ===========================================================================
# Aviones de apoyo (vista lateral, mirando a la derecha). No van a escala: se ajustan
# al mismo lienzo de 80x28 que los tanques. Sin insignias. Dibujo propio a partir de
# medidas y siluetas generales públicas.
# ===========================================================================
def _helice(l, x, cy):
    l.circulo(x - 1, cy, 2.0, "tdk")  # buje
    for y in range(cy - 9, cy + 10, 2):  # hélice girando: borrosa
        l.poner(x + 1, y, "helice")


def _cola(l, x0, cy):
    l.poligono([(x0, cy - 1), (x0 + 1, cy - 9), (x0 + 5, cy - 9), (x0 + 10, cy - 2)], "b")
    l.linea_h(x0 + 1, x0 + 5, cy - 9, "hl")
    l.linea_h(x0 - 1, x0 + 11, cy + 1, "dk")  # estabilizador horizontal


# Hawker Typhoon: radiador grande bajo el morro, cabina de burbuja y cohetes RP-3.
def typhoon(l):
    cy = 12
    l.poligono([(4, 11), (12, 10), (56, 9), (68, 10), (74, 12), (72, 16), (64, 17), (48, 17), (28, 15), (10, 14), (4, 13)], "b")
    l.linea_h(12, 56, 9, "hl")
    l.poligono([(58, 15), (68, 15), (68, 20), (60, 20)], "dk")  # radiador bajo el morro
    l.poligono([(45, 9), (48, 5), (54, 5), (57, 9)], "vidrio")
    l.linea_v(51, 5, 8, "dk")
    _cola(l, 4, cy - 1)
    l.poligono([(32, 15), (58, 15), (60, 17), (34, 17)], "lt")  # ala
    for y in (18, 20):  # cohetes RP-3 bajo el ala
        l.linea_h(38, 54, y, "tlt")
        l.poner(55, y, "estrella")
    _helice(l, 75, cy + 1)


# Ilyushin Il-2 Shturmovik: biplaza blindado, cabina alta y larga, ala gruesa y bombas.
def il2(l):
    cy = 12
    l.poligono([(4, 12), (12, 11), (40, 9), (64, 9), (72, 11), (74, 13), (72, 16), (60, 18), (30, 17), (10, 15), (4, 14)], "b")
    l.linea_h(40, 64, 9, "hl")
    l.poligono([(40, 9), (43, 5), (57, 5), (60, 9)], "vidrio")
    for x in (46, 51, 55):
        l.linea_v(x, 5, 8, "dk")
    l.linea_h(62, 72, 13, "dk", 2)  # escapes del motor
    _cola(l, 4, cy)
    l.poligono([(30, 15), (58, 15), (62, 18), (34, 19)], "lt")  # ala gruesa
    for x in (42, 50):  # contenedores de bombas PTAB
        l.poligono([(x - 3, 20), (x + 3, 20), (x + 4, 21), (x + 3, 22), (x - 3, 22)], "tdk")
    _helice(l, 75, cy + 1)


# Republic P-47 Thunderbolt: morro redondo enorme (motor radial), burbuja y una bomba.
def p47(l):
    cy = 13
    l.poligono([(4, 12), (12, 11), (40, 9), (56, 8), (68, 7), (73, 9), (74, 13), (73, 18), (68, 20), (56, 19), (30, 17), (10, 15), (4, 14)], "b")
    l.linea_h(40, 68, 8, "hl")
    l.linea_v(67, 8, 19, "dk")  # anillo del capó
    l.poligono([(42, 8), (44, 4), (52, 4), (55, 8)], "vidrio")
    _cola(l, 4, cy - 1)
    l.poligono([(34, 16), (60, 16), (62, 18), (36, 19)], "lt")
    l.poligono([(44, 21), (56, 21), (58, 22), (56, 23), (44, 23)], "tdk")  # bomba
    l.linea_v(45, 20, 23, "t")
    _helice(l, 76, cy)


# Fiat CR.42 Falco: biplano con motor radial, cabina abierta y tren fijo carenado.
def cr42(l):
    cy = 12
    l.poligono([(10, 12), (18, 11), (50, 10), (64, 10), (70, 11), (72, 13), (70, 16), (64, 17), (40, 16), (18, 14), (10, 14)], "b")
    l.linea_h(18, 64, 10, "hl")
    l.rect(66, 10, 70, 16, "dk")  # capó del radial
    l.linea_h(42, 46, 9, "vidrio")  # parabrisas de la cabina abierta
    l.rect(38, 3, 62, 4, "lt")  # ala de arriba
    l.linea_h(38, 62, 3, "hl")
    for x in (44, 56):
        l.linea_v(x, 5, 9, "t")  # montantes
    l.rect(40, 15, 60, 16, "lt")  # ala de abajo
    l.poligono([(55, 17), (60, 17), (60, 22), (55, 22)], "b")  # tren carenado
    l.circulo(57.5, 23.5, 2.0, "goma")
    _cola(l, 10, cy)
    _helice(l, 73, cy + 1)


AVIONES = {
    "typhoon": (typhoon, "verde_britanico"),
    "il2": (il2, "verde_sovietico"),
    "p47": (p47, "verde_oliva"),
    "cr42": (cr42, "arena"),
}


def generar(raiz):
    assets = os.path.join(raiz, "assets")
    hojas = []
    for nombre, (dibujar, paleta, estrella, con_enemigo) in TANQUES.items():
        variantes = [("", paleta, estrella)]
        if con_enemigo:
            variantes.append(("_enemigo", "gris_enemigo", False))
        for sufijo, pal, est in variantes:
            l = Lienzo(pal, est)
            dibujar(l)
            l.contorno()
            l.png(os.path.join(assets, f"{nombre}{sufijo}.png"))
            if not sufijo:
                hojas.append(l)
    for nombre, (dibujar, paleta) in AVIONES.items():
        l = Lienzo(paleta, False)
        dibujar(l)
        l.contorno()
        l.png(os.path.join(assets, "aviones", f"{nombre}.png"))
        hojas.append(l)
    # Vista previa ×6, de a 4 tanques por fila.
    esc, fondo, por_fila = 6, (214, 222, 200), 4
    filas = []
    for i in range(0, len(hojas), por_fila):
        fila = hojas[i:i + por_fila]
        fila += [Lienzo("arena")] * (por_fila - len(fila))
        for y in range(ALTO):
            linea = b""
            for l in fila:
                for x in range(ANCHO):
                    c = l.px.get((x, y), fondo)
                    linea += bytes((*c, 255)) * esc
            filas += [linea] * esc
    _escribir_png(os.path.join(raiz, "tools", "vista_previa.png"), filas,
                  ANCHO * esc * por_fila, len(filas))


if __name__ == "__main__":
    generar(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
