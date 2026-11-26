"""Revisa la traducción al inglés (data/idioma/en.json).

Junta todos los textos que el juego muestra:
  - los tr("...") y TranslationServer.translate("...") de scripts/,
  - los textos de las constantes que se traducen al usarlas (dificultades, Michi, dado,
    tutorial, mapas),
  - los campos de texto de data/ (los mismos que traduce Datos.leer),
y avisa cuáles faltan en en.json y cuáles sobran.

Uso (desde la raíz del proyecto):
  python tools/revisar_traduccion.py              # informe
  python tools/revisar_traduccion.py --faltantes  # escribe los que faltan en
                                                   # data/idioma/faltantes.json para traducirlos
"""
import glob
import json
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EN = os.path.join(RAIZ, "data", "idioma", "en.json")
CAMPOS_DE_TEXTO = {"nombre", "nombre_corto", "texto", "lema", "descripcion", "mania_texto", "pais", "anio",
                   "peso", "canon", "blindaje", "velocidad", "armamento", "dato", "gato"}
# Constantes cuyos textos se pasan por tr() donde se usan.
CONSTANTES = {
    "partida.gd": ["OFICIAL", "DIFICULTADES", "MAPAS"],
    "combate.gd": ["EVENTOS_FRENTE"],
    "tutorial.gd": ["PAGINAS", "NOMBRES"],
    "campana.gd": ["NOMBRES_DIFICULTAD"],
}
LITERAL = r'"((?:[^"\\]|\\.)*)"'


def decodificar(s):
    return re.sub(r'\\(.)', lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s, flags=re.S)


def visible(s):
    if s.startswith(("res://", "user://")):
        return False
    sin_formato = re.sub(r"%[-+0-9.]*[sdif%]", "", s)
    return bool(re.search(r"[A-Za-zÁÉÍÓÚáéíóúñÑ]", sin_formato)) and not re.fullmatch(r"[a-z_0-9:/.]+", s)


def textos():
    claves = []

    def agregar(s):
        if s and s not in claves:
            claves.append(s)

    for ruta in sorted(glob.glob(os.path.join(RAIZ, "scripts", "*.gd"))):
        t = open(ruta, encoding="utf-8").read()
        for m in re.finditer(r'(?:\btr|TranslationServer\.translate)\(\s*' + LITERAL, t, re.S):
            agregar(decodificar(m.group(1)))
        for nombre in CONSTANTES.get(os.path.basename(ruta), []):
            m = (re.search(r"^const " + nombre + r"\b[^\n]*[\[{]\n.*?^[\]}]", t, re.S | re.M)
                 or re.search(r"^const " + nombre + r"\b[^\n]*", t, re.M))
            assert m, (ruta, nombre)
            bloque = re.sub(r"#[^\n\"]*$", "", m.group(0), flags=re.M)
            for lit in re.finditer(LITERAL + r"(\s*:)?", bloque, re.S):
                s = decodificar(lit.group(1))
                es_clave = lit.group(2) is not None
                if visible(s) and (not es_clave or nombre == "MAPAS"):
                    agregar(s)

    def recorrer(x):
        if isinstance(x, dict):
            for k, v in x.items():
                if isinstance(v, str) and k in CAMPOS_DE_TEXTO and visible(v):
                    agregar(v)
                else:
                    recorrer(v)
        elif isinstance(x, list):
            for v in x:
                recorrer(v)

    for ruta in sorted(glob.glob(os.path.join(RAIZ, "data", "*.json")) +
                       glob.glob(os.path.join(RAIZ, "data", "mapas", "*.json"))):
        if os.path.basename(ruta) == "dedicatoria.json":  # personal: no se traduce
            continue
        recorrer(json.load(open(ruta, encoding="utf-8")))
    return claves


def main():
    claves = textos()
    en = json.load(open(EN, encoding="utf-8")) if os.path.exists(EN) else {}
    faltan = [c for c in claves if not en.get(c)]
    sobran = [c for c in en if c not in claves]
    print(f"{len(claves)} textos, {len(claves) - len(faltan)} traducidos, faltan {len(faltan)}, sobran {len(sobran)}")
    for c in faltan[:40]:
        print("  falta:", repr(c[:100]))
    for c in sobran[:40]:
        print("  sobra:", repr(c[:100]))
    # Los %s/%d tienen que ser los mismos y en el mismo orden (GDScript los llena por posición).
    formato = lambda s: re.findall(r"%[-+0-9.]*[sdif%]", s)
    malos = [c for c in claves if en.get(c) and formato(c) != formato(en[c])]
    for c in malos:
        print("  formato distinto:", repr(c[:80]), formato(c), formato(en[c]))
    faltan += malos
    if "--faltantes" in sys.argv:
        ruta = os.path.join(RAIZ, "data", "idioma", "faltantes.json")
        json.dump({c: "" for c in faltan}, open(ruta, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print("escrito", ruta)
    sys.exit(1 if faltan else 0)


if __name__ == "__main__":
    main()
