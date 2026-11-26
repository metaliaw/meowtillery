"""Dibuja la copa de los trofeos (assets/trofeo.png), pixel a pixel. Arte propio."""
import os
from PIL import Image

COPA = [
    ".................",
    "...###########...",
    ".##hhhyyyyyyyo##.",
    "#..#hhyyyyyyo#..#",
    "#..#hyyyyyyyo#..#",
    ".#.#hyyyyyyyo#.#.",
    "..##yyyyyyyyo##..",
    "....#yyyyyyo#....",
    ".....#yyyyo#.....",
    "......#yyo#......",
    ".......#o#.......",
    ".......#o#.......",
    ".....#ooooo#.....",
    "....#bbbbbbb#....",
    "....#########....",
    ".................",
]
COLORES = {"#": (28, 26, 36, 255), "y": (255, 204, 77, 255), "h": (255, 240, 170, 255),
           "o": (214, 146, 40, 255), "b": (120, 84, 60, 255)}


def main():
    ancho = max(len(f) for f in COPA)
    img = Image.new("RGBA", (ancho, len(COPA)), (0, 0, 0, 0))
    for y, fila in enumerate(COPA):
        for x, c in enumerate(fila):
            if c in COLORES:
                img.putpixel((x, y), COLORES[c])
    raiz = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    img.save(os.path.join(raiz, "assets", "trofeo.png"))


if __name__ == "__main__":
    main()
