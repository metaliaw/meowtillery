# Tanques Kawaii (prototipo)

Táctica por turnos en grilla al estilo **Fire Emblem**, donde las acciones salen de un
**mazo de cartas** (al estilo Slay the Spire). Pixel art 2D, hecho en **Godot 4.3+** con GDScript.

## Cómo abrirlo

1. Instala Godot 4 (versión estándar, no .NET): <https://godotengine.org/download>
   o con `winget install GodotEngine.GodotEngine`.
2. En el Project Manager: **Importar** → elige `project.godot` de esta carpeta.
3. Pulsa **F5** para jugar.

Pruebas de la lógica (sin abrir ventana), desde esta carpeta:

```powershell
godot --headless --path . -s tests/test_combate.gd
```

## Cómo se juega

- **Batallones y gatos.** Antes del combate se elige batallón: **británico** (3 tanques,
  precisión y té) o **soviético** (4 tanques, ataques en grupo y humo); el otro es el rival.
  Cada tanque lo comanda un gato con una **manía** que cambia las reglas para él:
  *ritual del té* (quieto recupera moral), *asustadizo* (por detrás pierde 2 de moral),
  *terca* (girar cuesta 1 más), *recarga lenta* (un ataque por turno), *camarada* (+1 de
  daño con un compañero pegado) y *valiente* (los golpes no lo dejan en pánico).
  El mazo es el general más las cartas del batallón.
- **Fase del jugador.** Clic en un tanque tuyo para elegirlo: en azul, a dónde puede
  moverse. Clic en una casilla azul para moverlo (puedes repartir su movimiento en
  varios pasos). Clic en un enemigo para elegirlo como blanco: en rojo, lo que puede
  atacar en su fase. El marco amarillo muestra las casillas a tiro de tus cartas.
- **Cartas.** El pelotón comparte 3 de energía y una mano de 5 cartas por turno.
  Las cartas de ataque tienen **alcance** (distancia en casillas). Al pasar el mouse
  sobre una carta se ve qué haría: el daño sobre cada enemigo afectado (en rojo si lo
  derriba), la cuenta del blindaje y cuánto entraría por frente, flanco y trasera.
- **Orientación y blindaje.** Cada tanque mira hacia donde dio su último paso (la
  flecha amarilla). Su blindaje es distinto de **frente**, **flanco** y **trasera**:
  disparar a un costado o por detrás hace mucho más daño.
  Daño que entra = daño − (blindaje del lado + cobertura del terreno − penetración), mínimo 1.
- **Terreno.** Llano (coste 1), bosque (coste 2, +1 cobertura), ruinas (coste 2,
  +2 cobertura) y roca (intransitable).
- **Moral.** Cada impacto de 5 o más baja 1 de moral. Con 0 la tripulación entra en
  pánico y ese tanque no puede atacar (*Arenga* la recupera). Un enemigo en pánico
  pierde su turno y se recupera.
- **Fase enemiga.** Actúan como máximo 3 enemigos por turno (los más cercanos a tus
  tanques); si hay más, el resto queda **en reserva** (se ven oscurecidos y con "zZ").
  Así los 4 soviéticos tienen más cuerpos, pero no más acciones. Cada enemigo anuncia su acción. Si es un disparo, se acerca al
  aliado más cercano buscando pegarle por el flanco o la trasera.

## Estructura

