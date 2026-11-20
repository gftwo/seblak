extends Node2D

enum WokState { EMPTY, COOKING, READY, BURNT }
enum CustomerPhase { NONE, WALKING_TO_BUFFET, PICKING_TOPPINGS, WAITING_FOOD, PAYING_CASHIER, LEAVING }

class SeblakOrder:
	var cust_name: String
	var items: Array
	var chili_req: int
	var price: int
	var is_ojol: bool
	var is_vlogger: bool
	var is_kasbon: bool
	var drink_name: String

var woks: Array = [
	{ "state": WokState.EMPTY, "progress": 0.0, "chili": 0, "order": null },
	{ "state": WokState.EMPTY, "progress": 0.0, "chili": 0, "order": null }
]
var cook_duration: float = 5.5

var game_started: bool = false
var cust_phase: CustomerPhase = CustomerPhase.NONE
var current_order: SeblakOrder = null
var waiting_orders: Array = []
var ready_to_pay_order: SeblakOrder = null
var ready_chili_used: int = 0

var customer_patience: float = 55.0
var max_patience: float = 55.0
var final_bill_amount: int = 0
var paid_cash_amount: int = 0
var is_qris_payment: bool = false
var spawn_timer: float = 1.2
var phase_timer: float = 0.0
var day_ended: bool = false

# Event Cuaca & Viral Food Vlogger
var is_raining: bool = false
var weather_timer: float = 18.0
var rain_particles: Array = []
var viral_boost_timer: float = 0.0
var steam_particles: Array = []

# Visual 2.5D Nodes
var bg_rect: ColorRect
var world_container: Node2D
var player_avatar: Node2D
var cashier_avatar: Node2D
var customer_avatar: Node2D
var glass_showcase: Polygon2D
var neon_sign_bg: Polygon2D
var drink_cooler: Polygon2D
var wok_visuals: Array = []
var cust_bubble_panel: PanelContainer
var cust_bubble: Label
var target_pos: Vector2 = Vector2.ZERO
var is_cust_walking: bool = false

# UI References
var title_overlay: PanelContainer
var lbl_title_save_info: Label

var lbl_money: Label
var lbl_day: Label
var lbl_rank: Label
var lbl_weather: Label
var lbl_status: Label
var lbl_queue_info: Label
var progress_patience: ProgressBar
var wok_ui: Array = []

var tab_upgrade_box: VBoxContainer
var tab_stock_box: VBoxContainer
var btn_tab_upgrade: Button
var btn_tab_stock: Button

var restock_container: VBoxContainer
var btn_upgrade_stove: Button
var btn_upgrade_fan: Button
var btn_unlock_qris: Button
var btn_unlock_drinks: Button
var btn_unlock_wok2: Button
var btn_hire_cashier: Button
var btn_upgrade_decor: Button
var btn_mute: Button

var cashier_panel: PanelContainer
var lbl_cashier_detail: Label
var btn_cashier_opt1: Button
var btn_cashier_opt2: Button
var btn_cashier_opt3: Button

var summary_panel: PanelContainer
var lbl_summary_text: Label

var customer_names = [
	"Neng Geulis", "Bocil Epep", "Ibu RT", "Mahasiswa Kos", 
	"Teh Dinnar", "Mang Ujang", "Aa Bandung", "Teteh Kantor"
]

var shirt_colors = [
	Color("#E63946"), Color("#457B9D"), Color("#2A9D8F"), 
	Color("#E9C46A"), Color("#9B5DE5"), Color("#F15BB5")
]

func _ready() -> void:
	build_isometric_world()
	build_ui()
	update_hud()
	refresh_restock_shop()
	GameManager.money_changed.connect(func(_m): update_hud())
	GameManager.day_changed.connect(func(_d): update_hud())
	GameManager.stats_updated.connect(update_hud)
	GameManager.stock_updated.connect(refresh_restock_shop)

func make_card_style(bg_col: Color, border_col: Color, radius: int = 12) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 6
	return sb

func make_btn_style(bg_col: Color, border_col: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

func create_chibi_character(shirt_col: Color, label_text: String, role: String = "customer") -> Node2D:
	var root = Node2D.new()
	
	var shadow = Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(-22, 0), Vector2(0, -10), Vector2(22, 0), Vector2(0, 10)])
	shadow.color = Color(0, 0, 0, 0.38)
	root.add_child(shadow)

	var rig = Node2D.new()
	rig.name = "Rig"
	root.add_child(rig)

	var leg_l = Polygon2D.new()
	leg_l.polygon = PackedVector2Array([Vector2(-10, -14), Vector2(-3, -14), Vector2(-3, -2), Vector2(-10, -2)])
	leg_l.color = Color("#2B2D42")
	rig.add_child(leg_l)

	var leg_r = Polygon2D.new()
	leg_r.polygon = PackedVector2Array([Vector2(3, -14), Vector2(10, -14), Vector2(10, -2), Vector2(3, -2)])
	leg_r.color = Color("#2B2D42")
	rig.add_child(leg_r)

	var body = Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([Vector2(-15, -46), Vector2(15, -46), Vector2(18, -12), Vector2(-18, -12)])
	body.color = shirt_col
	rig.add_child(body)

	if role == "chef" or role == "cashier":
		var apron = Polygon2D.new()
		apron.polygon = PackedVector2Array([Vector2(-11, -40), Vector2(11, -40), Vector2(13, -13), Vector2(-13, -13)])
		apron.color = Color("#FFF3B0") if role == "chef" else Color("#FFFFFF")
		rig.add_child(apron)

	var arm_l = Polygon2D.new()
	arm_l.polygon = PackedVector2Array([Vector2(-21, -43), Vector2(-15, -43), Vector2(-16, -24), Vector2(-22, -24)])
	arm_l.color = shirt_col.darkened(0.1)
	rig.add_child(arm_l)

	var arm_r = Polygon2D.new()
	arm_r.polygon = PackedVector2Array([Vector2(15, -43), Vector2(21, -43), Vector2(22, -24), Vector2(16, -24)])
	arm_r.color = shirt_col.darkened(0.1)
	rig.add_child(arm_r)

	var head = Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(-13, -72), Vector2(13, -72), Vector2(16, -65),
		Vector2(15, -50), Vector2(10, -46), Vector2(-10, -46),
		Vector2(-15, -50), Vector2(-16, -65)
	])
	head.color = Color("#FFDCB6")
	rig.add_child(head)

	var blush_l = Polygon2D.new()
	blush_l.polygon = PackedVector2Array([Vector2(-12, -55), Vector2(-7, -55), Vector2(-7, -52), Vector2(-12, -52)])
	blush_l.color = Color(0.95, 0.45, 0.45, 0.5)
	rig.add_child(blush_l)

	var blush_r = Polygon2D.new()
	blush_r.polygon = PackedVector2Array([Vector2(7, -55), Vector2(12, -55), Vector2(12, -52), Vector2(7, -52)])
	blush_r.color = Color(0.95, 0.45, 0.45, 0.5)
	rig.add_child(blush_r)

	var eye_l = Polygon2D.new()
	eye_l.polygon = PackedVector2Array([Vector2(-8, -62), Vector2(-4, -62), Vector2(-4, -57), Vector2(-8, -57)])
	eye_l.color = Color("#1D1E2C")
	rig.add_child(eye_l)

	var eye_r = Polygon2D.new()
	eye_r.polygon = PackedVector2Array([Vector2(4, -62), Vector2(8, -62), Vector2(8, -57), Vector2(4, -57)])
	eye_r.color = Color("#1D1E2C")
	rig.add_child(eye_r)

	var hair = Polygon2D.new()
	hair.name = "Hair"
	hair.polygon = PackedVector2Array([
		Vector2(-15, -75), Vector2(15, -75), Vector2(17, -64),
		Vector2(12, -67), Vector2(0, -65), Vector2(-12, -67), Vector2(-17, -64)
	])
	hair.color = Color("#2B2118")
	rig.add_child(hair)

	if role == "chef":
		var headband = Polygon2D.new()
		headband.polygon = PackedVector2Array([Vector2(-15, -71), Vector2(15, -71), Vector2(15, -67), Vector2(-15, -67)])
		headband.color = Color("#E63946")
		rig.add_child(headband)

	var tag = Label.new()
	tag.name = "NameTag"
	tag.text = label_text
	tag.position = Vector2(-55, -98)
	tag.custom_minimum_size = Vector2(110, 20)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.add_theme_constant_override("outline_size", 4)
	root.add_child(tag)

	return root

