extends RefCounted
## File walks for the guard tests.


## Every file under `dir` (recursively) that ends with `extension`.
static func files(dir: String, extension: String, found: Array[String] = []) -> Array[String]:
	for file in DirAccess.get_files_at(dir):
		if String(file).ends_with(extension):
			found.append("%s/%s" % [dir, file])
	for folder in DirAccess.get_directories_at(dir):
		files("%s/%s" % [dir, folder], extension, found)
	return found