| Carpeta / archivo | Qué contiene |
|---|---|
| `data/mapa.json` | Terreno (filas de letras) y posiciones iniciales. |
| `data/batallones.json` | Batallones: lema, cartas propias y unidades (gato, tanque, casco, blindaje por lado, movimiento, moral, manía, acciones cuando es el rival). |
| `data/cartas.json`, `mazo_inicial.json` | Cartas (las de un batallón llevan `"batallon"`) y mazo general. Para equilibrar el juego, se edita aquí. |
| `scripts/partida.gd`, `scripts/eleccion.gd` | Autoload `Partida` (batallón elegido y armado del combate) y pantalla de elegir batallón. |
| `tools/gatos/` | `generar_gatos.py` dibuja los gatos tanquistas (`assets/gatos/`) con la base de Muffy (`muchi.py`, `pixlib.py`), cambiando pelaje, ojos, marcas, gorro (boina, shlemofon con gafas o gorra de oficial) y carácter (Michi es "mañosa": frunce el ceño en reposo). Requiere Pillow. |
| `tests/datos/` | Unidades fijas de prueba, para que las pruebas no cambien al equilibrar. |
| `scripts/mapa.gd` | Grilla, costes y búsqueda de caminos. |
| `scripts/combate.gd` | Toda la lógica del combate y la IA, sin nodos (se prueba sola). |
| `scripts/tablero.gd` | Dibuja el mapa, unidades y resaltados. |
| `scripts/escena_combate.gd` | Interfaz: fichas, mano de cartas, registro. |
| `scripts/menu.gd`, `scripts/tutorial.gd` | Pantalla de inicio y tutorial de 10 páginas guiado por Muffy (instructora) y la teniente Michi (explica las cartas). |
| `scripts/gato_animado.gd` | Anima a un gato desde su hoja de sprites. Por defecto, Muffy (`assets/muchi/`, el archivo conserva el nombre original del personaje; arte propio de la autora, todos los derechos reservados). |
| `scripts/estilo.gd` | Estética común tipo Balatro: tapete, botones-carta, títulos. |
| `assets/fuentes/` | [Pixelify Sans](https://github.com/eifetx/Pixelify-Sans), SIL Open Font License 1.1 (`OFL.txt`): se puede incluir y vender con el juego, siempre que la licencia vaya junto a la fuente. Se usa sin suavizado (`Estilo.fuente()`). |
| `assets/sonidos/` | Efectos CC0 (Kenney y OpenGameArt). Origen de cada uno en `CREDITOS.txt`. |
| `scripts/sonido.gd` | Autoload `Sonido`: todos los botones suenan solos (hover, clic, error si está deshabilitado); el combate avisa disparos, derribos y movimientos con la señal `evento` y suenan en cola. |
| `tools/generar_terreno.py` | Dibuja las losetas-carta del terreno (`assets/terreno/`). |
| `tests/test_combate.gd` | Pruebas de la lógica. |
| `assets/` | Sprites. Los tanques son de 80×28 px a escala real (1 px = 13 cm) y se dibujan a ×1 en casillas de 64 px; la variante `_enemigo` es el mismo tanque en gris. |
| `tools/generar_sprites.py` | Dibuja los sprites de tanques por código (`python tools/generar_sprites.py`). `tools/vista_previa.png` los muestra ampliados. |

### Campos de una carta

`coste`, `tipo` (`ataque` / `defensa` / `maniobra` / `apoyo`), `dano`, `penetracion`,
`alcance` ([mín, máx]), `bonus_flanco`, `salpicadura`, `escudo`, `radio` (a quién más
afecta, en casillas), `encarar` + `requiere_objetivo`, `movimiento`, `moral`, `energia`, `texto`.

## Publicar en la web (GitHub Pages)

El proyecto ya usa el renderizador *Compatibility* (WebGL 2), que es el que necesita
la exportación web. Pasos, cuando toque:

1. En Godot: **Editor → Manage Export Templates** → descargar las plantillas.
2. **Project → Export → Add… → Web**. Dejar **Thread Support desactivado**: así no hace
   falta configurar cabeceras especiales, que GitHub Pages no permite.
3. Exportar como `index.html` a una carpeta (por ejemplo `build/web`) y publicarla
   en GitHub Pages (se puede automatizar con una GitHub Action).

## Pendiente

- Más batallones (estadounidense, francés, italiano, de Alemania Oriental…).
- Ojo con las fuentes de arte: los mapas de Dice Grimorium no publican licencia de uso
  comercial; usar arte propio o CC0 (p. ej. Kenney.nl).
- Línea de visión (hoy se dispara a través de todo).
- Muerte permanente de la tripulación entre batallas, campaña con varios mapas,
  recompensas de cartas y guardado.
- Animaciones de movimiento y disparo (los sonidos ya están). Música.

## Tanques reales de referencia y derechos

Los tanques están **inspirados** en el Centurion Mk1, el Sherman Firefly, el Churchill
Mk VII, el IS-2 y el T-34-85 (y, sin usar por ahora, el M4 Sherman temprano y el P40).
Los Firefly, Churchill, IS-2 y T-34-85 se dibujaron con medidas públicas generales, sin
calcar ningún plano ni foto. No llevan insignias nacionales ni políticas. La forma de un vehículo real no es el problema:
lo protegido son los *dibujos y fotos concretos* de otros. Regla: usar las fuentes
como **referencia** y dibujar los sprites propios; no calcar ni recortar imágenes.

- **Sherman:** los manuales técnicos del ejército de EE. UU. (serie TM 9-731) son
  obras del gobierno federal y, por eso, de dominio público en EE. UU. Ej.:
  [TM 9-731E en Internet Archive](https://ia800201.us.archive.org/35/items/TM9-731E/TM9-731E.pdf).
- **Centurion Mk1:** la *Crown copyright* británica de obras publicadas dura 50 años
  desde su publicación, así que manuales de los años 40-50 deberían estar libres.
  Los planos de diseño nunca publicados pueden seguir protegidos. Hay archivo en el
  [Tank Museum](https://tankmuseum.org/) y registros en The National Archives.
- **P40:** no se encontró una fuente confirmada de planos originales de Ansaldo/Fiat
  en dominio público. Usar fotos de los dos ejemplares que se conservan como referencia.
- **Referencias usadas para los sprites** (solo proporciones; el dibujo es propio):
  [TM 9-731B, 1943](https://commons.wikimedia.org/wiki/File:TM_9-731B_Medium_Tank_M4A2_(1943).djvu) (dominio público),
  [Centurion Mk VII, foto CC0](https://commons.wikimedia.org/wiki/File:Centurion_Mk_VII_(Panzer_57)_pic05.JPG)
  (mismo casco y tren de rodaje que el Mk1) y
  [Ansaldo P40, foto de época](https://commons.wikimedia.org/wiki/File:Ansaldo_P40_01.jpg) (dominio público).
- **Ojo:** los planos de sitios como the-blueprints.com son redibujos modernos con
  autor; no son planos originales y no deben copiarse.

Esto no es asesoría legal; antes de vender el juego conviene una consulta rápida.
