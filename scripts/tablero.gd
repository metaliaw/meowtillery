extends Control
## Dibuja el mapa, las unidades y los resaltados, y avisa qué celda se pulsó.
## No decide nada: la escena le pasa qué resaltar.
##
## Animaciones: el combate avisa cada acción (señal `accion`) y el tablero las reproduce
## en orden sobre su propia "vista" de las unidades (posición, casco, escudo...), que va
## un paso atrás de la lógica. Mientras `animando` es true la escena no acepta jugadas;
## al terminar se emite `animacion_terminada` y la vista vuelve a calzar con la lógica.

signal celda_pulsada(celda: Vector2i)
signal animacion_terminada

const TAM := 64
## Variantes por tipo de loseta (las genera tools/generar_terreno.py).
const VARIANTES_TERRENO := 3
const COLOR_MOVIMIENTO := Color(0.35, 0.65, 1.0, 0.35)
const COLOR_AMENAZA := Color(1.0, 0.25, 0.25, 0.12)
const COLOR_BORDE_AMENAZA := Color(0.9, 0.2, 0.25, 0.85)
const COLOR_ALCANCE := Color(1.0, 0.88, 0.54, 0.7)
const COLOR_ACTOR := Color("ffe08a")
const COLOR_OBJETIVO := Color("ff9eb5")
const COLOR_FLECHA := Color("ffe08a")
const COLOR_TAPETE := Color("1b3833")
const COLOR_TINTA := Color("1c1a24")
const COLORES_TEXTO := {"escudo": Color("8ad0ff"), "moral": Color("ffe08a"), "malo": Color("d6a2ff"),
	"dano": Color("ff6b6b"), "vida": Color("7ee08a")}
## Recorte de la cabeza (con gorro) dentro de un cuadro de 32×32 de la hoja del gato.
const CABEZA := Rect2(3, 0, 26, 20)
## Fila de la hoja con la cara de susto ("alert"), para el pánico.
const FILA_SUSTO := 3

## Duraciones (segundos).
const PASO_MOVER := 0.12      # por casilla
const DUR_GIRAR := 0.15
const DUR_DISPARO := 0.35
const DUR_GOLPE := 0.55
const DUR_TEXTO := 0.3
const DUR_TRAZO := 0.3
const DUR_EXPLOSION := 0.6
const DUR_FLOTANTE := 1.1
const DUR_TEMBLOR := 0.35
## Kill cam: primer plano del tanque derribado (al estilo de los juegos de tanques).
const DUR_KILLCAM := 2.0
const IMPACTO_KC := 0.45   # cuándo llega el proyectil dentro de la kill cam
const SALTO_GATO_KC := 1.0 # cuándo salta el gato por la escotilla
const DUR_ESCAPE := 1.4    # el gato corre hacia su lado del mapa
const RESTOS := Color(0.32, 0.28, 0.26)

var combate  # scripts/combate.gd
var movimiento: Dictionary = {}  # celdas a las que puede ir el tanque elegido
var amenaza: Dictionary = {}     # celdas que el enemigo elegido puede atacar
var alcance: Dictionary = {}     # celdas a tiro de las cartas de ataque en mano
var actor_pos := Vector2i(-1, -1)
var objetivo_pos := Vector2i(-1, -1)
## Tanque al que la teniente Michi le ordenó atacar este turno (se marca con "!").
var orden_pos := Vector2i(-1, -1)
## Tanques propios que podrían caer en la próxima fase enemiga: {celda: true}.
var peligro: Dictionary = {}
## Vista previa de la carta bajo el mouse: {celda: {"texto": "-6", "derriba": bool}}.
var prevision: Dictionary = {}
var animando := false

var _texturas: Dictionary = {}
var _vista: Dictionary = {}  # clave -> {celda: Vector2, orientacion, casco, escudo, vivo}
var _cola: Array = []
var _t := 0.0
var _iniciada := false
var _flotantes: Array = []   # {pos, texto, color, t}
var _trazos: Array = []      # {de, a, t}
var _explosiones: Array = [] # {pos, t}
var _temblor: Dictionary = {}  # clave -> segundos restantes
var _killcam: Dictionary = {}  # {clave, lado, dano, t} mientras se muestra
var _escapes: Array = []       # gatos corriendo a salvo: {hoja, de, hacia_x, t}


