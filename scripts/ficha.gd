extends PanelContainer
## Ficha visual de un tanque para el panel derecho del combate:
##  - retrato del gato (cara de susto si está en pánico), nombre y tanque;
##  - dibujo del tanque visto desde arriba, girado hacia donde mira, con el blindaje
##    de cada lado en círculos de color (rojo = delgado, verde = grueso). El lado por
##    donde le estás apuntando se marca con un anillo amarillo;
##  - barras de casco y moral, puntos de movimiento, escudo, terreno y manía.

const Estilo := preload("res://scripts/estilo.gd")
## Recorte de la cabeza del gato en su hoja (como en el tablero).
const CABEZA := Rect2(3, 0, 26, 20)

var _retrato: TextureRect
var _atlas := AtlasTexture.new()
var _nombre: Label
var _tanque: Label
var _diagrama: Diagrama
var _barras: Barras
var _terreno: Label
var _mania: Label
var _extra: Label


func _init(color_acento: Color) -> void:
	add_theme_stylebox_override("panel", Estilo.caja(Color(0, 0, 0, 0.22), color_acento, 2))
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	add_child(caja)

	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 8)
	caja.add_child(cabecera)
	_retrato = TextureRect.new()
	_retrato.texture = _atlas
	_retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_retrato.custom_minimum_size = CABEZA.size * 2
	_retrato.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabecera.add_child(_retrato)
	var nombres := VBoxContainer.new()
	nombres.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombres.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nombres.add_theme_constant_override("separation", 0)
	cabecera.add_child(nombres)
	_nombre = _etiqueta(nombres, 19, color_acento, false)
	_tanque = _etiqueta(nombres, 13, Estilo.APAGADO, false)

	var medio := HBoxContainer.new()
	medio.add_theme_constant_override("separation", 10)
	caja.add_child(medio)
	_diagrama = Diagrama.new()
	medio.add_child(_diagrama)
	var derecha := VBoxContainer.new()
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	derecha.add_theme_constant_override("separation", 2)
	medio.add_child(derecha)
	_barras = Barras.new()
	derecha.add_child(_barras)
	_terreno = _etiqueta(derecha, 13, Estilo.PAPEL)

	_mania = _etiqueta(caja, 13, Color(1, 1, 1, 0.85))
	_extra = _etiqueta(caja, 14, color_acento)


func _etiqueta(padre: Control, tam: int, color: Color, varias_lineas: bool = true) -> Label:
	var l := Label.new()
	if varias_lineas:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	padre.add_child(l)
	return l


## Muestra a la unidad `u`. `extra`: líneas debajo (qué planea, desde dónde le das...).
## `resaltar`: lado del blindaje a marcar ("frente", "flanco", "trasera" o "").
func mostrar(u: Dictionary, combate, extra: String = "", resaltar: String = "") -> void:
	var vivo: bool = combate.vivo(u)
	var panico: bool = combate.en_panico(u)
	if u.has("gato"):
		_atlas.atlas = load(u["gato"])
		_atlas.region = Rect2(CABEZA.position + Vector2(0, (3 if panico else 0) * 32), CABEZA.size)
		_retrato.visible = true
	else:
		_retrato.visible = false
	_retrato.modulate = Color(1, 1, 1, 1) if vivo else Color(1, 1, 1, 0.5)
	_nombre.text = u["nombre"]
	_tanque.text = u.get("inspirado_en", "")
	_diagrama.configurar(u["blindaje"], u["orientacion"], resaltar if vivo else "")
	_barras.configurar(u, combate)
	var terreno: Dictionary = combate.mapa.terreno(u["pos"])
	var cob := int(terreno.get("cobertura", 0))
	_terreno.text = "Terreno: %s%s" % [terreno["nombre"], " (+%d de blindaje)" % cob if cob > 0 else ""]
	_mania.text = u.get("mania_texto", "")
	_mania.visible = _mania.text != ""
	if not vivo:
		extra = "Fuera de combate · el gato escapó a salvo"
	_extra.text = extra
	_extra.visible = extra != ""


