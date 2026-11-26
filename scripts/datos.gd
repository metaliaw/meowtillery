extends RefCounted
## Carga de los datos del juego (tanques, enemigos, cartas) desde JSON.

## Campos que se muestran en pantalla: se traducen al cargar (ver scripts/idioma.gd).
## Los ids, rutas y números quedan igual.
const CAMPOS_DE_TEXTO := ["nombre", "nombre_corto", "texto", "lema", "descripcion", "mania_texto",
	"pais", "anio", "peso", "canon", "blindaje", "velocidad", "armamento", "dato", "gato"]


static func leer(ruta: String) -> Variant:
	var texto := FileAccess.get_file_as_string(ruta)
	if texto.is_empty():
		push_error("No se pudo leer %s" % ruta)
		return null
	var datos = JSON.parse_string(texto)
	if datos == null:
		push_error("JSON inválido en %s" % ruta)
	return traducir(datos)


## Traduce en el lugar los campos de texto (solo los String: "blindaje" de un tanque es un
## diccionario de números y no se toca).
static func traducir(x: Variant) -> Variant:
	if x is Dictionary:
		for k in x:
			if x[k] is String and k in CAMPOS_DE_TEXTO:
				x[k] = String(TranslationServer.translate(x[k]))
			else:
				traducir(x[k])
	elif x is Array:
		for v in x:
			traducir(v)
	return x