func preparar(c) -> void:
	combate = c
	custom_minimum_size = Vector2(c.mapa.ancho, c.mapa.alto) * TAM
	_cola.clear()
	_killcam = {}
	_escapes.clear()
	animando = false
	sincronizar()
	queue_redraw()


## Copia el estado de la lógica a la vista (cuando no hay nada animándose).
func sincronizar() -> void:
	_vista.clear()
	for u in combate.aliados + combate.enemigos:
		_vista[u.get("clave", "")] = {"celda": Vector2(u["pos"]), "orientacion": u["orientacion"],
			"casco": u["casco"], "escudo": u["escudo"], "vivo": combate.vivo(u)}


func encolar(datos: Dictionary) -> void:
	_cola.append(datos)
	animando = true


# ------------------------------------------------------------------ animación ---

func _process(delta: float) -> void:
	var hay_efectos := not (_flotantes.is_empty() and _trazos.is_empty() and _explosiones.is_empty() \
		and _temblor.is_empty() and _escapes.is_empty()) or _hay_restos() or not peligro.is_empty()
	_envejecer(delta)
	if not _cola.is_empty():
		_avanzar(delta)
	elif animando:
		animando = false
		sincronizar()
		animacion_terminada.emit()
	if animando or hay_efectos:
		queue_redraw()


func _envejecer(delta: float) -> void:
	for lista in [_flotantes, _trazos, _explosiones, _escapes]:
		for e in lista:
			e["t"] += delta
	_escapes = _escapes.filter(func(e): return e["t"] < DUR_ESCAPE)
	_flotantes = _flotantes.filter(func(e): return e["t"] < DUR_FLOTANTE)
	_trazos = _trazos.filter(func(e): return e["t"] < DUR_TRAZO)
	_explosiones = _explosiones.filter(func(e): return e["t"] < DUR_EXPLOSION)
	for clave in _temblor.keys():
		_temblor[clave] -= delta
		if _temblor[clave] <= 0.0:
			_temblor.erase(clave)


func _avanzar(delta: float) -> void:
	var a: Dictionary = _cola[0]
	var v: Dictionary = _vista.get(a["clave"], {})
	if v.is_empty():  # unidad desconocida: se salta
		_cola.pop_front()
		return
	if not _iniciada:
		_iniciar(a, v)
		_iniciada = true
	_t += delta
	var dur := DUR_TEXTO
	match a["tipo"]:
		"mover":
			var camino: Array = a["camino"]
			var pasos: int = maxi(camino.size() - 1, 1)
			dur = pasos * PASO_MOVER
			var k := minf(_t / PASO_MOVER, camino.size() - 1)
			var i := int(k)
			if i >= camino.size() - 1:
				v["celda"] = Vector2(camino[-1])
				v["orientacion"] = a["orientacion"]
			else:
				var de: Vector2i = camino[i]
				var hacia: Vector2i = camino[i + 1]
				v["celda"] = Vector2(de).lerp(Vector2(hacia), k - i)
				v["orientacion"] = hacia - de
		"girar":
			dur = DUR_GIRAR
		"disparo":
			dur = DUR_DISPARO
		"golpe":
			dur = DUR_GOLPE
			if a["derriba"]:
				dur = DUR_KILLCAM
				_killcam["t"] = _t
	if _t >= dur:
		if a["tipo"] == "golpe" and a["derriba"]:
			_terminar_killcam(a, v)
		_cola.pop_front()
		_t = 0.0
		_iniciada = false


## Al cerrar la kill cam: el tanque queda en llamas y el gato sale corriendo hacia su lado.
func _terminar_killcam(a: Dictionary, v: Dictionary) -> void:
	_killcam = {}
	v["vivo"] = false
	_explosiones.append({"pos": _centro(v), "t": 0.0})
	var u := _unidad(a["clave"])
	if u.has("gato"):
		var hacia_x: float = -40.0 if u["bando"] == "aliado" else size.x + 40.0
		_escapes.append({"hoja": _textura(u["gato"]), "de": _centro(v) + Vector2(0, -18), "hacia_x": hacia_x, "t": 0.0})
	_flotar(v, "¡A salvo!", COLORES_TEXTO["moral"])


func _unidad(clave: String) -> Dictionary:
	if clave.length() < 2 or combate == null:
		return {}
	var lista: Array = combate.aliados if clave[0] == "a" else combate.enemigos
	var i := int(clave.substr(1))
	return lista[i] if i < lista.size() else {}


