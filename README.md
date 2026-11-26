# Meowtillery

**Turn-based WWII tank tactics, with cards — and the crews are cats.** 🐾

**▶ Play in your browser:** <https://metaliaw.github.io/meowtillery/> (press **English** in the top-right corner of the menu)

![Battle in the desert](docs/capturas/combate.png)

A small pixel-art game made in Godot as a gift for a young tank fan: grid tactics in the
style of *Fire Emblem*, where every action comes from a hand of cards like in *Slay the
Spire*. Every tank is crewed by a cat with a quirk of its own, and every tank is a real one.

- **4 battalions, 11 real tanks.** British (Centurion Mk 1, Sherman Firefly, Churchill
  Mk VII), Soviet (IS-2, T-34-85), American (M4 Sherman, M18 Hellcat, M26 Pershing) and
  Italian (M13/40, Semovente da 75/18, P26/40).
- **Armor that matters.** Each tank has front, flank and rear armor; cards have damage and
  pierce. Flank them, use cover, keep line of sight, and watch your facing — the Semovente
  has no turret, so it has to turn to shoot.
- **Cats with quirks.** Earl Grey regains morale drinking tea, Boris's 122 mm hits hard but
  reloads slowly, Cannoli hits harder from ambush, Panettone's rivets pop on big hits…
- **Air support** on the harder difficulties: Typhoon, Il-2 Shturmovik, P-47 Thunderbolt
  and CR.42 Falco. On Ace the enemy calls one in too — get out of the red crosshair!
- **Frontline Die** on turn 3: rain, fog, supplies, letters from home, a breakdown, or fish
  for everyone.
- **Campaign** of 5 battles on 5 maps (hills, forest, El Alamein desert with a minefield, a
  river with a bridge and a ford, and a ruined city), medals for the surviving cats, loot
  cards for your Arsenal, and **18 trophies** to collect.
- **Tech sheets** with real data and a "did you know?" for every tank and plane.
- **Kill cam** — and don't worry: when a tank is knocked out, its cat always jumps out and
  escapes safely.

| | |
|---|---|
| ![Kill cam](docs/capturas/killcam.png) | ![Choose your battalion](docs/capturas/batallones.png) |
| ![Frontline Die](docs/capturas/dado.png) | ![Tech sheets](docs/capturas/fichas.png) |

Also available for Windows (zip, no install needed) — see *Exportar* below. The art is
drawn by code (`tools/`), with no copied images; tanks carry no national or political
insignia. Sounds are CC0 (Kenney, OpenGameArt) and Lieutenant Michi's voice is a real cat.
The game is written in Spanish and translated into English (`data/idioma/en.json`).

---

# Meowtillery (prototipo, en español)

Táctica por turnos en grilla al estilo **Fire Emblem**, donde las acciones salen de un
**mazo de cartas** (al estilo Slay the Spire) y los tanques los comandan **gatos**.
Pixel art 2D, hecho en **Godot 4.3+** con GDScript.

**Jugar en el navegador:** <https://metaliaw.github.io/meowtillery/>
(la versión web vive en `docs/` y GitHub Pages la publica desde ahí).

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

- **Batalla suelta o campaña.** *Batalla suelta*: una pelea con el batallón, rival y
  dificultad que elijas. *Campaña*: 5 batallas seguidas (Recluta → Veterano → As) en
  tres mapas (`data/mapas/`: las colinas, el bosque espeso y la ciudad en ruinas). Cada
  gato que sigue en pie al ganar recibe una **medalla** (★, +2 de vida para el resto de la
  campaña), y tras cada victoria se elige una de 3 cartas para el Arsenal. Si pierdes,
  reintentas esa batalla. Se guarda sola en `user://campana.json`.
- **Fichas técnicas.** Desde el menú: los 11 tanques y los 4 aviones con su sprite, datos reales
  (país, peso, cañón, blindaje, velocidad, cuántos se fabricaron) y un "¿Sabías que…?".
