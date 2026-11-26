extends Node
## Autoload "Trofeos": la vitrina de logros (data/trofeos.json), guardada entre partidas.
## Cuando se gana uno nuevo aparece un cartel arriba de la pantalla, esté donde esté.

const Datos := preload("res://scripts/datos.gd")
const Estilo := preload("res://scripts/estilo.gd")
const ARCHIVO := "user://trofeos.json"
const DUR_CARTEL := 3.0

signal nuevo(id: String)

var archivo := ARCHIVO  # las pruebas usan otro
var conseguidos: Dictionary = {}       # id -> true
var batallones_ganadores: Dictionary = {}  # para "Gira mundial"
var fichas_vistas: Dictionary = {}     # para "Gato de biblioteca"
## Sin cartel (pruebas y simulador).
var silencioso := false
var _lista: Array = []
var _avisos: Array = []
var _capa: CanvasLayer
var _cartel: PanelContainer
var _nombre_cartel: Label


func _ready() -> void:
	cargar()


func lista() -> Array:
	if _lista.is_empty():
		_lista = Datos.leer("res://data/trofeos.json")
	return _lista


func tiene(id: String) -> bool:
	return conseguidos.has(id)


func cuantos() -> int:
	return lista().filter(func(t): return conseguidos.has(t["id"])).size()


## Gana un trofeo. Devuelve true solo la primera vez.
func conseguir(id: String) -> bool:
	if conseguidos.has(id) or not lista().any(func(t): return t["id"] == id):
		return false
	conseguidos[id] = true
	guardar()
	nuevo.emit(id)
	if not silencioso:
		_avisos.append(id)
		if _avisos.size() == 1:
			_mostrar_siguiente()
	return true


## Victoria con un batallón: cuenta para "Gira mundial".
func victoria_con(batallon: String, total_batallones: int) -> void:
	batallones_ganadores[batallon] = true
	guardar()
	if batallones_ganadores.size() >= total_batallones:
		conseguir("gira_mundial")


func campana_terminada(batallon: String) -> void:
	conseguir("campana_" + batallon)


func ficha_vista(i: int, total: int) -> void:
	if fichas_vistas.has(str(i)):
		return
	fichas_vistas[str(i)] = true
	guardar()
	if fichas_vistas.size() >= total:
		conseguir("gato_de_biblioteca")


func cargar() -> void:
	conseguidos = {}
	batallones_ganadores = {}
	fichas_vistas = {}
	if not FileAccess.file_exists(archivo):
		return
	var datos = JSON.parse_string(FileAccess.get_file_as_string(archivo))
	if datos is Dictionary:
		conseguidos = datos.get("conseguidos", {})
		batallones_ganadores = datos.get("batallones", {})
		fichas_vistas = datos.get("fichas", {})


func guardar() -> void:
	var f := FileAccess.open(archivo, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"conseguidos": conseguidos, "batallones": batallones_ganadores,
			"fichas": fichas_vistas}))


func borrar_todo() -> void:
	conseguidos = {}
	batallones_ganadores = {}
	fichas_vistas = {}
	guardar()


# ------------------------------------------------------------------ cartel ---

func _armar_cartel() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 50
	add_child(_capa)
	_cartel = PanelContainer.new()
	_cartel.add_theme_stylebox_override("panel", Estilo.caja(Color("2b2540"), Estilo.ACENTO, 4))
	_cartel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.add_child(_cartel)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	_cartel.add_child(fila)
	var copa := Estilo.imagen("res://assets/trofeo.png", 3)
	fila.add_child(copa)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_child(col)
	var arriba := Label.new()
	arriba.text = "¡Trofeo nuevo!"
	arriba.theme = Estilo.tema()
	arriba.add_theme_font_size_override("font_size", 15)
	arriba.add_theme_color_override("font_color", Estilo.ACENTO)
	col.add_child(arriba)
	_nombre_cartel = Label.new()
	_nombre_cartel.theme = Estilo.tema()
	_nombre_cartel.add_theme_font_size_override("font_size", 24)
	col.add_child(_nombre_cartel)


func _mostrar_siguiente() -> void:
	if _avisos.is_empty() or not is_inside_tree():
		return
	if _cartel == null:
		_armar_cartel()
	var id: String = _avisos[0]
	for t in lista():
		if t["id"] == id:
			_nombre_cartel.text = t["nombre"]
	_cartel.reset_size()
	var ancho := get_viewport().get_visible_rect().size.x
	var x := (ancho - _cartel.size.x) / 2.0
	_cartel.position = Vector2(x, -_cartel.size.y - 10)
	var sonido := get_node_or_null("/root/Sonido")  # sin referencia directa: así compila en las pruebas
	if sonido:
		sonido.tocar("trofeo")
	var tw := create_tween()
	tw.tween_property(_cartel, "position:y", 14.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(DUR_CARTEL)
	tw.tween_property(_cartel, "position:y", -_cartel.size.y - 10, 0.3)
	tw.tween_callback(func():
		_avisos.pop_front()
		_mostrar_siguiente())