func _hay_restos() -> bool:
	if combate == null:
		return false
	for u in combate.aliados + combate.enemigos:
		if not _estado(u)["vivo"]:
			return true
	return false


func _iniciar(a: Dictionary, v: Dictionary) -> void:
	match a["tipo"]:
		"mover":
			_sonar("mover")
		"girar":
			v["orientacion"] = a["orientacion"]
		"disparo":
			v["orientacion"] = a["orientacion"]
			_sonar("disparo")
			var blanco: Dictionary = _vista.get(a["objetivo"], {})
			if not blanco.is_empty():
				_trazos.append({"de": _boca(v), "a": _centro(blanco), "t": 0.0})
		"golpe":
			v["casco"] = a["casco"]
			v["escudo"] = a["escudo"]
			if a["derriba"]:
				# El derribo se cuenta en primer plano (kill cam) en vez de en el tablero.
				_killcam = {"clave": a["clave"], "lado": a.get("lado", "flanco"), "dano": a["al_casco"], "t": 0.0}
				_sonar("explosion")
				return
			_temblor[a["clave"]] = DUR_TEMBLOR
			var texto := "-%d" % a["al_casco"]
			var color: Color = COLORES_TEXTO["dano"]
			if a["al_casco"] == 0:
				texto = "escudo -%d" % a["absorbido"]
				color = COLORES_TEXTO["escudo"]
			_flotar(v, texto, color)
			if a.get("voz", "") != "":
				_sonar(a["voz"])  # el gato se asusta (entra en pánico)
		"texto":
			if a.has("escudo"):
				v["escudo"] = a["escudo"]
			if a.has("casco"):
				v["casco"] = a["casco"]  # reparaciones: la barra sube junto con el texto
			_flotar(v, a["texto"], COLORES_TEXTO.get(a["color"], Color.WHITE))
			if a.get("voz", "") != "":
				_sonar(a["voz"])


func _flotar(v: Dictionary, texto: String, color: Color) -> void:
	# Si ya hay un texto reciente sobre la misma unidad, este sale un poco más arriba.
	var pos := _centro(v) + Vector2(0, -36)  # sobre la cabeza del gato, no encima
	for f in _flotantes:
		if f["t"] < 0.3 and f["pos"].distance_to(pos) < 10:
			pos.y -= 16
	_flotantes.append({"pos": pos, "texto": texto, "color": color, "t": 0.0})


func _sonar(nombre: String) -> void:
	var s := get_node_or_null("/root/Sonido")
	if s:
		s.tocar(nombre)


func _centro(v: Dictionary) -> Vector2:
	return (v["celda"] + Vector2(0.5, 0.5)) * TAM


func _boca(v: Dictionary) -> Vector2:
	return _centro(v) + Vector2(v["orientacion"]) * TAM * 0.55 + Vector2(0, -6)


## Estado a dibujar de una unidad: la vista si existe, si no la lógica.
func _estado(u: Dictionary) -> Dictionary:
	var v: Dictionary = _vista.get(u.get("clave", ""), {})
	if not v.is_empty():
		return v
	return {"celda": Vector2(u["pos"]), "orientacion": u["orientacion"], "casco": u["casco"],
		"escudo": u["escudo"], "vivo": combate.vivo(u)}


# ------------------------------------------------------------------ dibujo ---