func build_isometric_world() -> void:
	bg_rect = ColorRect.new()
	bg_rect.size = Vector2(1280, 720)
	bg_rect.color = Color("#1F1714")
	add_child(bg_rect)
	
	var road = Polygon2D.new()
	road.polygon = PackedVector2Array([Vector2(110, 390), Vector2(610, 625), Vector2(480, 690), Vector2(-10, 455)])
	road.color = Color("#343A40")
	add_child(road)

	var curb = Polygon2D.new()
	curb.polygon = PackedVector2Array([Vector2(140, 380), Vector2(620, 608), Vector2(610, 616), Vector2(130, 388)])
	curb.color = Color("#ADB5BD")
	add_child(curb)

	var floor_base = Polygon2D.new()
	floor_base.polygon = PackedVector2Array([Vector2(620, 145), Vector2(1100, 375), Vector2(620, 605), Vector2(140, 375)])
	floor_base.color = Color("#F3D5B5")
	add_child(floor_base)

	var origin = Vector2(620, 145)
	var step_u = Vector2(480.0 / 8.0, 230.0 / 8.0)
	var step_v = Vector2(-480.0 / 8.0, 230.0 / 8.0)
	for gx in range(8):
		for gy in range(8):
			if (gx + gy) % 2 == 0:
				var p0 = origin + step_u * gx + step_v * gy
				var tile = Polygon2D.new()
				tile.polygon = PackedVector2Array([p0, p0 + step_u, p0 + step_u + step_v, p0 + step_v])
				tile.color = Color("#E7BC91")
				add_child(tile)

	var wall_left = Polygon2D.new()
	wall_left.polygon = PackedVector2Array([Vector2(140, 375), Vector2(620, 145), Vector2(620, 35), Vector2(140, 265)])
	wall_left.color = Color("#BC6C25")
	add_child(wall_left)

	var wall_left_trim = Polygon2D.new()
	wall_left_trim.polygon = PackedVector2Array([Vector2(140, 375), Vector2(620, 145), Vector2(620, 125), Vector2(140, 355)])
	wall_left_trim.color = Color("#6F1D1B")
	add_child(wall_left_trim)
	
	var wall_right = Polygon2D.new()
	wall_right.polygon = PackedVector2Array([Vector2(620, 145), Vector2(1100, 375), Vector2(1100, 265), Vector2(620, 35)])
	wall_right.color = Color("#99582A")
	add_child(wall_right)

	var awning_colors = [Color("#D62828"), Color("#FCBF49")]
	for s in range(6):
		var t0 = float(s) / 6.0
		var t1 = float(s + 1) / 6.0
		var a0 = Vector2(140, 265).lerp(Vector2(620, 35), t0)
		var a1 = Vector2(140, 265).lerp(Vector2(620, 35), t1)
		var stripe = Polygon2D.new()
		stripe.polygon = PackedVector2Array([a0, a1, a1 + Vector2(26, 18), a0 + Vector2(26, 18)])
		stripe.color = awning_colors[s % 2]
		add_child(stripe)

	neon_sign_bg = Polygon2D.new()
	neon_sign_bg.polygon = PackedVector2Array([Vector2(380, 195), Vector2(585, 98), Vector2(585, 134), Vector2(380, 231)])
	neon_sign_bg.color = Color("#FF006E")
	neon_sign_bg.visible = false
	add_child(neon_sign_bg)

	var banner_label = Label.new()
	banner_label.text = "SEBLAK PRASMANAN JUARA"
	banner_label.position = Vector2(390, 168)
	banner_label.rotation = -0.44
	banner_label.add_theme_font_size_override("font_size", 17)
	banner_label.add_theme_color_override("font_color", Color("#FFF3B0"))
	banner_label.add_theme_color_override("font_outline_color", Color("#540B0E"))
	banner_label.add_theme_constant_override("outline_size", 4)
	add_child(banner_label)

	var warm_glow = Polygon2D.new()
	warm_glow.polygon = PackedVector2Array([Vector2(620, 210), Vector2(920, 355), Vector2(620, 500), Vector2(320, 355)])
	warm_glow.color = Color(1.0, 0.85, 0.5, 0.14)
	add_child(warm_glow)

	world_container = Node2D.new()
	world_container.y_sort_enabled = true
	add_child(world_container)

	# Dispenser Minuman Es Teh / Es Jeruk (Muncul saat drinks_unlocked)
	drink_cooler = Polygon2D.new()
	drink_cooler.polygon = PackedVector2Array([Vector2(285, 315), Vector2(315, 300), Vector2(315, 345), Vector2(285, 360)])
	drink_cooler.color = Color("#FF9F1C")
	drink_cooler.visible = false
	world_container.add_child(drink_cooler)

	var dining_node = Node2D.new()
	dining_node.position = Vector2(440, 445)
	world_container.add_child(dining_node)

	var d_table = Polygon2D.new()
	d_table.polygon = PackedVector2Array([Vector2(-45, 0), Vector2(15, -28), Vector2(55, -8), Vector2(-5, 20)])
	d_table.color = Color("#8D5B4C")
	dining_node.add_child(d_table)

	var d_leg = Polygon2D.new()
	d_leg.polygon = PackedVector2Array([Vector2(-5, 20), Vector2(55, -8), Vector2(55, 12), Vector2(-5, 40)])
	d_leg.color = Color("#5C3A21")
	dining_node.add_child(d_leg)

	var buffet_node = Node2D.new()
	buffet_node.position = Vector2(440, 260)
	world_container.add_child(buffet_node)
	
	var buffet_front = Polygon2D.new()
	buffet_front.polygon = PackedVector2Array([Vector2(-110, 10), Vector2(90, -85), Vector2(90, -45), Vector2(-110, 50)])
	buffet_front.color = Color("#6F1D1B")
	buffet_node.add_child(buffet_front)

	var buffet_top = Polygon2D.new()
	buffet_top.polygon = PackedVector2Array([Vector2(-110, 10), Vector2(90, -85), Vector2(135, -63), Vector2(-65, 32)])
	buffet_top.color = Color("#99582A")
	buffet_node.add_child(buffet_top)

	var bowl_colors = [Color("#FF6B35"), Color("#FFD166"), Color("#F4A261"), Color("#E76F51"), Color("#2A9D8F"), Color("#E63946")]
	for idx in range(6):
		var tray = Polygon2D.new()
		var ox = -80 + idx * 33
		var oy = -2 - idx * 15
		tray.polygon = PackedVector2Array([Vector2(ox, oy), Vector2(ox + 20, oy - 9), Vector2(ox + 34, oy - 2), Vector2(ox + 14, oy + 7)])
		tray.color = bowl_colors[idx]
		buffet_node.add_child(tray)

	glass_showcase = Polygon2D.new()
	glass_showcase.polygon = PackedVector2Array([Vector2(-110, 10), Vector2(90, -85), Vector2(90, -118), Vector2(-110, -23)])
	glass_showcase.color = Color(0.68, 0.94, 1.0, 0.32)
	glass_showcase.visible = false
	buffet_node.add_child(glass_showcase)

	var kitchen_node = Node2D.new()
	kitchen_node.position = Vector2(730, 385)
	world_container.add_child(kitchen_node)

	var stove_front = Polygon2D.new()
	stove_front.polygon = PackedVector2Array([Vector2(-105, 25), Vector2(105, -75), Vector2(105, -38), Vector2(-105, 62)])
	stove_front.color = Color("#2B2D42")
	kitchen_node.add_child(stove_front)

	var stove_top = Polygon2D.new()
	stove_top.polygon = PackedVector2Array([Vector2(-105, 25), Vector2(105, -75), Vector2(150, -53), Vector2(-60, 47)])
	stove_top.color = Color("#4A4E69")
	kitchen_node.add_child(stove_top)

	var bottle_red = Polygon2D.new()
	bottle_red.polygon = PackedVector2Array([Vector2(-82, 16), Vector2(-74, 16), Vector2(-74, -2), Vector2(-82, -2)])
	bottle_red.color = Color("#E63946")
	kitchen_node.add_child(bottle_red)

	var bottle_soy = Polygon2D.new()
	bottle_soy.polygon = PackedVector2Array([Vector2(-68, 10), Vector2(-60, 10), Vector2(-60, -8), Vector2(-68, -8)])
	bottle_soy.color = Color("#1D1E2C")
	kitchen_node.add_child(bottle_soy)

	var wok_offsets = [Vector2(-30, -5), Vector2(40, -38)]
	for w_idx in range(2):
		var off = wok_offsets[w_idx]
		var fire = Polygon2D.new()
		fire.polygon = PackedVector2Array([off + Vector2(-2, 6), off + Vector2(22, -6), off + Vector2(34, 3), off + Vector2(10, 15)])
		fire.color = Color("#FF9F1C")
		fire.visible = false
		kitchen_node.add_child(fire)

		var rim = Polygon2D.new()
		rim.polygon = PackedVector2Array([off + Vector2(-12, 0), off + Vector2(26, -18), off + Vector2(48, -5), off + Vector2(10, 13)])
		rim.color = Color("#14151E")
		kitchen_node.add_child(rim)

		var liq = Polygon2D.new()
		liq.polygon = PackedVector2Array([off + Vector2(-5, 0), off + Vector2(24, -14), off + Vector2(41, -5), off + Vector2(12, 9)])
		liq.color = Color("#D90429")
		liq.visible = false
		kitchen_node.add_child(liq)

		wok_visuals.append({
			"fire": fire, "rim": rim, "liquid": liq,
			"world_pos": kitchen_node.position + off + Vector2(18, -8)
		})

	player_avatar = create_chibi_character(Color("#F77F00"), "JURAGAN", "chef")
	player_avatar.position = Vector2(815, 340)
	world_container.add_child(player_avatar)

	cashier_avatar = create_chibi_character(Color("#00BBF9"), "KASIR (AUTO)", "cashier")
	cashier_avatar.position = Vector2(640, 260)
	cashier_avatar.visible = false
	world_container.add_child(cashier_avatar)

	customer_avatar = create_chibi_character(Color("#457B9D"), "Pembeli", "customer")
	customer_avatar.position = Vector2(160, 520)
	customer_avatar.visible = false
	world_container.add_child(customer_avatar)

	cust_bubble_panel = PanelContainer.new()
	cust_bubble_panel.position = Vector2(-55, -135)
	cust_bubble_panel.add_theme_stylebox_override("panel", make_card_style(Color("#FFFDF7"), Color("#2B2D42"), 8))
	customer_avatar.add_child(cust_bubble_panel)

	cust_bubble = Label.new()
	cust_bubble.add_theme_font_size_override("font_size", 12)
	cust_bubble.add_theme_color_override("font_color", Color("#1D1E2C"))
	cust_bubble_panel.add_child(cust_bubble)

	for r in range(38):
		var drop = ColorRect.new()
		drop.size = Vector2(2, 14)
		drop.rotation = 0.25
		drop.color = Color(0.65, 0.88, 1.0, 0.55)
		drop.position = Vector2(randf_range(0, 1280), randf_range(0, 720))
		drop.visible = false
		add_child(drop)
		rain_particles.append(drop)

