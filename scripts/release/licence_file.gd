class_name LicenceFile
extends RefCounted
## The text of licences.txt, written next to the web build by the packaging step. It comes from the engine itself (its own licence, the
## licences of its bundled libraries and the list of those components), so it is never typed from memory. Build-time only.

const RIGHTS_LINE := "Copyright 2026 JTexpo. All rights reserved."


static func text() -> String:
	var out := PackedStringArray()
	out.append(RIGHTS_LINE)
	out.append("ScrollSmith Survivors is not licensed for copying, modification or redistribution.")
	out.append("")
	out.append("THIRD-PARTY NOTICES")
	out.append("This game is made with the Godot Engine, used under the licence below.")
	out.append("")
	out.append("=== Godot Engine ===")
	out.append(Engine.get_license_text())
	out.append("")
	out.append("=== Licences of the libraries bundled with the engine ===")
	var info := Engine.get_license_info()
	var names := info.keys()
	names.sort()
	for license_name in names:
		out.append("--- %s ---" % license_name)
		out.append(String(info[license_name]))
		out.append("")
	out.append("=== Components bundled with the engine ===")
	for entry in Engine.get_copyright_info():
		out.append("--- %s ---" % entry["name"])
		for part in entry["parts"]:
			out.append("Files: %s" % ", ".join(part["files"]))
			for line in part["copyright"]:
				out.append("Copyright: %s" % line)
			out.append("Licence: %s" % part["license"])
		out.append("")
	return "\n".join(out)