func _draw() -> void:
	if combate == null:
		return
	var m = combate.mapa
	var fuente := get_theme_default_font()  # la pixelada, heredada del tema de la escena
	# Tapete: se ve en los huecos entre las cartas de terreno.
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_TAPETE)
	for y in m.alto:
		for x in m.ancho:
			var celda := Vector2i(x, y)
			var r := Rect2(Vector2(celda * TAM), Vector2(TAM, TAM))
			var terreno: Dictionary = m.terreno(celda)
			var con_textura: bool = terreno.has("textura")
			if con_textura:
				# Variante fija por celda (no aleatoria), para que el mapa no "parpadee" al redibujar.
				var variante: int = (x * 7 + y * 13) % VARIANTES_TERRENO
				draw_texture_rect(_textura("res://assets/terreno/%s_%d.png" % [terreno["textura"], variante]), r, false)
			else:
				draw_rect(r, Color(terreno["color"]))
			var cobertura := int(terreno.get("cobertura", 0))
			if cobertura > 0:
				# Junto al "palo" de la carta, en la esquina superior izquierda.
				draw_string(fuente, r.position + Vector2(17, 14), "+%d" % cobertura,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_TINTA)
			if amenaza.has(celda):
				# Tinte suave y solo el contorno exterior de la zona: se lee sin ensuciar el mapa.
				draw_rect(r, COLOR_AMENAZA)
				_contorno_zona(celda, r)
			if movimiento.has(celda):
				draw_rect(r, COLOR_MOVIMIENTO)
			if alcance.has(celda):
				draw_rect(r.grow(-5), COLOR_ALCANCE, false, 2.0)
			if not con_textura:
				draw_rect(r, Color(0, 0, 0, 0.18), false, 1.0)

	# Marcos de selección debajo de los tanques: así no tapan el sprite, el gato ni sus íconos.
	_marco(actor_pos, COLOR_ACTOR)
	_marco(objetivo_pos, COLOR_OBJETIVO)
	# Primero los restos en llamas (quedan debajo), después los tanques en pie.
	for u in combate.aliados + combate.enemigos:
		var e := _estado(u)
		if not e["vivo"]:
			_dibujar_restos(u, e)
	for u in combate.aliados + combate.enemigos:
		var e := _estado(u)
		if e["vivo"]:
			_dibujar_unidad(u, e)

	if m.dentro(orden_pos) and not animando:
		_insignia_orden(orden_pos)
	if not animando:
		for celda in peligro:
			_calavera(celda)
	for celda in prevision:
		_etiqueta_dano(celda, prevision[celda])
	_dibujar_efectos(fuente)
	_dibujar_escapes()
	if not _killcam.is_empty():
		_dibujar_killcam(fuente)


## Tanque derribado: chamuscado, con fueguitos que titilan y humo que sube.
func _dibujar_restos(u: Dictionary, e: Dictionary) -> void:
	var esquina: Vector2 = e["celda"] * TAM
	var centro := esquina + Vector2(TAM, TAM) / 2
	var tex := _textura(u["sprite"])
	var tam_sprite := tex.get_size() * maxi(1, TAM / int(tex.get_size().x))
	var escala := Vector2(-1, 1) if e["orientacion"] == Vector2i.LEFT else Vector2(1, 1)
	draw_set_transform(centro, 0.0, escala)
	draw_texture_rect(tex, Rect2(-tam_sprite / 2 - Vector2(0, 4), tam_sprite), false, RESTOS)
	draw_set_transform(Vector2.ZERO)
	var t := Time.get_ticks_msec() / 1000.0
	for k in 3:
		var base := centro + Vector2(-14 + k * 14, -4)
		var llama := 0.65 + 0.35 * sin(t * 9.0 + k * 2.1)
		draw_circle(base + Vector2(0, -3 * llama), 6.0 * llama, Color(1.0, 0.45, 0.1, 0.9))
		draw_circle(base + Vector2(0, -5 * llama), 3.5 * llama, Color(1.0, 0.85, 0.3))
	for k in 3:
		var fase := fmod(t * 0.45 + k / 3.0, 1.0)
		var humo := centro + Vector2(sin(t + k) * 4 + (k - 1) * 8, -12 - fase * 32)
		draw_circle(humo, 4.0 + fase * 6.0, Color(0.22, 0.22, 0.24, 0.5 * (1.0 - fase)))


## El gato que escapó corre dando saltitos hacia el borde de su bando.
func _dibujar_escapes() -> void:
	for es in _escapes:
		var p: float = es["t"] / DUR_ESCAPE
		var de: Vector2 = es["de"]
		var pos := Vector2(lerpf(de.x, es["hacia_x"], p), de.y - absf(sin(p * PI * 5.0)) * 10.0)
		# Cuadro "happy" de su hoja (fila 2), a tamaño natural.
		draw_texture_rect_region(es["hoja"], Rect2(pos - Vector2(16, 16), Vector2(32, 32)), Rect2(0, 64, 32, 32))


