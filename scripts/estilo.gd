extends RefCounted
## Estética común, cartas pixeladas tipo Balatro: tapete verde, papel claro,
## bordes oscuros gruesos y una sombra dura desplazada.

const TAPETE := Color("244640")
const TINTA := Color("1c1a24")
const PAPEL := Color("eef1f8")
const PAPEL_HOVER := Color("fff6d6")
const ACENTO := Color("ffe08a")
const APAGADO := Color("9aa0b0")

## Pixelify Sans (SIL Open Font License 1.1, ver assets/fuentes/OFL.txt).
const RUTA_FUENTE := "res://assets/fuentes/PixelifySans.ttf"

static var _fuente: FontFile


## Fuente pixelada sin suavizado, para que los bordes queden nítidos como el resto del arte.
static func fuente() -> FontFile:
	if _fuente == null:
		_fuente = load(RUTA_FUENTE)
		_fuente.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_fuente.hinting = TextServer.HINTING_NONE
		_fuente.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _fuente


## Caja con borde grueso y sombra dura, como una carta sobre la mesa.
static func caja(fondo: Color, borde: Color = TINTA, grosor: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(grosor)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(10)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 1
	s.shadow_offset = Vector2(3, 3)
	return s


static func tema() -> Theme:
	var t := Theme.new()
	t.default_font = fuente()
	t.default_font_size = 17
	t.set_stylebox("normal", "Button", caja(PAPEL))
	t.set_stylebox("hover", "Button", caja(PAPEL_HOVER))
	t.set_stylebox("pressed", "Button", caja(ACENTO))
	t.set_stylebox("disabled", "Button", caja(APAGADO, Color("4a4858")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for clave in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(clave, "Button", TINTA)
	t.set_color("font_disabled_color", "Button", Color("4a4858"))
	t.set_stylebox("panel", "PanelContainer", caja(PAPEL))
	t.set_color("font_color", "Label", PAPEL)
	return t


## Etiqueta de texto oscuro, para usar dentro de paneles de papel.
static func texto_en_papel(texto: String, tam: int = 18) -> Label:
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", TINTA)
	l.add_theme_font_size_override("font_size", tam)
	return l


## Título grande con contorno oscuro.
static func titulo(texto: String, tam: int = 56) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", ACENTO)
	l.add_theme_color_override("font_outline_color", TINTA)
	l.add_theme_constant_override("outline_size", 14)
	return l


## Imagen pixelada escalada sin suavizar.
static func imagen(ruta: String, escala: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(ruta)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = r.texture.get_size() * escala
	return r