- **Batallones y gatos.** Antes del combate se elige batallón y rival (o rival al azar).
  Todas las peleas son **3 contra 3**: **británico** (precisión y té), **soviético**
  (ataques en grupo, humo y la carta *¡Refuerzos!* de Boris, que trae a Mishka en un
  cuarto T-34 una vez por batalla), **estadounidense** (Maine Coons: reparan con el
  *Taller de campaña*, piden *artillería* que ignora la cobertura y tienen el Hellcat,
  el cazatanques más rápido de la guerra) e **italiano** (gatos atigrados con casco de
  cuero: blindaje delgado, pero emboscan. El *Semovente da 75/18* no tiene torreta: solo
  dispara a lo que tiene al frente, pero es tan bajo que siempre tiene +1 de cobertura.
  Cartas *Proyectil EP* (carga hueca: perfora 5 y nunca roza), *Camuflaje* (no le
  disparan desde 3 o más hasta que se mueva o dispare), *Espresso* y *¡Avanti!*).
  Cada tanque lo comanda un gato con una **manía** que cambia las reglas para él:
  *ritual del té* (quieto recupera moral), *asustadizo* (por detrás pierde 2 de moral),
  *escaladora* (bosque y ruinas le cuestan 1, como al Churchill real), *recarga lenta* (un ataque por turno), *camarada* (+1 de
  daño con un compañero pegado), *valiente* (los golpes no lo dejan en pánico),
  *mecánico* (repara 2 a un compañero pegado al final del turno), *velocista* (6 de
  movimiento, blindaje delgado), *glotón* (si no ataca, recupera 1 de moral),
  *dramático* (si recibe 5 o más, el resto del pelotón gana 1 de moral), *emboscador*
  (si no se movió, pega +2) y *remachado* (si le entran 7 o más, recibe 1 extra).
  **Cada gato tiene sus propias cartas** (no hay mazo compartido): el cañón de su
  tanque, dos cartas propias y *Encarar*, que todos tienen. Se elige un tanque y abajo
  aparecen las suyas. Todos comparten 3 de energía por turno; cada carta se usa una
  vez por turno y algunas tienen **recarga** (turnos que hay que esperar).
- **Botín y Arsenal.** Al derribar un enemigo se elige una de sus dos cartas propias como
  **botín**: es de un solo uso y la puede jugar cualquier tanque (sale en dorado junto a
  las cartas del gato elegido). Al terminar o abandonar la batalla, el botín sin usar va
  al **Arsenal** (`user://arsenal.json`, hasta 12 cartas). En la pantalla de batallón se
  eligen hasta 2 cartas del Arsenal para llevar; usarlas las gasta.
- **Apuntar.** Disparar a un blanco que no está en tu frente (las diagonales exactas
  cuentan como frente) resta 2 de daño. *Encarar* hacia el blanco lo evita y, de paso,
  le da tu frente blindado. La moral máxima es 5.
- **Apoyo aéreo (Veterano y As).** Una vez por batalla, cualquier tanque puede pedir el
  avión de su batallón (cuesta 2 de energía). Marca a un enemigo y el avión lo busca al
  empezar tu próximo turno; pega desde arriba (el techo, tan delgado como la trasera),
  sin cobertura ni línea de visión. *Typhoon* (británico): cohetes, 8 de daño. *Il-2*
  (soviético): 5 al blanco y 3 a los pegados. *P-47* (estadounidense): 7 y -1 de moral.
  *CR.42* (italiano): cuesta 1 y pega ya mismo, pero solo 5. En **As** el rival también
  tiene el suyo: desde el turno 3 marca con una mira roja la casilla de tu tanque más
  dañado y ataca al empezar su fase; si lo sacas de ahí, falla. Los aviones están en las
  fichas técnicas y se dibujan en `tools/generar_sprites.py` (`assets/aviones/`).
