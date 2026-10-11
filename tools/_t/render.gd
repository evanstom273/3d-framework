extends SceneTree
## Renders a .vox from 6 directions (front, back, left, right, top, bottom),
## depth-shaded, into one PNG per model.
const PX := 5
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	for id in args.slice(1):
		var data := VoxFile.read_cells("res://furniture/vox/%s.vox" % id)
		var cells: Dictionary = data["cells"]
		var lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
		var hi := -lo
		for c: Vector3i in cells:
			lo = lo.min(c)
			hi = hi.max(c)
		var size := hi - lo + Vector3i.ONE
		# view: [across axis, across sign, up axis, up sign, depth axis, depth sign]
		var views := [
			["front", 0, 1, 1, 1, 2, 1], ["back", 0, -1, 1, 1, 2, -1], ["left", 2, -1, 1, 1, 0, 1],
			["right", 2, 1, 1, 1, 0, -1], ["top", 0, 1, 2, 1, 1, -1], ["bottom", 0, 1, 2, -1, 1, 1]]
		var tiles := []
		var w := 0
		var h := 0
		for v in views:
			var img := _view(cells, lo, size, v[1], v[2], v[3], v[4], v[5], v[6])
			tiles.append(img)
			w += img.get_width() + 10
			h = maxi(h, img.get_height())
		var sheet := Image.create(w, h, false, Image.FORMAT_RGB8)
		sheet.fill(Color(0.35, 0.4, 0.5))
		var x := 0
		for img: Image in tiles:
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, h - img.get_height()))
			x += img.get_width() + 10
		sheet.save_png(out_dir + "/" + id + ".png")
	quit()

func _view(cells: Dictionary, lo: Vector3i, size: Vector3i, ax: int, asg: int, up: int, usg: int, dp: int, dsg: int) -> Image:
	var nw: int = size[ax]
	var nh: int = size[up]
	var nd: int = size[dp]
	var img := Image.create(nw * PX, nh * PX, false, Image.FORMAT_RGB8)
	img.fill(Color(0.85, 0.85, 0.88))
	for i in nw:
		for j in nh:
			for k in nd:
				var c := lo
				c[ax] = lo[ax] + (i if asg > 0 else nw - 1 - i)
				c[up] = lo[up] + (j if usg > 0 else nh - 1 - j)
				c[dp] = lo[dp] + (k if dsg > 0 else nd - 1 - k)
				if cells.has(c):
					var col: Color = cells[c]
					col = col.darkened(clampf(float(k) / maxf(nd, 1) * 0.6, 0.0, 0.6))
					img.fill_rect(Rect2i(i * PX, (nh - 1 - j) * PX, PX, PX), col)
					break
	return img
