extends RefCounted
## Loads a committed scroll by its path under `resources/scrolls/`.


## `path` is the folder and file, for example `base/fire`.
static func scroll(path: String) -> ScrollData:
	return load("res://resources/scrolls/%s.tres" % path) as ScrollData


## A Buff scroll by its file name.
static func buff_scroll(file: String) -> ScrollData:
	return load("res://resources/scrolls/buff/%s.tres" % file) as ScrollData