- **Dado del frente.** Al empezar el turno 3 de cada batalla se tira un dado y pasa algo
  ese turno (el tuyo y la fase enemiga): 1 lluvia (todos mueven 1 menos), 2 niebla (nadie
  dispara a más de 2), 3 suministros (+1 energía), 4 cartas de casa (+1 moral), 5 avería
  (un enemigo no actúa, cartelito "!!") y 6 pescado para todos (reparas 2). En Recluta
  solo salen del 3 al 6. Usa su propio generador, así que no cambia el resto de una
  partida con semilla. Constantes en `Combate.EVENTOS_FRENTE`.
- **Trofeos.** 18 logros en `data/trofeos.json` (autoload `Trofeos`, guardados en
  `user://trofeos.json`), con una vitrina en el menú. El combate avisa las hazañas con la
  señal `hazana` y la escena las anuncia al terminar la animación (cartel arriba de la
  pantalla, con su sonido). La copa se dibuja con `tools/generar_trofeo.py`.
- **Inglés.** Botón *English / Español* arriba a la derecha del menú (parte siempre en
  español y recuerda la elección en `user://idioma.cfg`). Todo se escribe en español y
  `data/idioma/en.json` trae la traducción de cada texto (la clave es el texto en español):
  en el código se usa `tr("...")` y `Datos.leer()` traduce los campos de texto de `data/`.
  Al agregar o cambiar un texto, `python tools/revisar_traduccion.py` avisa qué falta
  traducir (y que los `%s`/`%d` coincidan); con `--faltantes` los deja en un archivo.
  Glosario: moral → morale, vida → health, blindaje → armor, cobertura → cover, perfora →
  pierce, roce → graze, botín → loot, manía → quirk, Recluta/Veterano/As →
  Recruit/Veteran/Ace, dado del frente → Frontline Die, Encarar → Face Target. Los nombres
  de los gatos y los gritos («¡Avanti!», «¡Urá!») no se traducen.
- **Línea de visión.** Las rocas tapan: no se puede disparar si la línea entre los dos
  tanques pasa por una (rozar la esquina no cuenta). La *Artillería* sí, porque cae
  desde arriba. La zona roja de amenaza enemiga también la respeta.
- **Roces (Veterano y As).** De lejos se puede rozar: a 1-2 casillas se acierta siempre,
  a 3-4 un 85% y a 5 o más un 70%. Un roce hace la mitad del daño. La vista previa de la
  carta muestra el % de acierto y el daño del roce. En Recluta nunca se roza.
- **Dificultad.** Se elige junto al batallón. *Recluta*: actúan 2 enemigos por turno y
  pegan 1 menos. *Veterano*: la IA elige blanco y casilla por daño esperado (remata,
  flanquea, se cubre) y pega 1 más. *As*: además actúan todos los enemigos y pegan 2 más.
  En Recluta pegan 2 menos. En Recluta y Veterano hay **red de seguridad**: un tanque
  que empieza sano la fase enemiga no cae en ella (queda con 1, "¡salvado por los
  bigotes!"). Una **calavera roja** sobre un tanque propio avisa que los enemigos que
  lo alcanzan podrían destruirlo si se queda ahí. Con el bot de QA (100 batallas por caso), jugando bien:
  Recluta ~100%, Veterano ~90% (británicos) / ~97% (soviéticos), As ~59-64% (con botín). Jugando
  al azar en Recluta: ~83% / ~65%. Una batalla dura ~6-10 turnos.
  `tools/qa/cartas.gd` mide cuánto aporta cada carta (quitándola y comparando).
- **Inspección sorpresa de la teniente Michi.** En cada batalla hay 1 probabilidad en 3
  de que Michi tome el mando (y viene segura si lleva 3 batallas sin aparecer). Su manía,
  *mandona*: cada turno ordena a un tanque que ataque (se marca con "!"). Si obedece,
  +1 de energía el turno siguiente; si no, ese tanque pierde 1 de moral.
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
  +2 cobertura) y roca (intransitable). Desierto: arena (1), arena blanda (2), duna (2,
  +1, tapa la vista) y campo minado (al pasar se tira un dado: con 1 o 2 explota, 5 de
  daño por la panza, y queda arena blanda). Río: el agua no se cruza pero se ve por
  encima; puente (1) y vado (3). Propiedades del terreno en el JSON del mapa:
  `tapa_vista`, `mina`.