## Kill cam: primer plano del tanque derribado. El proyectil entra por el lado del
## impacto, el tanque explota y se chamusca, y el gato salta por la escotilla a salvo.
func _dibujar_killcam(fuente: Font) -> void:
	var u := _unidad(_killcam["clave"])
	if u.is_empty():
		return
	var t: float = _killcam["t"]
	var v: Dictionary = _vista.get(_killcam["clave"], {})
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var panel := Rect2(size / 2 - Vector2(240, 140), Vector2(480, 280))
	draw_rect(Rect2(panel.position + Vector2(5, 5), panel.size), Color(0, 0, 0, 0.5))
	draw_rect(panel, Color("eef1f8"))
	draw_rect(panel, COLOR_TINTA, false, 3.0)
	var cabecera := Rect2(panel.position, Vector2(panel.size.x, 30))
	draw_rect(cabecera, Color("e84a5f"))
	draw_rect(cabecera, COLOR_TINTA, false, 3.0)
	draw_string(fuente, cabecera.position + Vector2(12, 22), "KILL CAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(fuente, cabecera.position + Vector2(120, 22), "%s · %s" % [u["nombre"], u.get("inspirado_en", "")],
		HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 130, 15, Color.WHITE)

	# Tanque a ×4. Tiembla y se chamusca después del impacto.
	var tex := _textura(u["sprite"])
	var escala_kc := 4.0
	var tam := tex.get_size() * escala_kc
	var mira_izq: bool = v.get("orientacion", u["orientacion"]) == Vector2i.LEFT
	var s := -1.0 if mira_izq else 1.0  # hacia dónde apunta el cañón en pantalla
	var centro := panel.get_center() + Vector2(0, 20)
	var tras_impacto := clampf((t - IMPACTO_KC) / 0.5, 0.0, 1.0)
	if t > IMPACTO_KC:
		centro.x += sin(t * 70.0) * 5.0 * (1.0 - tras_impacto)
	var tinte := Color.WHITE.lerp(RESTOS, tras_impacto)
	draw_set_transform(centro, 0.0, Vector2(s, 1))
	var origen := -tam / 2
	draw_texture_rect(tex, Rect2(origen, tam), false, tinte)
	# El gato: asustado en la escotilla y, después, salta fuera feliz.
	if u.has("gato"):
		var hoja := _textura(u["gato"])
		var escotilla := Vector2(u["escotilla"][0], u["escotilla"][1]) * escala_kc
		var salto := clampf((t - SALTO_GATO_KC) / 0.5, 0.0, 1.0)
		var fila := 2 if salto > 0.0 else (FILA_SUSTO if t > IMPACTO_KC else 0)
		var alto_gato := 32.0 * 2.5
		var pos := origen + escotilla + Vector2(-alto_gato / 2, -alto_gato * 0.75 - salto * 50.0)
		draw_texture_rect_region(hoja, Rect2(pos, Vector2(alto_gato, alto_gato)), Rect2(0, fila * 32, 32, 32))
	draw_set_transform(Vector2.ZERO)

	# Proyectil antes del impacto; explosión después.
	var punto := centro + Vector2(0, 6)
	var lado: String = _killcam["lado"]
	if lado == "frente":
		punto = centro + Vector2(s * tam.x * 0.3, 0)
	elif lado == "trasera":
		punto = centro + Vector2(-s * tam.x * 0.4, 0)
	if t < IMPACTO_KC:
		var p := t / IMPACTO_KC
		if lado == "flanco":
			# Del flanco: viene hacia la cámara; se dibuja como una mira que se cierra.
			draw_arc(punto, lerpf(60.0, 8.0, p), 0, TAU, 24, Color("e84a5f"), 3.0)
		else:
			var desde := punto + Vector2((s if lado == "frente" else -s) * 220.0, -6)
			var bala := desde.lerp(punto, p)
			draw_line(bala - (punto - desde).normalized() * 30.0, bala, Color(1, 0.9, 0.5, 0.6), 4.0)
			draw_circle(bala, 5.0, Color(1, 0.95, 0.7))
	else:
		var pe := clampf((t - IMPACTO_KC) / 0.6, 0.0, 1.0)
		draw_circle(punto, 10.0 + 50.0 * pe, Color(1.0, 0.55, 0.15, 0.85 * (1.0 - pe)))
		draw_circle(punto, 6.0 + 26.0 * pe, Color(1.0, 0.92, 0.55, 1.0 - pe))

	var nombres_lado := {"frente": "el frente", "flanco": "el flanco", "trasera": "la trasera"}
	var texto := "¡Derribado! Impacto por %s · -%d" % [nombres_lado.get(lado, lado), _killcam["dano"]]
	if t > SALTO_GATO_KC:
		texto = "¡%s salta del tanque y escapa a salvo!" % u["nombre"]
	var pie := panel.position + Vector2(0, panel.size.y - 14)
	draw_string(fuente, pie, texto, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 17, COLOR_TINTA)


