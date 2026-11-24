extends Control
## Dibuja el mapa, las unidades y los resaltados, y avisa qué celda se pulsó.
## No decide nada: la escena le pasa qué resaltar.

signal celda_pulsada(celda: Vector2i)

const TAM := 64
## Variantes por tipo de loseta (las genera tools/generar_terreno.py).
const VARIANTES_TERRENO := 3
const COLOR_MOVIMIENTO := Color(0.35, 0.65, 1.0, 0.35)
const COLOR_AMENAZA := Color(1.0, 0.25, 0.25, 0.25)
const COLOR_ALCANCE := Color(1.0, 0.88, 0.54, 0.7)
const COLOR_ACTOR := Color("ffe08a")
const COLOR_OBJETIVO := Color("ff9eb5")
const COLOR_FLECHA := Color("ffe08a")
const COLOR_TAPETE := Color("1b3833")
const COLOR_TINTA := Color("1c1a24")
## Recorte de la cabeza (con gorro) dentro de un cuadro de 32×32 de la hoja del gato.
const CABEZA := Rect2(3, 0, 26, 20)
## Fila de la hoja con la cara de susto ("alert"), para el pánico.
const FILA_SUSTO := 3

var combate  # scripts/combate.gd
var movimiento: Dictionary = {}  # celdas a las que puede ir el tanque elegido
var amenaza: Dictionary = {}     # celdas que el enemigo elegido puede atacar
var alcance: Dictionary = {}     # celdas a tiro de las cartas de ataque en mano
var actor_pos := Vector2i(-1, -1)
var objetivo_pos := Vector2i(-1, -1)
## Tanque al que la teniente Michi le ordenó atacar este turno (se marca con "!").
var orden_pos := Vector2i(-1, -1)
## Vista previa de la carta bajo el mouse: {celda: {"texto": "-6", "derriba": bool}}.
var prevision: Dictionary = {}
var _texturas: Dictionary = {}


func preparar(c) -> void:
	combate = c
	custom_minimum_size = Vector2(c.mapa.ancho, c.mapa.alto) * TAM
	queue_redraw()


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
				draw_rect(r, COLOR_AMENAZA)
			if movimiento.has(celda):
				draw_rect(r, COLOR_MOVIMIENTO)
			if alcance.has(celda):
				draw_rect(r.grow(-5), COLOR_ALCANCE, false, 2.0)
			if not con_textura:
				draw_rect(r, Color(0, 0, 0, 0.18), false, 1.0)

	for u in combate.aliados + combate.enemigos:
		if combate.vivo(u):
			_dibujar_unidad(u)

	_marco(actor_pos, COLOR_ACTOR)
	_marco(objetivo_pos, COLOR_OBJETIVO)
	if m.dentro(orden_pos):
		_insignia_orden(orden_pos)
	for celda in prevision:
		_etiqueta_dano(celda, prevision[celda])


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


func _dibujar_unidad(u: Dictionary) -> void:
	var celda: Vector2i = u["pos"]
	var o: Vector2i = u["orientacion"]
	var esquina := Vector2(celda * TAM)
	var centro := esquina + Vector2(TAM, TAM) / 2

	# El sprite mira a la derecha; se voltea si la unidad mira a la izquierda.
	var tex := _textura(u["sprite"])
	# Escala entera: los sprites chicos (32 px) se duplican; los realistas (80 px) van a ×1
	# y su cañón puede asomar un poco a la casilla vecina.
	var tam_sprite := tex.get_size() * maxi(1, TAM / int(tex.get_size().x))
	var escala := Vector2(-1, 1) if o == Vector2i.LEFT else Vector2(1, 1)
	draw_set_transform(centro, 0.0, escala)
	var origen := -tam_sprite / 2 - Vector2(0, 4)
	var en_reserva: bool = u.get("intencion", {}).get("reserva", false)
	var tinte := Color(u.get("tinte", "ffffff"))
	if en_reserva:
		tinte = tinte.darkened(0.3)  # en reserva: no actúa este turno
	draw_texture_rect(tex, Rect2(origen, tam_sprite), false, tinte)
	if u.has("gato"):
		_dibujar_gato(u, origen)
	draw_set_transform(Vector2.ZERO)
	if en_reserva:
		var fuente := get_theme_default_font()
		draw_string_outline(fuente, esquina + Vector2(4, 16), "zZ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, COLOR_TINTA)
		draw_string(fuente, esquina + Vector2(4, 16), "zZ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("8ad0ff"))

	# Flecha de orientación: indica dónde está su frente (el lado más blindado).
	var dir := Vector2(o)
	var perp := Vector2(-dir.y, dir.x) * 6
	var punta := centro + dir * (TAM * 0.48)
	var base := centro + dir * (TAM * 0.34)
	draw_colored_polygon(PackedVector2Array([punta, base + perp, base - perp]), COLOR_FLECHA)

	# Barra de casco y escudo.
	var barra := Rect2(esquina + Vector2(6, TAM - 9), Vector2(TAM - 12, 5))
	draw_rect(barra, Color(0, 0, 0, 0.6))
	var fraccion := float(u["casco"]) / float(u["casco_max"])
	var color_barra := Color("7ee08a") if u["bando"] == "aliado" else Color("ff7a7a")
	draw_rect(Rect2(barra.position, Vector2(barra.size.x * fraccion, barra.size.y)), color_barra)
	if u["escudo"] > 0:
		draw_string(get_theme_default_font(), esquina + Vector2(TAM - 24, 14), "+%d" % u["escudo"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8ad0ff"))


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


func _marco(celda: Vector2i, color: Color) -> void:
	if combate.mapa.dentro(celda):
		draw_rect(Rect2(Vector2(celda * TAM), Vector2(TAM, TAM)).grow(-1), color, false, 3.0)


func _textura(ruta: String) -> Texture2D:
	if not _texturas.has(ruta):
		_texturas[ruta] = load(ruta)
	return _texturas[ruta]


func _gui_input(evento: InputEvent) -> void:
	if combate == null:
		return
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		var celda := Vector2i((evento.position / TAM).floor())
		if combate.mapa.dentro(celda):
			celda_pulsada.emit(celda)
			accept_event()
