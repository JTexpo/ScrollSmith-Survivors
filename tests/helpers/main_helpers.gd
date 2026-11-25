extends RefCounted
## Builds a run scene the way every run test needs it: no save file and no pick screen pausing the tree.


static func new_main(test: GutTest, path: String) -> Main:
	var main := load(path).instantiate() as Main
	main.save_path = ""
	(main.get_node("BuffPickScreen") as BuffPickScreen).pause_tree = false
	test.add_child_autofree(main)
	return main