## Dibuja los lados de la celda que dan hacia afuera de la zona de amenaza.
func _contorno_zona(celda: Vector2i, r: Rect2) -> void:
	var a := r.position + Vector2(2, 2)
	var b := r.position + Vector2(TAM - 2, 2)
	var c := r.position + Vector2(TAM - 2, TAM - 2)
	var d := r.position + Vector2(2, TAM - 2)
	for lado in [[Vector2i.UP, a, b], [Vector2i.RIGHT, b, c], [Vector2i.DOWN, c, d], [Vector2i.LEFT, d, a]]:
		if not amenaza.has(celda + lado[0]):
			draw_line(lado[1], lado[2], COLOR_BORDE_AMENAZA, 3.0)


func _dibujar_efectos(fuente: Font) -> void:
	for tr in _trazos:
		var p: float = tr["t"] / DUR_TRAZO
		draw_line(tr["de"], tr["a"], Color(1.0, 0.6, 0.2, 0.9 * (1.0 - p)), 6.0)
		draw_line(tr["de"], tr["a"], Color(1.0, 1.0, 0.85, 1.0 - p), 2.5)
		draw_circle(tr["de"], 12.0 * (1.0 - p) + 3.0, Color(1.0, 0.75, 0.25, 1.0 - p))
		draw_circle(tr["de"], 6.0 * (1.0 - p) + 1.0, Color(1.0, 1.0, 0.8, 1.0 - p))
	for ex in _explosiones:
		var p: float = ex["t"] / DUR_EXPLOSION
		draw_circle(ex["pos"], 8.0 + 26.0 * p, Color(1.0, 0.55, 0.15, 0.85 * (1.0 - p)))
		draw_circle(ex["pos"], 4.0 + 14.0 * p, Color(1.0, 0.9, 0.5, 1.0 - p))
	for f in _flotantes:
		var p: float = f["t"] / DUR_FLOTANTE
		var pos: Vector2 = f["pos"] + Vector2(0, -26.0 * p)
		var alfa := 1.0 if p < 0.6 else 1.0 - (p - 0.6) / 0.4
		var tam_letra := 28 if f["texto"].begins_with("-") and f["texto"].length() <= 3 else 20
		var ancho := fuente.get_string_size(f["texto"], HORIZONTAL_ALIGNMENT_LEFT, -1, tam_letra).x
		var en := pos - Vector2(ancho / 2.0, 0)
		draw_string_outline(fuente, en, f["texto"], HORIZONTAL_ALIGNMENT_LEFT, -1, tam_letra, 8, Color(COLOR_TINTA, alfa))
		draw_string(fuente, en, f["texto"], HORIZONTAL_ALIGNMENT_LEFT, -1, tam_letra, Color(f["color"], alfa))


## Calavera roja arriba a la izquierda: si el tanque se queda ahí, lo pueden destruir.
func _calavera(celda: Vector2i) -> void:
	var c := Vector2(celda * TAM) + Vector2(11, 9)
	var latido := 1.0 + 0.12 * sin(Time.get_ticks_msec() / 160.0)
	draw_circle(c, 10.0 * latido, COLOR_TINTA)
	draw_circle(c, 8.0 * latido, Color("e84a5f"))
	draw_circle(c + Vector2(0, -1), 5.0, Color.WHITE)            # cráneo
	draw_rect(Rect2(c + Vector2(-3, 2), Vector2(6, 4)), Color.WHITE)  # mandíbula
	draw_circle(c + Vector2(-2, -1), 1.4, COLOR_TINTA)            # ojos
	draw_circle(c + Vector2(2, -1), 1.4, COLOR_TINTA)
	draw_line(c + Vector2(-1, 4), c + Vector2(-1, 6), COLOR_TINTA, 1.0)  # dientes
	draw_line(c + Vector2(1, 4), c + Vector2(1, 6), COLOR_TINTA, 1.0)