- **Mapas.** Pradera (`data/mapa.json`), colinas, bosque, ciudad, desierto y río
  (`data/mapas/`). En batalla suelta se elige uno o al azar; la campaña usa colinas y
  bosque (Recluta), desierto y río (Veterano) y la ciudad (As, la final).
- **Moral.** Cada impacto de 5 o más baja 1 de moral. Con 0 la tripulación entra en
  pánico y ese tanque no puede atacar (*Arenga* la recupera). Un enemigo en pánico
  pierde su turno y se recupera.
- **Terminar turno.** El botón cuenta cuántos tanques todavía pueden jugar alguna carta
  (Encarar no cuenta); si quedan, pregunta antes de terminar ("Terminar de todos modos").
- **Intenciones a la vista.** Sobre cada enemigo hay un cartelito con lo que hará:
  mira roja + daño (ataque), escudo azul, grito morado (baja moral), "?" (pánico) o "zZ" (reserva).
- **Fase enemiga.** Se anima enemigo por enemigo (se mueve, dispara, el número de daño
  salta). Según la dificultad actúan 2 o 3 enemigos por turno (los más cercanos a
  tus tanques); el resto queda **en reserva** (se ven oscurecidos y con "zZ").
  Cada enemigo anuncia su acción. Si es un disparo, se acerca al
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
| `scripts/tablero.gd` | Dibuja el mapa, unidades, resaltados e íconos de intención enemiga, y anima en orden cada acción que avisa el combate (señal `accion`): desplazamiento, disparo, golpe con número, explosión y textos. |
| `tools/qa/` | `bot.gd` (jugador automático) y `simular.gd`: juega cientos de batallas para medir balance (`godot --headless --path . -s tools/qa/simular.gd`, o `-- --azar` para un bot al azar, `-- --mapa=bosque` para un mapa de campaña). |
| `scripts/escena_combate.gd` | Interfaz: fichas, mano de cartas, registro, menú de pausa. |
| `scripts/ficha.gd` | Ficha visual de un tanque: retrato del gato, tanque visto desde arriba con el blindaje de cada lado (rojo = delgado, verde = grueso; anillo amarillo en el lado donde le pegas), barras de casco y moral, movimiento, escudo, terreno y manía. |
| `scripts/campana.gd`, `data/mapas/` | Pantallas de campaña (elegir batallón, progreso con medallas y Arsenal, recompensa, final) y sus mapas. |
| `scripts/fichas.gd`, `data/fichas.json` | Pantalla de fichas técnicas con datos reales de cada tanque. |
| `scripts/menu.gd`, `scripts/tutorial.gd` | Pantalla de inicio y tutorial de 10 páginas guiado por Muffy (instructora) y la teniente Michi (explica las cartas). |
| `scripts/gato_animado.gd` | Anima a un gato desde su hoja de sprites. Por defecto, Muffy (`assets/muchi/`, el archivo conserva el nombre original del personaje; arte propio de la autora, todos los derechos reservados). |
| `scripts/estilo.gd` | Estética común tipo Balatro: tapete, botones-carta, títulos. |
| `assets/fuentes/` | [Pixelify Sans](https://github.com/eifetx/Pixelify-Sans), SIL Open Font License 1.1 (`OFL.txt`): se puede incluir y vender con el juego, siempre que la licencia vaya junto a la fuente. Se usa sin suavizado (`Estilo.fuente()`). |
| `assets/sonidos/` | Efectos CC0 (Kenney y OpenGameArt), incluidos maullidos y ronroneo. La voz de Michi (`michi_*.ogg`) es la de la gata de verdad, grabada por la autora (todos los derechos reservados). Origen de cada uno en `CREDITOS.txt`. Las grabaciones originales (`grabaciones/`) no se suben. |
| `scripts/control_sonido.gd` | Barra de volumen y botón de silencio (menú y pausa). El ajuste se guarda en `user://ajustes.cfg`. |
| `scripts/globo.gd` | Globo de diálogo de cómic con colita que apunta a quien habla (menú, tutorial, órdenes de Michi). |
| `scripts/sonido.gd` | Autoload `Sonido`: todos los botones suenan solos (hover, clic, error si está deshabilitado); el combate avisa disparos, derribos y movimientos con la señal `evento` y suenan en cola. |
| `tools/generar_terreno.py` | Dibuja las losetas-carta del terreno (`assets/terreno/`). |
| `tests/test_combate.gd` | Pruebas de la lógica. |
| `assets/` | Sprites. Los tanques son de 80×28 px a escala real (1 px = 13 cm) y se dibujan a ×1 en casillas de 64 px; la variante `_enemigo` es el mismo tanque en gris. |
| `tools/generar_sprites.py` | Dibuja los sprites de tanques por código (`python tools/generar_sprites.py`). `tools/vista_previa.png` los muestra ampliados. |
| `icon.png`, `icon.ico` | Ícono del juego (Earl Grey con su boina). |
| `export_presets.cfg`, `tools/LEEME-regalo.txt`, `tools/README-gift-en.txt` | Presets de exportación (Windows y Web; la web lleva etiquetas para la vista previa del enlace) y los LEEME en español e inglés que van en el zip. |
| `data/dedicatoria.json` | Dedicatoria del regalo (pantalla al abrir el juego). No se sube a GitHub (`.gitignore`) ni va en la web (filtro del preset Web): solo en el zip de Windows. |
| `docs/capturas/` | Capturas en inglés para la presentación (README y vista previa del enlace). |

### Campos de una carta

`coste`, `tipo` (`ataque` / `defensa` / `maniobra` / `apoyo`), `dano`, `penetracion`,
`alcance` ([mín, máx]), `bonus_flanco`, `salpicadura`, `escudo`, `radio` (a quién más
afecta, en casillas), `encarar` + `requiere_objetivo`, `movimiento`, `moral`, `energia`, `texto`.

## Exportar

Hace falta tener las plantillas de exportación de Godot instaladas (Editor → Manage
Export Templates). Los presets ya están en `export_presets.cfg`; desde esta carpeta:

```powershell
godot --headless --path . --export-release "Windows Desktop" build/windows/Meowtillery.exe
godot --headless --path . --export-release "Web" docs/index.html
```

Después de exportar la web, hacer commit de `docs/` y push: GitHub Pages se actualiza
solo en ~1 minuto. `docs/.gdignore` evita que Godot importe esos archivos como parte
del juego, y `docs/licencias/` lleva la licencia de la fuente y los créditos de sonido.

- **Windows:** un solo `.exe` con todo adentro. No está firmado, así que Windows avisa
  la primera vez ("Más información" → "Ejecutar de todas formas").
- **Web:** usa el renderizador *Compatibility* (WebGL 2) y **sin hilos**, así no hace falta
  configurar cabeceras especiales y funciona en GitHub Pages o itch.io.

## Pendiente

- Más batallones (francés, polaco…).
- Ojo con las fuentes de arte: los mapas de Dice Grimorium no publican licencia de uso
  comercial; usar arte propio o CC0 (p. ej. Kenney.nl).
- Música.
- Más mapas y campañas por batallón (con su propia historia).

## Tanques reales de referencia y derechos

Los tanques están **inspirados** en el Centurion Mk1, el Sherman Firefly, el Churchill
Mk VII, el IS-2, el T-34-85, el M4 Sherman, el M18 Hellcat, el M26 Pershing, el M13/40,
el Semovente da 75/18 y el P26/40. Los Firefly, Churchill, IS-2, T-34-85, Hellcat, Pershing, M13/40 y Semovente se dibujaron con medidas públicas generales, sin
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