func build_ui() -> void:
	var ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	var card_bg = Color(0.11, 0.09, 0.08, 0.92)
	var card_border = Color("#D4A373")

	# TOP HUD BAR
	var top_panel = PanelContainer.new()
	top_panel.position = Vector2(16, 10)
	top_panel.custom_minimum_size = Vector2(1248, 48)
	top_panel.add_theme_stylebox_override("panel", make_card_style(card_bg, card_border, 10))
	ui_layer.add_child(top_panel)

	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 16)
	top_panel.add_child(top_hbox)

	lbl_day = Label.new()
	lbl_day.add_theme_font_size_override("font_size", 15)
	top_hbox.add_child(lbl_day)

	lbl_money = Label.new()
	lbl_money.add_theme_font_size_override("font_size", 18)
	lbl_money.add_theme_color_override("font_color", Color("#80ED99"))
	top_hbox.add_child(lbl_money)

	lbl_rank = Label.new()
	lbl_rank.add_theme_font_size_override("font_size", 15)
	lbl_rank.add_theme_color_override("font_color", Color("#FFAFCC"))
	top_hbox.add_child(lbl_rank)

	lbl_weather = Label.new()
	lbl_weather.add_theme_font_size_override("font_size", 15)
	lbl_weather.text = "Cuaca: CERAH"
	top_hbox.add_child(lbl_weather)

	lbl_status = Label.new()
	lbl_status.add_theme_font_size_override("font_size", 15)
	lbl_status.text = "Warung Seblak Buka!"
	top_hbox.add_child(lbl_status)

	btn_mute = Button.new()
	btn_mute.text = "AUDIO: ON"
	btn_mute.custom_minimum_size = Vector2(95, 32)
	btn_mute.add_theme_stylebox_override("normal", make_btn_style(Color("#3D405B"), Color("#8D99AE")))
	btn_mute.pressed.connect(_on_toggle_mute)
	top_hbox.add_child(btn_mute)

	# PANEL KIRI ATAS: ANTREAN MANGKUK
	var cust_panel = PanelContainer.new()
	cust_panel.position = Vector2(16, 68)
	cust_panel.custom_minimum_size = Vector2(315, 255)
	cust_panel.add_theme_stylebox_override("panel", make_card_style(card_bg, card_border, 12))
	ui_layer.add_child(cust_panel)

	var cust_vbox = VBoxContainer.new()
	cust_vbox.add_theme_constant_override("separation", 6)
	cust_panel.add_child(cust_vbox)

	var q_title = Label.new()
	q_title.text = "MANGKUK PESANAN"
	q_title.add_theme_font_size_override("font_size", 16)
	q_title.add_theme_color_override("font_color", Color("#FFD166"))
	cust_vbox.add_child(q_title)

	progress_patience = ProgressBar.new()
	progress_patience.max_value = 55.0
	progress_patience.value = 55.0
	progress_patience.custom_minimum_size = Vector2(0, 14)
	cust_vbox.add_child(progress_patience)

	lbl_queue_info = Label.new()
	lbl_queue_info.add_theme_font_size_override("font_size", 14)
	lbl_queue_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_queue_info.text = "Menunggu pembeli mengambil topping di rak prasmanan..."
	cust_vbox.add_child(lbl_queue_info)

	# PANEL BAWAH: 2 WAJAN MASAK
	var woks_hbox = HBoxContainer.new()
	woks_hbox.position = Vector2(16, 520)
	woks_hbox.add_theme_constant_override("separation", 12)
	ui_layer.add_child(woks_hbox)

	for w_idx in range(2):
		var w_panel = PanelContainer.new()
		w_panel.custom_minimum_size = Vector2(445, 185)
		w_panel.add_theme_stylebox_override("panel", make_card_style(card_bg, card_border, 12))
		woks_hbox.add_child(w_panel)

		var w_vbox = VBoxContainer.new()
		w_vbox.add_theme_constant_override("separation", 6)
		w_panel.add_child(w_vbox)

		var title = Label.new()
		title.text = "WAJAN #%d" % (w_idx + 1)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", Color("#FFD166"))
		w_vbox.add_child(title)

		var p_bar = ProgressBar.new()
		p_bar.max_value = 100.0
		p_bar.value = 0.0
		p_bar.custom_minimum_size = Vector2(0, 20)
		w_vbox.add_child(p_bar)

		var lbl_c = Label.new()
		lbl_c.text = "Cabai: Level 0 | Kosong"
		lbl_c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_c.add_theme_font_size_override("font_size", 14)
		w_vbox.add_child(lbl_c)

		var b_row = HBoxContainer.new()
		b_row.alignment = BoxContainer.ALIGNMENT_CENTER
		b_row.add_theme_constant_override("separation", 10)
		w_vbox.add_child(b_row)

		var b_chili = Button.new()
		b_chili.text = "+ Cabai"
		b_chili.custom_minimum_size = Vector2(135, 46)
		b_chili.add_theme_stylebox_override("normal", make_btn_style(Color("#9B2226"), Color("#FFCCD5")))
		b_chili.pressed.connect(func(): _on_wok_chili_pressed(w_idx))
		b_row.add_child(b_chili)

		var b_act = Button.new()
		b_act.text = "MASAK PESANAN"
		b_act.custom_minimum_size = Vector2(250, 46)
		b_act.add_theme_stylebox_override("normal", make_btn_style(Color("#2A9D8F"), Color("#B7E4C7")))
		b_act.pressed.connect(func(): _on_wok_action_pressed(w_idx))
		b_row.add_child(b_act)

		wok_ui.append({
			"panel": w_panel, "title": title, "bar": p_bar,
			"lbl_chili": lbl_c, "btn_chili": b_chili, "btn_act": b_act
		})

	# PANEL KANAN DENGAN SISTEM TAB
	var shop_panel = PanelContainer.new()
	shop_panel.position = Vector2(935, 68)
	shop_panel.custom_minimum_size = Vector2(329, 440)
	shop_panel.add_theme_stylebox_override("panel", make_card_style(card_bg, card_border, 12))
	ui_layer.add_child(shop_panel)

	var shop_vbox = VBoxContainer.new()
	shop_vbox.add_theme_constant_override("separation", 6)
	shop_panel.add_child(shop_vbox)

	var tab_bar = HBoxContainer.new()
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_bar.add_theme_constant_override("separation", 6)
	shop_vbox.add_child(tab_bar)

	btn_tab_stock = Button.new()
	btn_tab_stock.text = "BELANJA STOK"
	btn_tab_stock.custom_minimum_size = Vector2(148, 34)
	btn_tab_stock.pressed.connect(func(): switch_shop_tab(true))
	tab_bar.add_child(btn_tab_stock)

	btn_tab_upgrade = Button.new()
	btn_tab_upgrade.text = "UPGRADE WARUNG"
	btn_tab_upgrade.custom_minimum_size = Vector2(148, 34)
	btn_tab_upgrade.pressed.connect(func(): switch_shop_tab(false))
	tab_bar.add_child(btn_tab_upgrade)

	tab_stock_box = VBoxContainer.new()
	shop_vbox.add_child(tab_stock_box)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 365)
	tab_stock_box.add_child(scroll)

	restock_container = VBoxContainer.new()
	restock_container.add_theme_constant_override("separation", 5)
	scroll.add_child(restock_container)

	tab_upgrade_box = VBoxContainer.new()
	tab_upgrade_box.add_theme_constant_override("separation", 6)
	tab_upgrade_box.visible = false
	shop_vbox.add_child(tab_upgrade_box)

	btn_unlock_wok2 = Button.new()
	btn_unlock_wok2.custom_minimum_size = Vector2(0, 40)
	btn_unlock_wok2.pressed.connect(_on_unlock_wok2_pressed)
	tab_upgrade_box.add_child(btn_unlock_wok2)

	btn_hire_cashier = Button.new()
	btn_hire_cashier.custom_minimum_size = Vector2(0, 40)
	btn_hire_cashier.pressed.connect(_on_hire_cashier_pressed)
	tab_upgrade_box.add_child(btn_hire_cashier)

	btn_unlock_drinks = Button.new()
	btn_unlock_drinks.custom_minimum_size = Vector2(0, 40)
	btn_unlock_drinks.pressed.connect(_on_unlock_drinks_pressed)
	tab_upgrade_box.add_child(btn_unlock_drinks)

	btn_upgrade_decor = Button.new()
	btn_upgrade_decor.custom_minimum_size = Vector2(0, 40)
	btn_upgrade_decor.pressed.connect(_on_upgrade_decor_pressed)
	tab_upgrade_box.add_child(btn_upgrade_decor)

	btn_upgrade_stove = Button.new()
	btn_upgrade_stove.custom_minimum_size = Vector2(0, 40)
	btn_upgrade_stove.pressed.connect(_on_upgrade_stove_pressed)
	tab_upgrade_box.add_child(btn_upgrade_stove)

	btn_upgrade_fan = Button.new()
	btn_upgrade_fan.custom_minimum_size = Vector2(0, 40)
	btn_upgrade_fan.pressed.connect(_on_upgrade_fan_pressed)
	tab_upgrade_box.add_child(btn_upgrade_fan)

	btn_unlock_qris = Button.new()
	btn_unlock_qris.custom_minimum_size = Vector2(0, 40)
	btn_unlock_qris.pressed.connect(_on_unlock_qris_pressed)
	tab_upgrade_box.add_child(btn_unlock_qris)

	switch_shop_tab(true)

	# MODAL KASIR & KASBON
	cashier_panel = PanelContainer.new()
	cashier_panel.position = Vector2(400, 155)
	cashier_panel.custom_minimum_size = Vector2(450, 270)
	cashier_panel.add_theme_stylebox_override("panel", make_card_style(Color("#1D1E2C"), Color("#FFD166"), 14))
	cashier_panel.visible = false
	ui_layer.add_child(cashier_panel)

	var cash_vbox = VBoxContainer.new()
	cash_vbox.add_theme_constant_override("separation", 14)
	cashier_panel.add_child(cash_vbox)

	var cash_title = Label.new()
	cash_title.text = "MEJA KASIR WARUNG SEBLAK"
	cash_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cash_title.add_theme_font_size_override("font_size", 20)
	cash_title.add_theme_color_override("font_color", Color("#FFD166"))
	cash_vbox.add_child(cash_title)

	lbl_cashier_detail = Label.new()
	lbl_cashier_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_cashier_detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_cashier_detail.add_theme_font_size_override("font_size", 16)
	cash_vbox.add_child(lbl_cashier_detail)

	var cash_btns = HBoxContainer.new()
	cash_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	cash_btns.add_theme_constant_override("separation", 12)
	cash_vbox.add_child(cash_btns)

	btn_cashier_opt1 = Button.new()
	btn_cashier_opt1.custom_minimum_size = Vector2(130, 50)
	cash_btns.add_child(btn_cashier_opt1)

	btn_cashier_opt2 = Button.new()
	btn_cashier_opt2.custom_minimum_size = Vector2(130, 50)
	cash_btns.add_child(btn_cashier_opt2)

	btn_cashier_opt3 = Button.new()
	btn_cashier_opt3.custom_minimum_size = Vector2(130, 50)
	cash_btns.add_child(btn_cashier_opt3)

	# MODAL PEMBUKUAN AKHIR HARI
	summary_panel = PanelContainer.new()
	summary_panel.position = Vector2(390, 150)
	summary_panel.custom_minimum_size = Vector2(480, 340)
	summary_panel.add_theme_stylebox_override("panel", make_card_style(Color("#1D1E2C"), Color("#80ED99"), 14))
	summary_panel.visible = false
	ui_layer.add_child(summary_panel)

	var sum_vbox = VBoxContainer.new()
	sum_vbox.add_theme_constant_override("separation", 16)
	summary_panel.add_child(sum_vbox)

	var sum_title = Label.new()
	sum_title.text = "LAPORAN PEMBUKUAN HARIAN"
	sum_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sum_title.add_theme_font_size_override("font_size", 21)
	sum_title.add_theme_color_override("font_color", Color("#80ED99"))
	sum_vbox.add_child(sum_title)

	lbl_summary_text = Label.new()
	lbl_summary_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_summary_text.add_theme_font_size_override("font_size", 17)
	sum_vbox.add_child(lbl_summary_text)

	var btn_next_day = Button.new()
	btn_next_day.text = "BUKA WARUNG HARI BERIKUTNYA"
	btn_next_day.custom_minimum_size = Vector2(320, 55)
	btn_next_day.add_theme_stylebox_override("normal", make_btn_style(Color("#2A9D8F"), Color("#B7E4C7")))
	btn_next_day.pressed.connect(_on_next_day_pressed)
	sum_vbox.add_child(btn_next_day)

	# TITLE SCREEN / MAIN MENU OVERLAY
	title_overlay = PanelContainer.new()
	title_overlay.position = Vector2(330, 130)
	title_overlay.custom_minimum_size = Vector2(620, 440)
	title_overlay.add_theme_stylebox_override("panel", make_card_style(Color(0.09, 0.06, 0.05, 0.96), Color("#FF9F1C"), 18))
	ui_layer.add_child(title_overlay)

	var m_vbox = VBoxContainer.new()
	m_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	m_vbox.add_theme_constant_override("separation", 16)
	title_overlay.add_child(m_vbox)

	var m_title = Label.new()
	m_title.text = "SEBLAK PRASMANAN SIMULATOR"
	m_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m_title.add_theme_font_size_override("font_size", 30)
	m_title.add_theme_color_override("font_color", Color("#FFD166"))
	m_vbox.add_child(m_title)

	var m_sub = Label.new()
	m_sub.text = "Edisi Juragan Warung Bandung v5.0"
	m_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m_sub.add_theme_font_size_override("font_size", 17)
	m_sub.add_theme_color_override("font_color", Color("#FFAFCC"))
	m_vbox.add_child(m_sub)

	lbl_title_save_info = Label.new()
	lbl_title_save_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title_save_info.add_theme_font_size_override("font_size", 16)
	m_vbox.add_child(lbl_title_save_info)

	var btn_play = Button.new()
	btn_play.text = "BUKA WARUNG SEKARANG"
	btn_play.custom_minimum_size = Vector2(340, 62)
	btn_play.add_theme_font_size_override("font_size", 19)
	btn_play.add_theme_stylebox_override("normal", make_btn_style(Color("#E63946"), Color("#FFD166")))
	btn_play.pressed.connect(_on_start_game_pressed)
	m_vbox.add_child(btn_play)

	var btn_reset = Button.new()
	btn_reset.text = "Mulai Baru (Reset Progres)"
	btn_reset.custom_minimum_size = Vector2(240, 42)
	btn_reset.add_theme_stylebox_override("normal", make_btn_style(Color("#2B2D42"), Color("#8D99AE")))
	btn_reset.pressed.connect(_on_reset_progress_pressed)
	m_vbox.add_child(btn_reset)

