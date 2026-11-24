extends RefCounted
## Carga de los datos del juego (tanques, enemigos, cartas) desde JSON.


static func leer(ruta: String) -> Variant:
	var texto := FileAccess.get_file_as_string(ruta)
	if texto.is_empty():
		push_error("No se pudo leer %s" % ruta)
		return null
	var datos = JSON.parse_string(texto)
	if datos == null:
		push_error("JSON inválido en %s" % ruta)
	return datos
