extends PanelContainer
## Globo de diálogo de cómic: caja de papel con borde de tinta y una colita que apunta
## a quien habla. `cola`: "izquierda", "derecha" o "abajo" (y `cola_pos`, de 0 a 1, dice
## en qué parte de ese lado sale).

const Estilo := preload("res://scripts/estilo.gd")
const LARGO := 16.0
const ANCHO := 14.0

var cola := "izquierda":
	set(v):
		cola = v
		queue_redraw()
var cola_pos := 0.75:
	set(v):
		cola_pos = v
		queue_redraw()
var _texto: Label


func _init(contenido: String = "", tam_letra: int = 18, lado: String = "izquierda") -> void:
	cola = lado
	add_theme_stylebox_override("panel", Estilo.caja(Estilo.PAPEL))
	_texto = Estilo.texto_en_papel(contenido, tam_letra)
	add_child(_texto)


var texto: String:
	get:
		return _texto.text
	set(v):
		_texto.text = v


func _draw() -> void:
	# La colita se dibuja fuera de la caja; un relleno tapa el borde donde se une.
	var r := Rect2(Vector2.ZERO, size)
	var base_a: Vector2
	var base_b: Vector2
	var punta: Vector2
	match cola:
		"izquierda":
			var y := r.size.y * cola_pos
			base_a = Vector2(1.5, y - ANCHO / 2)
			base_b = Vector2(1.5, y + ANCHO / 2)
			punta = Vector2(-LARGO, y + ANCHO / 2 + 6)
		"derecha":
			var y := r.size.y * cola_pos
			base_a = Vector2(r.size.x - 1.5, y - ANCHO / 2)
			base_b = Vector2(r.size.x - 1.5, y + ANCHO / 2)
			punta = Vector2(r.size.x + LARGO, y + ANCHO / 2 + 6)
		_:  # abajo
			var x := r.size.x * cola_pos
			base_a = Vector2(x - ANCHO / 2, r.size.y - 1.5)
			base_b = Vector2(x + ANCHO / 2, r.size.y - 1.5)
			punta = Vector2(x - 6, r.size.y + LARGO)
	draw_colored_polygon(PackedVector2Array([base_a, base_b, punta]), Estilo.PAPEL)
	draw_line(base_a, punta, Estilo.TINTA, 3.0)
	draw_line(base_b, punta, Estilo.TINTA, 3.0)