func _on_start_game_pressed() -> void:
	AudioManager.play_cash_register()
	title_overlay.visible = false
	game_started = true
	lbl_status.text = "Warung Seblak Buka! Siap melayani pembeli!"

func _on_reset_progress_pressed() -> void:
	AudioManager.play_click()
	GameManager.reset_progress()
	update_hud()
	refresh_restock_shop()
	lbl_status.text = "Progres di-reset ke Hari 1!"

func switch_shop_tab(show_stock: bool) -> void:
	tab_stock_box.visible = show_stock
	tab_upgrade_box.visible = not show_stock
	btn_tab_stock.add_theme_stylebox_override("normal", make_btn_style(
		Color("#E76F51") if show_stock else Color("#2B2D42"), Color("#FFD166")
	))
	btn_tab_upgrade.add_theme_stylebox_override("normal", make_btn_style(
		Color("#E76F51") if not show_stock else Color("#2B2D42"), Color("#FFD166")
	))

func spawn_steam_puff(origin: Vector2, is_burnt: bool) -> void:
	var puff = Polygon2D.new()
	puff.polygon = PackedVector2Array([Vector2(-6, 0), Vector2(0, -6), Vector2(6, 0), Vector2(0, 6)])
	puff.color = Color(0.15, 0.15, 0.15, 0.65) if is_burnt else Color(1.0, 1.0, 1.0, 0.55)
	puff.position = origin + Vector2(randf_range(-10, 10), 0)
	add_child(puff)
	steam_particles.append({ "node": puff, "life": 1.1 })

