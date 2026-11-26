class_name ItchZipRules
extends RefCounted
## The rules the packaging step checks on the web build before it is zipped for itch.io (its limits as quoted in its documentation: at most
## 1000 files, 200 MB for one extracted file and 500 MB in all, `index.html` at the root, file names are case sensitive). Build-time only.

const MAX_FILES := 1000
const MAX_FILE_BYTES := 200 * 1024 * 1024
const MAX_TOTAL_BYTES := 500 * 1024 * 1024
const REQUIRED := ["index.html", "licences.txt"]


## `files` maps a path relative to the zip's root to its size in bytes. Returns every problem found (empty when clean).
static func problems(files: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for required in REQUIRED:
		if not files.has(required):
			found.append("%s is missing from the zip's root" % required)
	if files.size() > MAX_FILES:
		found.append("%d files; itch.io allows at most %d" % [files.size(), MAX_FILES])
	var total := 0
	var lowered := {}
	var names := files.keys()
	names.sort()
	for file_name in names:
		var size := int(files[file_name])
		total += size
		if size > MAX_FILE_BYTES:
			found.append("%s is %d bytes; one file may be at most %d" % [file_name, size, MAX_FILE_BYTES])
		var key := String(file_name).to_lower()
		if lowered.has(key):
			found.append("%s and %s differ only by case" % [lowered[key], file_name])
		else:
			lowered[key] = file_name
	if total > MAX_TOTAL_BYTES:
		found.append("%d bytes in all; the total may be at most %d" % [total, MAX_TOTAL_BYTES])
	return found