# ---------------------------------------------------------------------------
class Diagrama extends Control:
	## Tanque visto desde arriba con el blindaje de cada lado. Color del círculo según
	## el valor (0, 1, 2, 3, 4, 5+): de rojo (delgado) a verde (grueso).
	const Estilo := preload("res://scripts/estilo.gd")
	const COLORES := [Color("d8435a"), Color("e0603e"), Color("ec9a3c"), Color("e9c84a"), Color("8fcf6a"), Color("4fb87a")]
	var blindaje: Dictionary = {}
	var orientacion := Vector2i.RIGHT
	var resaltar := ""

	func _init() -> void:
		custom_minimum_size = Vector2(124, 124)

	func configurar(b: Dictionary, o: Vector2i, lado: String) -> void:
		blindaje = b
		orientacion = o
		resaltar = lado
		queue_redraw()

	func _draw() -> void:
		var c := size / 2
		var d := Vector2(orientacion)
		var p := Vector2(-d.y, d.x)
		# Orugas, casco, torreta y cañón.
		for lado in [-1.0, 1.0]:
			var o: Vector2 = p * 19.0 * lado
			draw_colored_polygon(PackedVector2Array([c + d * 25 + o - p * 3, c + d * 25 + o + p * 3,
				c - d * 25 + o + p * 3, c - d * 25 + o - p * 3]), Estilo.TINTA)
		var casco := PackedVector2Array([c + d * 23 - p * 15, c + d * 23 + p * 15, c - d * 23 + p * 15, c - d * 23 - p * 15])
		draw_colored_polygon(casco, Color("6f7d58"))
		casco.append(casco[0])
		draw_polyline(casco, Estilo.TINTA, 2.0)
		draw_line(c + d * 2, c + d * 36, Estilo.TINTA, 5.0)
		draw_line(c + d * 2, c + d * 35, Color("8e9b72"), 2.0)
		draw_circle(c + d * 2, 10.0, Estilo.TINTA)
		draw_circle(c + d * 2, 8.0, Color("8e9b72"))
		# Círculos de blindaje: frente adelante, trasera atrás, flanco a cada costado.
		_circulo(c + d * 50, "frente")
		_circulo(c - d * 47, "trasera")
		_circulo(c + p * 40, "flanco")
		_circulo(c - p * 40, "flanco")

	func _circulo(pos: Vector2, lado: String) -> void:
		var valor := int(blindaje.get(lado, 0))
		var color: Color = COLORES[clampi(valor, 0, COLORES.size() - 1)]
		if resaltar == lado:
			draw_circle(pos, 16.0, Estilo.ACENTO)
		draw_circle(pos, 12.0, Estilo.TINTA)
		draw_circle(pos, 10.0, color)
		var fuente := get_theme_default_font()
		var texto := str(valor)
		var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(fuente, pos + Vector2(-ancho / 2, 5), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Estilo.TINTA)


# ---------------------------------------------------------------------------
class Barras extends Control:
	## Casco, moral, movimiento y escudo.
	const Estilo := preload("res://scripts/estilo.gd")
	var casco := 0
	var casco_max := 1
	var moral := 0
	var moral_max := 1
	var escudo := 0
	var mov := 0
	var mov_max := 0
	var aliado := true
	var panico := false

	func _init() -> void:
		custom_minimum_size = Vector2(190, 66)

	func configurar(u: Dictionary, combate) -> void:
		casco = u["casco"]
		casco_max = maxi(int(u["casco_max"]), 1)
		moral = u["moral"]
		moral_max = maxi(int(u["moral_max"]), 1)
		escudo = u["escudo"]
		aliado = u["bando"] == "aliado"
		mov = u["mov_restante"] if aliado else u["movimiento"]
		mov_max = u["movimiento"]
		panico = combate.en_panico(u)
		queue_redraw()

	func _draw() -> void:
		var fuente := get_theme_default_font()
		var ancho_barra := size.x - 112
		_barra(fuente, 0, "Vida", float(casco) / casco_max, Color("7ee08a") if aliado else Color("ff7a7a"),
			"%d/%d" % [casco, casco_max], ancho_barra)
		var texto_moral := "¡PÁNICO!" if panico else "%d/%d" % [moral, moral_max]
		_barra(fuente, 21, "Moral", float(moral) / moral_max, Color("e84a5f") if panico else Color("ffd166"),
			texto_moral, ancho_barra)
		draw_string(fuente, Vector2(0, 54), "Mover", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Estilo.PAPEL)
		for i in mov_max:
			var centro := Vector2(58 + i * 14, 49)
			if i < mov:
				draw_circle(centro, 5.0, Color("6fb6ff") if aliado else Estilo.APAGADO)
			else:
				draw_arc(centro, 4.5, 0, TAU, 12, Estilo.APAGADO, 1.5)
		if escudo > 0:
			var e := Vector2(size.x - 40, 46)
			draw_colored_polygon(PackedVector2Array([e + Vector2(-7, -8), e + Vector2(7, -8), e + Vector2(7, 1),
				e + Vector2(0, 9), e + Vector2(-7, 1)]), Color("8ad0ff"))
			draw_string(fuente, e + Vector2(10, 5), "+%d" % escudo, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8ad0ff"))

	func _barra(fuente: Font, y: float, nombre: String, fraccion: float, color: Color, texto: String, ancho: float) -> void:
		draw_string(fuente, Vector2(0, y + 12), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Estilo.PAPEL)
		var r := Rect2(Vector2(52, y + 2), Vector2(ancho, 12))
		draw_rect(r, Color(0, 0, 0, 0.55))
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(fraccion, 0.0, 1.0), r.size.y)), color)
		draw_rect(r, Estilo.TINTA, false, 2.0)
		draw_string(fuente, Vector2(r.end.x + 6, y + 12), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Estilo.PAPEL)