## Círculo amarillo con "!" en la esquina inferior izquierda: la orden de Michi.
func _insignia_orden(celda: Vector2i) -> void:
	var centro := Vector2(celda * TAM) + Vector2(11, TAM - 20)
	draw_circle(centro, 8, COLOR_TINTA)
	draw_circle(centro, 6, COLOR_ACTOR)
	draw_string(get_theme_default_font(), centro + Vector2(-3, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_TINTA)


## Cartelito con el daño que entraría, pegado arriba de la unidad. Rojo si la derriba.
func _etiqueta_dano(celda: Vector2i, p: Dictionary) -> void:
	var fuente := get_theme_default_font()
	var tam_letra := 16
	var texto: String = p["texto"]
	var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_letra).x + 10
	var centro_x := celda.x * TAM + TAM / 2.0
	var caja := Rect2(Vector2(centro_x - ancho / 2, celda.y * TAM - 8), Vector2(ancho, 22))
	var fondo := Color("e84a5f") if p["derriba"] else Color("eef1f8")
	var tinta := Color.WHITE if p["derriba"] else Color("c0283c")
	draw_rect(Rect2(caja.position + Vector2(2, 2), caja.size), Color(0, 0, 0, 0.4))
	draw_rect(caja, fondo)
	draw_rect(caja, COLOR_TINTA, false, 2.0)
	draw_string(fuente, caja.position + Vector2(5, 16), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_letra, tinta)