func _process(delta: float) -> void:
	var t_sec = Time.get_ticks_msec() * 0.006
	player_avatar.get_node("Rig").position.y = sin(t_sec) * 2.5
	if cashier_avatar.visible:
		cashier_avatar.get_node("Rig").position.y = cos(t_sec) * 2.0

	if not game_started or day_ended:
		return

	if is_cust_walking:
		customer_avatar.get_node("Rig").position.y = -abs(sin(t_sec * 2.4)) * 6.0
	else:
		customer_avatar.get_node("Rig").position.y = sin(t_sec) * 2.0

	for idx in range(steam_particles.size() - 1, -1, -1):
		var sp = steam_particles[idx]
		sp["life"] -= delta
		sp["node"].position += Vector2(sin(t_sec + idx) * 14.0 * delta, -42.0 * delta)
		sp["node"].scale += Vector2(1.2 * delta, 1.2 * delta)
		sp["node"].modulate.a = max(0.0, sp["life"])
		if sp["life"] <= 0.0:
			sp["node"].queue_free()
			steam_particles.remove_at(idx)

	if viral_boost_timer > 0.0:
		viral_boost_timer -= delta
		if viral_boost_timer <= 0.0:
			lbl_status.text = "Efek viral Food Vlogger selesai. Jualan kembali normal."

	weather_timer -= delta
	if weather_timer <= 0.0:
		is_raining = not is_raining
		weather_timer = randf_range(16.0, 26.0)
		update_weather_visuals()

	if is_raining:
		for drop in rain_particles:
			drop.position += Vector2(-120.0 * delta, 520.0 * delta)
			if drop.position.y > 720:
				drop.position = Vector2(randf_range(0, 1400), -20)

	if cust_phase == CustomerPhase.NONE and waiting_orders.size() < 2:
		var rate = 1.0
		if is_raining:
			rate *= 1.6
		if viral_boost_timer > 0.0:
			rate *= 1.8
		spawn_timer -= delta * rate
		if spawn_timer <= 0.0:
			start_customer_visit()

	if cust_phase == CustomerPhase.WALKING_TO_BUFFET:
		is_cust_walking = true
		customer_avatar.position = customer_avatar.position.move_toward(target_pos, 200.0 * delta)
		if customer_avatar.position.distance_to(target_pos) < 4.0:
			is_cust_walking = false
			cust_phase = CustomerPhase.PICKING_TOPPINGS
			phase_timer = 1.4
			cust_bubble.text = "Ambil topping..."

	elif cust_phase == CustomerPhase.PICKING_TOPPINGS:
		phase_timer -= delta
		if phase_timer <= 0.0:
			finalize_customer_order()

	elif cust_phase == CustomerPhase.LEAVING:
		is_cust_walking = true
		customer_avatar.position = customer_avatar.position.move_toward(Vector2(140, 540), 230.0 * delta)
		if customer_avatar.position.distance_to(Vector2(140, 540)) < 6.0:
			is_cust_walking = false
			customer_avatar.visible = false
			cust_phase = CustomerPhase.NONE
			check_end_of_day()

	if waiting_orders.size() > 0 or is_any_wok_busy():
		customer_patience -= delta
		progress_patience.value = customer_patience
		if customer_patience <= 0.0:
			handle_patience_timeout()

	for i in range(2):
		var w = woks[i]
		if w["state"] != WokState.EMPTY:
			wok_visuals[i]["fire"].scale = Vector2(1.0 + sin(t_sec * 4.0 + i) * 0.12, 1.0 + cos(t_sec * 5.0) * 0.15)
			if randf() < 0.16:
				spawn_steam_puff(wok_visuals[i]["world_pos"], w["state"] == WokState.BURNT)

		if w["state"] == WokState.COOKING or w["state"] == WokState.READY:
			var speed_mult = 1.0 + (GameManager.stove_upgrade_level - 1) * 0.25
			w["progress"] += (delta * speed_mult / cook_duration) * 100.0
			wok_ui[i]["bar"].value = min(w["progress"], 100.0)
			
			if w["progress"] >= 70.0 and w["progress"] < 100.0:
				if w["state"] != WokState.READY:
					w["state"] = WokState.READY
					AudioManager.play_ready_bell()
					wok_ui[i]["btn_act"].text = "ANGKAT & SAJIKAN!"
					lbl_status.text = "Wajan #%d MATANG! Segera angkat!" % (i + 1)
			elif w["progress"] >= 100.0:
				w["state"] = WokState.BURNT
				wok_visuals[i]["liquid"].color = Color("#1B1B1B")
				AudioManager.play_error()
				wok_ui[i]["btn_act"].text = "BUANG GOSONG"
				lbl_status.text = "Wajan #%d GOSONG! Buang dan masak ulang!" % (i + 1)

