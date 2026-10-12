extends SceneTree
const PX := 7
func _initialize() -> void:
	var cells := {}
	for file in DirAccess.get_files_at("res://npc/vox/"):
		if file.ends_with(".vox") and file.begins_with("assistant__") and not file.contains("clipboard"):
			var data := VoxFile.read_cells("res://npc/vox/" + file)
			cells.merge(data["cells"])
	var lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var hi := -lo
	for c: Vector3i in cells:
		lo = lo.min(c); hi = hi.max(c)
	var size := hi - lo + Vector3i.ONE
	var views := [[0, 1, 1, 1, 2, 1], [2, -1, 1, 1, 0, 1], [0, -1, 1, 1, 2, -1]]
	var tiles := []
	var w := 0
	var h := 0
	for v in views:
		var img := _view(cells, lo, size, v[0], v[1], v[2], v[3], v[4], v[5])
		tiles.append(img); w += img.get_width() + 12; h = maxi(h, img.get_height())
	var sheet := Image.create(w, h, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.4, 0.45, 0.55))
	var x := 0
	for img: Image in tiles:
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, h - img.get_height()))
		x += img.get_width() + 12
	sheet.save_png(OS.get_cmdline_user_args()[0])
	quit()
func _view(cells: Dictionary, lo: Vector3i, size: Vector3i, ax: int, asg: int, up: int, usg: int, dp: int, dsg: int) -> Image:
	var nw: int = size[ax]
	var nh: int = size[up]
	var nd: int = size[dp]
	var img := Image.create(nw * PX, nh * PX, false, Image.FORMAT_RGB8)
	img.fill(Color(0.85, 0.86, 0.9))
	for i in nw:
		for j in nh:
			for k in nd:
				var c := lo
				c[ax] = lo[ax] + (i if asg > 0 else nw - 1 - i)
				c[up] = lo[up] + j
				c[dp] = lo[dp] + (k if dsg > 0 else nd - 1 - k)
				if cells.has(c):
					var col: Color = cells[c]
					img.fill_rect(Rect2i(i * PX, (nh - 1 - j) * PX, PX, PX), col.darkened(clampf(float(k) / maxf(nd, 1) * 0.5, 0.0, 0.5)))
					break
	return img