func _dibujar_unidad(u: Dictionary, e: Dictionary) -> void:
	var o: Vector2i = e["orientacion"]
	var esquina: Vector2 = e["celda"] * TAM
	if _temblor.has(u.get("clave", "")):
		esquina.x += sin(_temblor[u["clave"]] * 70.0) * 3.0
	var centro := esquina + Vector2(TAM, TAM) / 2

	# El sprite mira a la derecha; se voltea si la unidad mira a la izquierda.
	var tex := _textura(u["sprite"])
	# Escala entera: los sprites chicos (32 px) se duplican; los realistas (80 px) van a ×1
	# y su cañón puede asomar un poco a la casilla vecina.
	var tam_sprite := tex.get_size() * maxi(1, TAM / int(tex.get_size().x))
	var escala := Vector2(-1, 1) if o == Vector2i.LEFT else Vector2(1, 1)
	draw_set_transform(centro, 0.0, escala)
	var origen := -tam_sprite / 2 - Vector2(0, 4)
	var intencion: Dictionary = u.get("intencion", {})
	var tinte := Color(u.get("tinte", "ffffff"))
	if intencion.get("reserva", false) and not animando:
		tinte = tinte.darkened(0.3)  # en reserva: no actúa este turno
	var camuflado: bool = u.get("camuflado", false) and not animando
	if camuflado:
		tinte.a = 0.6  # camuflado: medio transparente y con ramas encima
	draw_texture_rect(tex, Rect2(origen, tam_sprite), false, tinte)
	if u.has("gato"):
		_dibujar_gato(u, origen)
	draw_set_transform(Vector2.ZERO)
	if camuflado:
		for p in [Vector2(-18, -6), Vector2(-6, -10), Vector2(8, -7), Vector2(18, -3)]:
			var h: Vector2 = centro + p
			draw_colored_polygon(PackedVector2Array([h + Vector2(-5, 0), h + Vector2(0, -4),
				h + Vector2(5, 0), h + Vector2(0, 4)]), Color("5f8a3a"))

	# Flecha de orientación: indica dónde está su frente (el lado más blindado).
	var dir := Vector2(o)
	var perp := Vector2(-dir.y, dir.x) * 6
	var punta := centro + dir * (TAM * 0.48)
	var base := centro + dir * (TAM * 0.34)
	draw_colored_polygon(PackedVector2Array([punta, base + perp, base - perp]), COLOR_FLECHA)

	# Barra de casco y escudo.
	var barra := Rect2(esquina + Vector2(6, TAM - 9), Vector2(TAM - 12, 5))
	draw_rect(barra, Color(0, 0, 0, 0.6))
	var fraccion := float(e["casco"]) / float(u["casco_max"])
	var color_barra := Color("7ee08a") if u["bando"] == "aliado" else Color("ff7a7a")
	draw_rect(Rect2(barra.position, Vector2(barra.size.x * fraccion, barra.size.y)), color_barra)
	if e["escudo"] > 0:
		draw_string(get_theme_default_font(), esquina + Vector2(4, 14), "+%d" % e["escudo"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLORES_TEXTO["escudo"])

	# Qué piensa hacer el enemigo, siempre a la vista (se oculta mientras se anima).
	if u["bando"] == "enemigo" and not animando:
		_icono_intencion(esquina, intencion)


## Cartelito sobre cada enemigo: mira + daño (ataque), escudo, grito (baja moral),
## "?" (pánico) o "zZ" (en reserva).
func _icono_intencion(esquina: Vector2, a: Dictionary) -> void:
	if a.is_empty():
		return
	var fuente := get_theme_default_font()
	var fondo := Color("e84a5f")
	var texto := ""
	var icono := ""
	if a.get("reserva", false):
		fondo = Color("34495e")
		texto = "zZ"
	elif a.get("paralizado", false):
		fondo = Color("6b6b78")
		texto = "?"
	elif a.has("dano"):
		icono = "mira"
		texto = str(int(a["dano"]))
	elif a.has("escudo"):
		fondo = Color("3b7dd8")
		icono = "escudo"
		texto = str(int(a["escudo"]))
	elif a.has("moral"):
		fondo = Color("8e4fc0")
		icono = "grito"
		texto = "-%d" % int(a["moral"])
	var ancho_texto := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var ancho := ancho_texto + (22.0 if icono != "" else 10.0)
	var caja := Rect2(esquina + Vector2(TAM - ancho - 1, -7), Vector2(ancho, 18))
	draw_rect(Rect2(caja.position + Vector2(2, 2), caja.size), Color(0, 0, 0, 0.45))
	draw_rect(caja, fondo)
	draw_rect(caja, COLOR_TINTA, false, 2.0)
	var c := caja.position + Vector2(10, 9)
	match icono:
		"mira":
			draw_arc(c, 5.0, 0, TAU, 16, Color.WHITE, 1.5)
			draw_line(c + Vector2(-7, 0), c + Vector2(-3, 0), Color.WHITE, 1.5)
			draw_line(c + Vector2(3, 0), c + Vector2(7, 0), Color.WHITE, 1.5)
			draw_line(c + Vector2(0, -7), c + Vector2(0, -3), Color.WHITE, 1.5)
			draw_line(c + Vector2(0, 3), c + Vector2(0, 7), Color.WHITE, 1.5)
		"escudo":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -6), c + Vector2(5, -6),
				c + Vector2(5, 0), c + Vector2(0, 6), c + Vector2(-5, 0)]), Color.WHITE)
		"grito":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -2), c + Vector2(-2, -2),
				c + Vector2(5, -6), c + Vector2(5, 6), c + Vector2(-2, 2), c + Vector2(-6, 2)]), Color.WHITE)
	var x_texto := caja.position.x + (20.0 if icono != "" else 5.0)
	draw_string(fuente, Vector2(x_texto, caja.position.y + 14), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


## La cabeza del gato comandante asomando por la escotilla. Se dibuja dentro de la
## transformación del tanque, así que se voltea con él. En pánico pone cara de susto.
func _dibujar_gato(u: Dictionary, origen_sprite: Vector2) -> void:
	var hoja := _textura(u["gato"])
	var fila := FILA_SUSTO if combate.en_panico(u) else 0
	var fuente := Rect2(CABEZA.position + Vector2(0, fila * 32), CABEZA.size)
	var escotilla := Vector2(u["escotilla"][0], u["escotilla"][1])
	# El cuello queda 3 px dentro de la torreta, como si estuviera sentado en la escotilla.
	var destino := Rect2(origen_sprite + escotilla + Vector2(-CABEZA.size.x / 2, 3 - CABEZA.size.y), CABEZA.size)
	draw_texture_rect_region(hoja, destino, fuente)


## Marco de selección: tinte suave y borde. Se dibuja bajo las unidades.
func _marco(celda: Vector2i, color: Color) -> void:
	if combate.mapa.dentro(celda):
		var r := Rect2(Vector2(celda * TAM), Vector2(TAM, TAM)).grow(-1)
		draw_rect(r, Color(color, 0.28))
		draw_rect(r, color, false, 3.0)


func _textura(ruta: String) -> Texture2D:
	if not _texturas.has(ruta):
		_texturas[ruta] = load(ruta)
	return _texturas[ruta]


func _gui_input(evento: InputEvent) -> void:
	if combate == null or animando:
		return
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		var celda := Vector2i((evento.position / TAM).floor())
		if combate.mapa.dentro(celda):
			celda_pulsada.emit(celda)
			accept_event()