func is_any_wok_busy() -> bool:
	return woks[0]["state"] != WokState.EMPTY or woks[1]["state"] != WokState.EMPTY

func update_weather_visuals() -> void:
	for drop in rain_particles:
		drop.visible = is_raining
	if is_raining:
		bg_rect.color = Color("#121722")
		lbl_weather.text = "Cuaca: HUJAN (+Bonus)"
		lbl_weather.add_theme_color_override("font_color", Color("#4CC9F0"))
	else:
		bg_rect.color = Color("#1F1714")
		lbl_weather.text = "Cuaca: CERAH"
		lbl_weather.add_theme_color_override("font_color", Color("#FFD166"))

func start_customer_visit() -> void:
	var available = GameManager.get_available_toppings()
	if available.size() == 0:
		lbl_status.text = "STOK HABIS! Belanja bahan di tab Belanja Stok!"
		spawn_timer = 3.0
		return

	var roll = randf()
	var is_vlogger = roll < 0.14
	var is_ojol = (not is_vlogger) and (roll < 0.35)
	var is_kasbon = (not is_vlogger) and (not is_ojol) and (roll < 0.48)
	
	var cname = ""
	var col = Color("#457B9D")
	if is_vlogger:
		cname = "FOOD VLOGGER"
		col = Color("#FFD700")
	elif is_ojol:
		cname = "Abang Ojol"
		col = Color("#2EC4B6")
	elif is_kasbon:
		cname = "Tetangga (Kasbon)"
		col = Color("#9B5DE5")
	else:
		cname = customer_names[randi() % customer_names.size()]
		col = shirt_colors[randi() % shirt_colors.size()]
	
	customer_avatar.get_node("Rig/Body").color = col
	customer_avatar.get_node("NameTag").text = cname
	customer_avatar.position = Vector2(150, 530)
	customer_avatar.visible = true
	cust_bubble.text = "Review Viral!" if is_vlogger else ("Order Ojol!" if is_ojol else ("Ngebon dulu ya!" if is_kasbon else "Permisi..."))
	target_pos = Vector2(440, 315)
	cust_phase = CustomerPhase.WALKING_TO_BUFFET
	
	current_order = SeblakOrder.new()
	current_order.cust_name = cname
	current_order.is_ojol = is_ojol
	current_order.is_vlogger = is_vlogger
	current_order.is_kasbon = is_kasbon
	current_order.drink_name = ""

func finalize_customer_order() -> void:
	var available = GameManager.get_available_toppings()
	if available.size() == 0:
		cust_phase = CustomerPhase.LEAVING
		return

	current_order.chili_req = randi_range(0, 5)
	current_order.items = []
	var base_price = 2000 + (1000 if is_raining else 0) + (GameManager.decor_level * 500)
	current_order.price = base_price

	var item_count = randi_range(2, min(4, available.size()))
	available.shuffle()
	for i in range(item_count):
		var chosen = available[i]
		current_order.items.append(chosen["name"])
		current_order.price += int(chosen["sell_price"])
		GameManager.consume_topping(chosen["id"])

	# Jika dispenser minuman aktif, 65% pembeli sekalian pesan Es Teh / Es Jeruk
	if GameManager.drinks_unlocked and randf() < 0.65:
		var drinks = ["Es Teh Manis", "Es Jeruk Segar"]
		current_order.drink_name = drinks[randi() % drinks.size()]
		current_order.price += 4000

	if current_order.is_ojol:
		current_order.price = int(current_order.price * 1.4)
	if current_order.is_vlogger:
		current_order.price = int(current_order.price * 1.8)
	if viral_boost_timer > 0.0:
		current_order.price *= 2

	waiting_orders.append(current_order)
	if waiting_orders.size() == 1 and not is_any_wok_busy():
		max_patience = 55.0 + (GameManager.fan_upgrade_level - 1) * 10.0
		customer_patience = max_patience
		progress_patience.max_value = max_patience

	cust_bubble.text = "Pedas Lvl %d!" % current_order.chili_req
	cust_phase = CustomerPhase.WAITING_FOOD
	spawn_timer = 3.5
	refresh_queue_ui()
	if current_order.is_vlogger:
		lbl_status.text = "AWAS! Food Vlogger datang! Masak pedas Lvl %d agar VIRAL!" % current_order.chili_req
	else:
		lbl_status.text = "Pesanan %s siap dimasak! Pilih Wajan!" % current_order.cust_name

func refresh_queue_ui() -> void:
	if waiting_orders.size() == 0:
		lbl_queue_info.text = "Belum ada mangkuk antre. Menunggu pembeli..."
		return
	var lines = []
	for idx in range(waiting_orders.size()):
		var o: SeblakOrder = waiting_orders[idx]
		var tag = " [VIRAL!]" if o.is_vlogger else (" [OJOL]" if o.is_ojol else (" [KASBON]" if o.is_kasbon else ""))
		var drink_str = (" + " + o.drink_name) if o.drink_name != "" else ""
		lines.append("[%d] %s%s (Pedas Lvl %d | Rp %d)
    %s%s" % [
			idx + 1, o.cust_name, tag, o.chili_req, o.price, ", ".join(o.items), drink_str
		])
	lbl_queue_info.text = "

".join(lines)

func _on_wok_chili_pressed(w_idx: int) -> void:
	var w = woks[w_idx]
	if w["state"] == WokState.COOKING or w["state"] == WokState.READY:
		w["chili"] = (w["chili"] + 1) % 6
		AudioManager.play_chili_chop()
		var ord: SeblakOrder = w["order"]
		wok_ui[w_idx]["lbl_chili"].text = "Cabai: Lvl %d (Target: Lvl %d)" % [w["chili"], ord.chili_req]
		var red_intensity = clamp(0.6 + w["chili"] * 0.08, 0.6, 1.0)
		wok_visuals[w_idx]["liquid"].color = Color(red_intensity, 0.12, 0.08)

