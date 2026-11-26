extends Node
## Autoload "Idioma": el juego está escrito en español (código y data/) y
## data/idioma/en.json trae la versión en inglés de cada texto (la clave es el texto en
## español). tr() en los scripts y Datos.leer() en los datos usan esta traducción.
##
## Para revisar que no falte nada: python tools/revisar_traduccion.py

const ARCHIVO := "user://idioma.cfg"
const TRADUCCION_EN := "res://data/idioma/en.json"
const IDIOMAS := ["es", "en"]


func _ready() -> void:
	var t := Translation.new()
	t.locale = "en"
	var datos = JSON.parse_string(FileAccess.get_file_as_string(TRADUCCION_EN))
	if datos is Dictionary:
		for es in datos:
			t.add_message(es, datos[es])
	TranslationServer.add_translation(t)
	var cfg := ConfigFile.new()
	var guardado := ""
	if cfg.load(ARCHIVO) == OK:
		guardado = cfg.get_value("idioma", "codigo", "")
	# Siempre parte en español (es un regalo en español); el botón del menú cambia a inglés
	# y la elección se recuerda.
	poner(guardado if guardado != "" else "es", false)


func actual() -> String:
	return TranslationServer.get_locale().substr(0, 2)


func poner(codigo: String, guardar := true) -> void:
	if not codigo in IDIOMAS:
		codigo = "es"
	TranslationServer.set_locale(codigo)
	if guardar:
		var cfg := ConfigFile.new()
		cfg.set_value("idioma", "codigo", codigo)
		cfg.save(ARCHIVO)


## Cambia al otro idioma y recarga la pantalla actual.
func alternar() -> void:
	poner("en" if actual() == "es" else "es")
	get_tree().reload_current_scene()