func _on_wok_action_pressed(w_idx: int) -> void:
	if w_idx == 1 and not GameManager.second_wok_unlocked:
		lbl_status.text = "Wajan #2 terkunci! Buka di tab Upgrade Warung!"
		AudioManager.play_error()
		return

	var w = woks[w_idx]
	if w["state"] == WokState.EMPTY:
		if waiting_orders.size() == 0:
			lbl_status.text = "Belum ada mangkuk pesanan yang siap dimasak!"
			AudioManager.play_error()
			return
		var next_ord: SeblakOrder = waiting_orders.pop_front()
		refresh_queue_ui()
		
		w["state"] = WokState.COOKING
		w["progress"] = 0.0
		w["chili"] = 0
		w["order"] = next_ord
		
		wok_visuals[w_idx]["fire"].visible = true
		wok_visuals[w_idx]["liquid"].visible = true
		wok_visuals[w_idx]["liquid"].color = Color("#E07A5F")
		
		wok_ui[w_idx]["lbl_chili"].text = "Cabai: Lvl 0 (Target: Lvl %d)" % next_ord.chili_req
		wok_ui[w_idx]["btn_act"].text = "MEREBUS... (Tunggu 70%)"
		AudioManager.play_sizzle()
		lbl_status.text = "Memasak pesanan %s di Wajan #%d!" % [next_ord.cust_name, w_idx + 1]

	elif w["state"] == WokState.COOKING:
		lbl_status.text = "Seblak di Wajan #%d belum matang!" % (w_idx + 1)

	elif w["state"] == WokState.READY:
		if cashier_panel.visible:
			lbl_status.text = "Selesaikan pembayaran di kasir terlebih dahulu!"
			return
		ready_to_pay_order = w["order"]
		ready_chili_used = w["chili"]
		reset_single_wok(w_idx)
		process_serving()

	elif w["state"] == WokState.BURNT:
		var retry_ord: SeblakOrder = w["order"]
		w["state"] = WokState.COOKING
		w["progress"] = 0.0
		w["chili"] = 0
		wok_visuals[w_idx]["liquid"].color = Color("#E07A5F")
		wok_ui[w_idx]["lbl_chili"].text = "Cabai: Lvl 0 (Target: Lvl %d)" % retry_ord.chili_req
		wok_ui[w_idx]["btn_act"].text = "MEREBUS ULANG..."
		AudioManager.play_sizzle()
		lbl_status.text = "Memasak ulang pesanan %s!" % retry_ord.cust_name

func process_serving() -> void:
	final_bill_amount = ready_to_pay_order.price
	var note = ""
	var perfect_spice = (ready_chili_used == ready_to_pay_order.chili_req)
	
	if perfect_spice:
		final_bill_amount += 2000
		GameManager.reputation = min(100, GameManager.reputation + 2)
		note = "Pedas PAS Level %d! (+Tip Rp 2.000)" % ready_to_pay_order.chili_req
		if ready_to_pay_order.is_vlogger:
			viral_boost_timer = 22.0
			note += "
WARUNG VIRAL 20 DETIK! HARGA 2X LIPAT!"
	else:
		final_bill_amount = int(final_bill_amount * 0.7)
		GameManager.reputation = max(0, GameManager.reputation - 5)
		note = "Salah Level Pedas! (Diskon 30%%)"

	# Tetangga Kasbon: Dibayar 2x lipat besok pagi!
	if ready_to_pay_order.is_kasbon:
		GameManager.pending_kasbon += final_bill_amount
		GameManager.daily_customers_served += 1
		AudioManager.play_click()
		cust_bubble.text = "Besok dibayar 2x!"
		lbl_status.text = "[KASBON] %s catat bon Rp %d (Besok bayar 2x: Rp %d)!" % [
			ready_to_pay_order.cust_name, final_bill_amount, final_bill_amount * 2
		]
		update_hud()
		cust_phase = CustomerPhase.LEAVING
		spawn_timer = 1.5
		return

	if GameManager.cashier_hired:
		finish_payment(true)
		lbl_status.text = "[AUTO-KASIR] %s membayar Rp %d! %s" % [ready_to_pay_order.cust_name, final_bill_amount, note.replace("
", " ")]
		return

	is_qris_payment = ready_to_pay_order.is_ojol or (GameManager.qris_unlocked and (randf() < 0.55))
	cashier_panel.visible = true

	for btn in [btn_cashier_opt1, btn_cashier_opt2, btn_cashier_opt3]:
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn["callable"])

	if is_qris_payment:
		var pay_label = "TRANSFER OJOL" if ready_to_pay_order.is_ojol else "SCAN QRIS WARUNG"
		lbl_cashier_detail.text = "%s
%s

Total: Rp %d
Metode: %s" % [ready_to_pay_order.cust_name, note, final_bill_amount, pay_label]
		btn_cashier_opt1.visible = false
		btn_cashier_opt2.visible = true
		btn_cashier_opt3.visible = false
		btn_cashier_opt2.text = "TERIMA SALDO
(+Rp %d)" % final_bill_amount
		btn_cashier_opt2.pressed.connect(func(): finish_payment(true))
	else:
		paid_cash_amount = int(ceil(float(final_bill_amount) / 10000.0)) * 10000
		if paid_cash_amount == final_bill_amount:
			paid_cash_amount += 5000
		var correct_change = paid_cash_amount - final_bill_amount
		
		lbl_cashier_detail.text = "%s
%s

Total: Rp %d | Tunai: Rp %d
Pilih Kembalian:" % [
			ready_to_pay_order.cust_name, note, final_bill_amount, paid_cash_amount
		]
		var options = [correct_change, correct_change + 2000, max(0, correct_change - 2000)]
		options.shuffle()
		
		var btns = [btn_cashier_opt1, btn_cashier_opt2, btn_cashier_opt3]
		for i in range(3):
			btns[i].visible = true
			var val = options[i]
			btns[i].text = "Kembalian
Rp %d" % val
			btns[i].pressed.connect(func(): finish_payment(val == correct_change))

func finish_payment(is_correct: bool) -> void:
	cashier_panel.visible = false
	if is_correct:
		GameManager.add_money(final_bill_amount, true)
		AudioManager.play_cash_register()
		cust_bubble.text = "Mantap Kang!"
		if not GameManager.cashier_hired:
			lbl_status.text = "Pembayaran diterima! +Rp %d masuk kas." % final_bill_amount
	else:
		var penalty_pay = max(0, final_bill_amount - 2000)
		GameManager.add_money(penalty_pay, true)
		GameManager.reputation = max(0, GameManager.reputation - 3)
		AudioManager.play_error()
		lbl_status.text = "Salah kembalian! Rugi Rp 2.000."

	GameManager.daily_customers_served += 1
	update_hud()
	cust_phase = CustomerPhase.LEAVING
	spawn_timer = 1.5

func handle_patience_timeout() -> void:
	if waiting_orders.size() > 0:
		waiting_orders.pop_front()
		refresh_queue_ui()
	reset_single_wok(0)
	GameManager.reputation = max(0, GameManager.reputation - 8)
	GameManager.daily_customers_served += 1
	AudioManager.play_error()
	cust_bubble.text = "Lama banget!!"
	lbl_status.text = "Pembeli kabur karena kelamaan! Reputasi turun!"
	cust_phase = CustomerPhase.LEAVING
	spawn_timer = 2.0

func check_end_of_day() -> void:
	if GameManager.daily_customers_served >= GameManager.customers_per_day and waiting_orders.size() == 0 and not is_any_wok_busy():
		day_ended = true
		var rent_cost = 15000 + (5000 if GameManager.cashier_hired else 0)
		var net_profit = GameManager.daily_revenue - GameManager.daily_expense - rent_cost
		var kasbon_note = ("
Piutang Kasbon (Dibayar Besok 2x): Rp %d" % (GameManager.pending_kasbon * 2)) if GameManager.pending_kasbon > 0 else ""
		lbl_summary_text.text = "Hari ke-%d Selesai!
Status: %s

Pendapatan Seblak: +Rp %d
Belanja & Upgrade: -Rp %d
Sewa Lapak & Gaji: -Rp %d%s

Laba Bersih Hari Ini: Rp %d" % [
			GameManager.day, GameManager.get_shop_rank(), GameManager.daily_revenue, GameManager.daily_expense, rent_cost, kasbon_note, net_profit
		]
		summary_panel.visible = true

func _on_next_day_pressed() -> void:
	AudioManager.play_click()
	summary_panel.visible = false
	day_ended = false
	var bonus_kasbon = GameManager.start_next_day()
	if bonus_kasbon > 0:
		lbl_status.text = "Hari ke-%d! Tetangga lunasi kasbon +Rp %d!" % [GameManager.day, bonus_kasbon]
	else:
		lbl_status.text = "Hari ke-%d dimulai! Target: %d pembeli." % [GameManager.day, GameManager.customers_per_day]

func reset_single_wok(w_idx: int) -> void:
	woks[w_idx]["state"] = WokState.EMPTY
	woks[w_idx]["progress"] = 0.0
	woks[w_idx]["chili"] = 0
	woks[w_idx]["order"] = null
	wok_ui[w_idx]["bar"].value = 0.0
	wok_visuals[w_idx]["fire"].visible = false
	wok_visuals[w_idx]["liquid"].visible = false
	wok_ui[w_idx]["lbl_chili"].text = "Cabai: Level 0 | Kosong"
	wok_ui[w_idx]["btn_act"].text = "MASAK PESANAN"

func update_hud() -> void:
	lbl_money.text = "Kas: Rp %d" % GameManager.money
	lbl_day.text = "Hari %d (%d/%d) | Rep %d%%" % [GameManager.day, GameManager.daily_customers_served, GameManager.customers_per_day, GameManager.reputation]
	lbl_rank.text = "[%s]" % GameManager.get_shop_rank()
	
	if lbl_title_save_info:
		lbl_title_save_info.text = "Progres Tersimpan: Hari %d | Kas Rp %d
Pangkat: %s" % [GameManager.day, GameManager.money, GameManager.get_shop_rank()]

	glass_showcase.visible = (GameManager.decor_level >= 2)
	neon_sign_bg.visible = (GameManager.decor_level >= 3)
	cashier_avatar.visible = GameManager.cashier_hired
	drink_cooler.visible = GameManager.drinks_unlocked

	if GameManager.second_wok_unlocked:
		btn_unlock_wok2.text = "Wajan #2: AKTIF"
		btn_unlock_wok2.disabled = true
		wok_ui[1]["panel"].modulate = Color(1, 1, 1, 1)
	else:
		btn_unlock_wok2.text = "Beli Wajan #2 (Rp 60.000)"
		wok_ui[1]["panel"].modulate = Color(0.65, 0.65, 0.65, 0.85)

	if GameManager.cashier_hired:
		btn_hire_cashier.text = "Karyawan Kasir: AKTIF"
		btn_hire_cashier.disabled = true
	else:
		btn_hire_cashier.text = "Rekrut Kasir Otomatis (Rp 120.000)"

	if GameManager.drinks_unlocked:
		btn_unlock_drinks.text = "Dispenser Es Teh/Jeruk: AKTIF"
		btn_unlock_drinks.disabled = true
	else:
		btn_unlock_drinks.text = "Beli Dispenser Es Teh (Rp 45.000)"

	if GameManager.decor_level >= 3:
		btn_upgrade_decor.text = "Dekorasi: MAKSIMAL (Neon Box)"
		btn_upgrade_decor.disabled = true
	else:
		var next_name = "Etalase Kaca" if GameManager.decor_level == 1 else "Neon Box Viral"
		btn_upgrade_decor.text = "Upgrade %s (Rp %d)" % [next_name, GameManager.decor_level * 50000]

	btn_upgrade_stove.text = "Api Kompor Lvl %d (Rp %d)" % [GameManager.stove_upgrade_level + 1, GameManager.stove_upgrade_level * 35000]
	btn_upgrade_fan.text = "Kipas Angin Lvl %d (Rp %d)" % [GameManager.fan_upgrade_level + 1, GameManager.fan_upgrade_level * 25000]
	if GameManager.qris_unlocked:
		btn_unlock_qris.text = "Pembayaran QRIS: AKTIF"
		btn_unlock_qris.disabled = true
	else:
		btn_unlock_qris.text = "Buka Pembayaran QRIS (Rp 40.000)"

func refresh_restock_shop() -> void:
	for child in restock_container.get_children():
		child.queue_free()

	for i in range(GameManager.toppings.size()):
		var item = GameManager.toppings[i]
		var pack_cost = int(item["buy_price"]) * 5
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(288, 38)
		btn.text = "%s (Stok: %d) | +5: Rp %d" % [item["name"], item["stock"], pack_cost]
		btn.add_theme_stylebox_override("normal", make_btn_style(
			Color("#582F0E") if item["stock"] <= 3 else Color("#2B2D42"),
			Color("#E63946") if item["stock"] <= 3 else Color("#8D99AE")
		))
		btn.pressed.connect(func(): _on_buy_stock(i))
		restock_container.add_child(btn)

func _on_buy_stock(index: int) -> void:
	if GameManager.restock_topping(index):
		AudioManager.play_click()
		lbl_status.text = "Restock %s berhasil!" % GameManager.toppings[index]["name"]
	else:
		AudioManager.play_error()
		lbl_status.text = "Uang kas tidak cukup!"

func _on_unlock_wok2_pressed() -> void:
	if GameManager.unlock_second_wok():
		AudioManager.play_cash_register()
		lbl_status.text = "Wajan #2 terbuka!"
	else:
		AudioManager.play_error()
		lbl_status.text = "Kas belum cukup!"

func _on_hire_cashier_pressed() -> void:
	if GameManager.hire_cashier():
		AudioManager.play_cash_register()
		lbl_status.text = "Karyawan Kasir direkrut!"
	else:
		AudioManager.play_error()
		lbl_status.text = "Kas belum cukup (Butuh Rp 120.000)!"

func _on_unlock_drinks_pressed() -> void:
	if GameManager.unlock_drinks():
		AudioManager.play_cash_register()
		lbl_status.text = "Dispenser Es Teh & Es Jeruk terpasang! Margin naik!"
	else:
		AudioManager.play_error()
		lbl_status.text = "Kas belum cukup (Butuh Rp 45.000)!"

func _on_upgrade_decor_pressed() -> void:
	if GameManager.upgrade_decor():
		AudioManager.play_cash_register()
		lbl_status.text = "Dekorasi warung di-upgrade!"
	else:
		AudioManager.play_error()
		lbl_status.text = "Kas belum cukup!"

func _on_upgrade_stove_pressed() -> void:
	if GameManager.upgrade_stove():
		AudioManager.play_cash_register()
		lbl_status.text = "Api Kompor naik ke Level %d!" % GameManager.stove_upgrade_level
	else:
		AudioManager.play_error()
		lbl_status.text = "Kas belum cukup!"

func _on_upgrade_fan_pressed() -> void:
	if GameManager.upgrade_fan():
		AudioManager.play_cash_register()
		lbl_status.text = "Kipas angin dipasang!"
	else:
		AudioManager.play_error()
		lbl_status.text = "Kas belum cukup!"

func _on_unlock_qris_pressed() -> void:
	if GameManager.unlock_qris():
		AudioManager.play_cash_register()
		lbl_status.text = "QRIS aktif!"
	else:
		AudioManager.play_error()
		lbl_status.text = "Kas belum cukup!"

func _on_toggle_mute() -> void:
	AudioManager.is_muted = not AudioManager.is_muted
	btn_mute.text = "AUDIO: OFF" if AudioManager.is_muted else "AUDIO: ON"
