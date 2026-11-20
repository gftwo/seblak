extends Node2D

enum WokState { EMPTY, COOKING, READY, BURNT }
enum CustomerPhase { NONE, WALKING_TO_BUFFET, PICKING_TOPPINGS, WAITING_FOOD, PAYING_CASHIER, LEAVING }

# Kelas Data Pesanan
class SeblakOrder:
	var cust_name: String
	var items: Array
	var chili_req: int
	var price: int
	var is_ojol: bool

# State 2 Wajan Independen
var woks: Array = [
	{ "state": WokState.EMPTY, "progress": 0.0, "chili": 0, "order": null },
	{ "state": WokState.EMPTY, "progress": 0.0, "chili": 0, "order": null }
]
var cook_duration: float = 5.5

# State Pembeli & Antrean Meja
var cust_phase: CustomerPhase = CustomerPhase.NONE
var current_order: SeblakOrder = null
var waiting_orders: Array = [] # Antrean mangkuk siap dimasak
var ready_to_pay_order: SeblakOrder = null
var ready_chili_used: int = 0

var customer_patience: float = 55.0
var max_patience: float = 55.0
var final_bill_amount: int = 0
var paid_cash_amount: int = 0
var is_qris_payment: bool = false
var spawn_timer: float = 1.5
var phase_timer: float = 0.0
var day_ended: bool = false

# Sistem Cuaca (Hujan bikin pembeli ramai & bonus)
var is_raining: bool = false
var weather_timer: float = 18.0
var rain_particles: Array = []

# Visual 2.5D Nodes
var bg_rect: ColorRect
var world_container: Node2D
var player_avatar: Node2D
var customer_avatar: Node2D
var wok_visuals: Array = []
var cust_bubble: Label
var target_pos: Vector2 = Vector2.ZERO

# UI References
var lbl_money: Label
var lbl_day: Label
var lbl_weather: Label
var lbl_status: Label
var lbl_queue_info: Label
var progress_patience: ProgressBar
var wok_ui: Array = []

var restock_container: VBoxContainer
var btn_upgrade_stove: Button
var btn_upgrade_fan: Button
var btn_unlock_qris: Button
var btn_unlock_wok2: Button
var btn_mute: Button

# Cashier & Summary Modals
var cashier_panel: PanelContainer
var lbl_cashier_detail: Label
var btn_cashier_opt1: Button
var btn_cashier_opt2: Button
var btn_cashier_opt3: Button

var summary_panel: PanelContainer
var lbl_summary_text: Label

var customer_names = [
	"Neng Geulis", "Bocil Epep", "Ibu RT", "Mahasiswa Kos", 
	"Food Vlogger", "Teh Dinnar", "Mang Ujang", "Aa Bandung", "Teteh Kantor"
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

func create_25d_character(shirt_col: Color, label_text: String) -> Node2D:
	var root = Node2D.new()
	var shadow = Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(-18, 0), Vector2(0, -9), Vector2(18, 0), Vector2(0, 9)])
	shadow.color = Color(0, 0, 0, 0.35)
	root.add_child(shadow)
	
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-14, -45), Vector2(14, -45), Vector2(16, -5), Vector2(-16, -5)])
	body.color = shirt_col
	root.add_child(body)
	
	var head = Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(-11, -70), Vector2(11, -70), Vector2(11, -48), Vector2(-11, -48)])
	head.color = Color("#FFDCB6")
	root.add_child(head)
	
	var hair = Polygon2D.new()
	hair.polygon = PackedVector2Array([Vector2(-12, -74), Vector2(12, -74), Vector2(12, -64), Vector2(-12, -64)])
	hair.color = Color("#2B2118")
	root.add_child(hair)
	
	var tag = Label.new()
	tag.text = label_text
	tag.position = Vector2(-48, -96)
	tag.add_theme_font_size_override("font_size", 13)
	root.add_child(tag)
	return root

func build_isometric_world() -> void:
	bg_rect = ColorRect.new()
	bg_rect.size = Vector2(1280, 720)
	bg_rect.color = Color("#241B15")
	add_child(bg_rect)
	
	var road = Polygon2D.new()
	road.polygon = PackedVector2Array([Vector2(140, 390), Vector2(640, 620), Vector2(540, 680), Vector2(40, 450)])
	road.color = Color("#495057")
	add_child(road)
	
	var floor_poly = Polygon2D.new()
	floor_poly.polygon = PackedVector2Array([Vector2(640, 150), Vector2(1140, 380), Vector2(640, 610), Vector2(140, 380)])
	floor_poly.color = Color("#E6CCB2")
	add_child(floor_poly)
	
	var wall_left = Polygon2D.new()
	wall_left.polygon = PackedVector2Array([Vector2(140, 380), Vector2(640, 150), Vector2(640, 50), Vector2(140, 280)])
	wall_left.color = Color("#B08968")
	add_child(wall_left)
	
	var wall_right = Polygon2D.new()
	wall_right.polygon = PackedVector2Array([Vector2(640, 150), Vector2(1140, 380), Vector2(1140, 280), Vector2(640, 50)])
	wall_right.color = Color("#9C6644")
	add_child(wall_right)

	var banner = Label.new()
	banner.text = "SEBLAK PRASMANAN JUARA"
	banner.position = Vector2(430, 165)
	banner.rotation = -0.42
	banner.add_theme_font_size_override("font_size", 18)
	banner.add_theme_color_override("font_color", Color("#FFD166"))
	add_child(banner)

	world_container = Node2D.new()
	world_container.y_sort_enabled = true
	add_child(world_container)

	# Rak Prasmanan 2.5D
	var buffet_node = Node2D.new()
	buffet_node.position = Vector2(470, 260)
	world_container.add_child(buffet_node)
	
	var buffet_box = Polygon2D.new()
	buffet_box.polygon = PackedVector2Array([Vector2(-110, 10), Vector2(90, -80), Vector2(130, -60), Vector2(-70, 30)])
	buffet_box.color = Color("#7F4F24")
	buffet_node.add_child(buffet_box)

	var bowl_colors = [Color("#FF6B35"), Color("#FFD166"), Color("#F4A261"), Color("#E76F51"), Color("#2A9D8F")]
	for idx in range(5):
		var tray = Polygon2D.new()
		var ox = -75 + idx * 38
		var oy = -5 - idx * 17
		tray.polygon = PackedVector2Array([Vector2(ox, oy), Vector2(ox + 22, oy - 10), Vector2(ox + 34, oy - 3), Vector2(ox + 12, oy + 7)])
		tray.color = bowl_colors[idx]
		buffet_node.add_child(tray)

	# Meja Dapur 2 Wajan 2.5D
	var kitchen_node = Node2D.new()
	kitchen_node.position = Vector2(780, 390)
	world_container.add_child(kitchen_node)

	var stove_body = Polygon2D.new()
	stove_body.polygon = PackedVector2Array([Vector2(-105, 25), Vector2(105, -75), Vector2(145, -55), Vector2(-65, 45)])
	stove_body.color = Color("#3D405B")
	kitchen_node.add_child(stove_body)

	# Visual Wajan 1 & Wajan 2
	var wok_offsets = [Vector2(-35, -5), Vector2(35, -38)]
	for w_idx in range(2):
		var off = wok_offsets[w_idx]
		var fire = Polygon2D.new()
		fire.polygon = PackedVector2Array([off + Vector2(0, 5), off + Vector2(20, -5), off + Vector2(30, 3), off + Vector2(10, 13)])
		fire.color = Color("#FF9F1C")
		fire.visible = false
		kitchen_node.add_child(fire)

		var rim = Polygon2D.new()
		rim.polygon = PackedVector2Array([off + Vector2(-10, 0), off + Vector2(25, -17), off + Vector2(45, -5), off + Vector2(10, 12)])
		rim.color = Color("#1D1E2C")
		kitchen_node.add_child(rim)

		var liq = Polygon2D.new()
		liq.polygon = PackedVector2Array([off + Vector2(-4, 0), off + Vector2(23, -13), off + Vector2(38, -5), off + Vector2(11, 8)])
		liq.color = Color("#D90429")
		liq.visible = false
		kitchen_node.add_child(liq)

		wok_visuals.append({ "fire": fire, "rim": rim, "liquid": liq })

	player_avatar = create_25d_character(Color("#F77F00"), "JURAGAN")
	player_avatar.position = Vector2(855, 340)
	world_container.add_child(player_avatar)

	customer_avatar = create_25d_character(Color("#457B9D"), "Pembeli")
	customer_avatar.position = Vector2(180, 520)
	customer_avatar.visible = false
	world_container.add_child(customer_avatar)

	cust_bubble = Label.new()
	cust_bubble.position = Vector2(-50, -120)
	cust_bubble.add_theme_font_size_override("font_size", 14)
	cust_bubble.add_theme_color_override("font_color", Color("#FFE66D"))
	customer_avatar.add_child(cust_bubble)

	# Partikel Hujan Isometrik
	for r in range(35):
		var drop = ColorRect.new()
		drop.size = Vector2(2, 14)
		drop.rotation = 0.25
		drop.color = Color(0.65, 0.85, 1.0, 0.55)
		drop.position = Vector2(randf_range(0, 1280), randf_range(0, 720))
		drop.visible = false
		add_child(drop)
		rain_particles.append(drop)

func build_ui() -> void:
	var ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	# TOP HUD
	var top_panel = PanelContainer.new()
	top_panel.position = Vector2(20, 12)
	top_panel.custom_minimum_size = Vector2(1240, 54)
	ui_layer.add_child(top_panel)

	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 22)
	top_panel.add_child(top_hbox)

	lbl_day = Label.new()
	lbl_day.add_theme_font_size_override("font_size", 20)
	top_hbox.add_child(lbl_day)

	lbl_money = Label.new()
	lbl_money.add_theme_font_size_override("font_size", 20)
	lbl_money.add_theme_color_override("font_color", Color("#80ED99"))
	top_hbox.add_child(lbl_money)

	lbl_weather = Label.new()
	lbl_weather.add_theme_font_size_override("font_size", 18)
	lbl_weather.text = "Cuaca: CERAH"
	top_hbox.add_child(lbl_weather)

	lbl_status = Label.new()
	lbl_status.add_theme_font_size_override("font_size", 17)
	lbl_status.text = "Warung Seblak Buka!"
	top_hbox.add_child(lbl_status)

	btn_mute = Button.new()
	btn_mute.text = "SFX: ON"
	btn_mute.custom_minimum_size = Vector2(90, 36)
	btn_mute.pressed.connect(_on_toggle_mute)
	top_hbox.add_child(btn_mute)

	# PANEL KIRI: ANTREAN MANGKUK PRASMANAN & OJOL
	var cust_panel = PanelContainer.new()
	cust_panel.position = Vector2(20, 78)
	cust_panel.custom_minimum_size = Vector2(335, 310)
	ui_layer.add_child(cust_panel)

	var cust_vbox = VBoxContainer.new()
	cust_vbox.add_theme_constant_override("separation", 8)
	cust_panel.add_child(cust_vbox)

	var q_title = Label.new()
	q_title.text = "MANGKUK PESANAN MASUK"
	q_title.add_theme_font_size_override("font_size", 18)
	cust_vbox.add_child(q_title)

	progress_patience = ProgressBar.new()
	progress_patience.max_value = 55.0
	progress_patience.value = 55.0
	progress_patience.custom_minimum_size = Vector2(0, 18)
	cust_vbox.add_child(progress_patience)

	lbl_queue_info = Label.new()
	lbl_queue_info.add_theme_font_size_override("font_size", 15)
	lbl_queue_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_queue_info.text = "Menunggu pembeli mengambil topping di rak prasmanan..."
	cust_vbox.add_child(lbl_queue_info)

	# PANEL BAWAH TENGAH: 2 WAJAN SEBLAK
	var woks_hbox = HBoxContainer.new()
	woks_hbox.position = Vector2(20, 495)
	woks_hbox.add_theme_constant_override("separation", 14)
	ui_layer.add_child(woks_hbox)

	for w_idx in range(2):
		var w_panel = PanelContainer.new()
		w_panel.custom_minimum_size = Vector2(425, 205)
		woks_hbox.add_child(w_panel)

		var w_vbox = VBoxContainer.new()
		w_vbox.add_theme_constant_override("separation", 8)
		w_panel.add_child(w_vbox)

		var title = Label.new()
		title.text = "WAJAN #%d" % (w_idx + 1)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 18)
		w_vbox.add_child(title)

		var p_bar = ProgressBar.new()
		p_bar.max_value = 100.0
		p_bar.value = 0.0
		p_bar.custom_minimum_size = Vector2(0, 24)
		w_vbox.add_child(p_bar)

		var lbl_c = Label.new()
		lbl_c.text = "Cabai: Level 0 | Kosong"
		lbl_c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_c.add_theme_font_size_override("font_size", 15)
		w_vbox.add_child(lbl_c)

		var b_row = HBoxContainer.new()
		b_row.alignment = BoxContainer.ALIGNMENT_CENTER
		b_row.add_theme_constant_override("separation", 10)
		w_vbox.add_child(b_row)

		var b_chili = Button.new()
		b_chili.text = "+ Cabai"
		b_chili.custom_minimum_size = Vector2(140, 50)
		b_chili.pressed.connect(func(): _on_wok_chili_pressed(w_idx))
		b_row.add_child(b_chili)

		var b_act = Button.new()
		b_act.text = "MASAK PESANAN"
		b_act.custom_minimum_size = Vector2(230, 50)
		b_act.pressed.connect(func(): _on_wok_action_pressed(w_idx))
		b_row.add_child(b_act)

		wok_ui.append({
			"panel": w_panel, "title": title, "bar": p_bar,
			"lbl_chili": lbl_c, "btn_chili": b_chili, "btn_act": b_act
		})

	# PANEL KANAN: GROSIR & UPGRADE
	var shop_panel = PanelContainer.new()
	shop_panel.position = Vector2(900, 78)
	shop_panel.custom_minimum_size = Vector2(360, 622)
	ui_layer.add_child(shop_panel)

	var shop_vbox = VBoxContainer.new()
	shop_vbox.add_theme_constant_override("separation", 5)
	shop_panel.add_child(shop_vbox)

	var shop_title = Label.new()
	shop_title.text = "GROSIR TOPPING & UPGRADE"
	shop_title.add_theme_font_size_override("font_size", 17)
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_vbox.add_child(shop_title)

	btn_unlock_wok2 = Button.new()
	btn_unlock_wok2.custom_minimum_size = Vector2(0, 36)
	btn_unlock_wok2.pressed.connect(_on_unlock_wok2_pressed)
	shop_vbox.add_child(btn_unlock_wok2)

	btn_upgrade_stove = Button.new()
	btn_upgrade_stove.custom_minimum_size = Vector2(0, 36)
	btn_upgrade_stove.pressed.connect(_on_upgrade_stove_pressed)
	shop_vbox.add_child(btn_upgrade_stove)

	btn_upgrade_fan = Button.new()
	btn_upgrade_fan.custom_minimum_size = Vector2(0, 36)
	btn_upgrade_fan.pressed.connect(_on_upgrade_fan_pressed)
	shop_vbox.add_child(btn_upgrade_fan)

	btn_unlock_qris = Button.new()
	btn_unlock_qris.custom_minimum_size = Vector2(0, 36)
	btn_unlock_qris.pressed.connect(_on_unlock_qris_pressed)
	shop_vbox.add_child(btn_unlock_qris)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 410)
	shop_vbox.add_child(scroll)

	restock_container = VBoxContainer.new()
	restock_container.add_theme_constant_override("separation", 5)
	scroll.add_child(restock_container)

	# MODAL KASIR
	cashier_panel = PanelContainer.new()
	cashier_panel.position = Vector2(400, 155)
	cashier_panel.custom_minimum_size = Vector2(450, 270)
	cashier_panel.visible = false
	ui_layer.add_child(cashier_panel)

	var cash_vbox = VBoxContainer.new()
	cash_vbox.add_theme_constant_override("separation", 14)
	cashier_panel.add_child(cash_vbox)

	var cash_title = Label.new()
	cash_title.text = "MEJA KASIR WARUNG SEBLAK"
	cash_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cash_title.add_theme_font_size_override("font_size", 21)
	cash_vbox.add_child(cash_title)

	lbl_cashier_detail = Label.new()
	lbl_cashier_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_cashier_detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_cashier_detail.add_theme_font_size_override("font_size", 17)
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

	# MODAL LAPORAN MALAM
	summary_panel = PanelContainer.new()
	summary_panel.position = Vector2(390, 150)
	summary_panel.custom_minimum_size = Vector2(480, 340)
	summary_panel.visible = false
	ui_layer.add_child(summary_panel)

	var sum_vbox = VBoxContainer.new()
	sum_vbox.add_theme_constant_override("separation", 16)
	summary_panel.add_child(sum_vbox)

	var sum_title = Label.new()
	sum_title.text = "LAPORAN PEMBUKUAN HARIAN"
	sum_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sum_title.add_theme_font_size_override("font_size", 22)
	sum_vbox.add_child(sum_title)

	lbl_summary_text = Label.new()
	lbl_summary_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_summary_text.add_theme_font_size_override("font_size", 18)
	sum_vbox.add_child(lbl_summary_text)

	var btn_next_day = Button.new()
	btn_next_day.text = "BUKA WARUNG HARI BERIKUTNYA"
	btn_next_day.custom_minimum_size = Vector2(320, 55)
	btn_next_day.pressed.connect(_on_next_day_pressed)
	sum_vbox.add_child(btn_next_day)

func _process(delta: float) -> void:
	if day_ended:
		return

	player_avatar.position.y = 340 + sin(Time.get_ticks_msec() * 0.005) * 2.5

	# Siklus Cuaca Dinamis
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

	# Kedatangan Pembeli & Ojol
	if cust_phase == CustomerPhase.NONE and waiting_orders.size() < 2:
		spawn_timer -= delta * (1.8 if is_raining else 1.0)
		if spawn_timer <= 0.0:
			start_customer_visit()

	if cust_phase == CustomerPhase.WALKING_TO_BUFFET:
		customer_avatar.position = customer_avatar.position.move_toward(target_pos, 200.0 * delta)
		if customer_avatar.position.distance_to(target_pos) < 4.0:
			cust_phase = CustomerPhase.PICKING_TOPPINGS
			phase_timer = 1.4
			cust_bubble.text = "Ambil topping..."

	elif cust_phase == CustomerPhase.PICKING_TOPPINGS:
		phase_timer -= delta
		if phase_timer <= 0.0:
			finalize_customer_order()

	elif cust_phase == CustomerPhase.LEAVING:
		customer_avatar.position = customer_avatar.position.move_toward(Vector2(140, 540), 230.0 * delta)
		if customer_avatar.position.distance_to(Vector2(140, 540)) < 6.0:
			customer_avatar.visible = false
			cust_phase = CustomerPhase.NONE
			check_end_of_day()

	# Timer Kesabaran Pesanan Pertama di Antrean
	if waiting_orders.size() > 0 or is_any_wok_busy():
		customer_patience -= delta
		progress_patience.value = customer_patience
		if customer_patience <= 0.0:
			handle_patience_timeout()

	# Update Proses Memasak di Kedua Wajan
	for i in range(2):
		var w = woks[i]
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
		bg_rect.color = Color("#161B22")
		lbl_weather.text = "Cuaca: HUJAN DERAS (Pembeli Ramai +Bonus!)"
		lbl_weather.add_theme_color_override("font_color", Color("#4CC9F0"))
	else:
		bg_rect.color = Color("#241B15")
		lbl_weather.text = "Cuaca: CERAH"
		lbl_weather.add_theme_color_override("font_color", Color("#FFD166"))

func start_customer_visit() -> void:
	var available = GameManager.get_available_toppings()
	if available.size() == 0:
		lbl_status.text = "STOK HABIS! Belanja bahan di panel kanan!"
		spawn_timer = 3.0
		return

	var is_ojol = randf() < 0.25
	var cname = "Abang Ojol (SeblakFood)" if is_ojol else customer_names[randi() % customer_names.size()]
	var col = Color("#2EC4B6") if is_ojol else shirt_colors[randi() % shirt_colors.size()]
	
	customer_avatar.get_child(1).color = col
	customer_avatar.get_child(4).text = cname
	customer_avatar.position = Vector2(160, 530)
	customer_avatar.visible = true
	cust_bubble.text = "Order Ojol!" if is_ojol else "Permisi..."
	target_pos = Vector2(465, 315)
	cust_phase = CustomerPhase.WALKING_TO_BUFFET
	
	current_order = SeblakOrder.new()
	current_order.cust_name = cname
	current_order.is_ojol = is_ojol

func finalize_customer_order() -> void:
	var available = GameManager.get_available_toppings()
	if available.size() == 0:
		cust_phase = CustomerPhase.LEAVING
		return

	current_order.chili_req = randi_range(0, 5)
	current_order.items = []
	var base_price = 2000 + (1000 if is_raining else 0)
	current_order.price = base_price

	var item_count = randi_range(2, min(4, available.size()))
	available.shuffle()
	for i in range(item_count):
		var chosen = available[i]
		current_order.items.append(chosen["name"])
		current_order.price += int(chosen["sell_price"])
		GameManager.consume_topping(chosen["id"])

	if current_order.is_ojol:
		current_order.price = int(current_order.price * 1.4)

	waiting_orders.append(current_order)
	if waiting_orders.size() == 1 and not is_any_wok_busy():
		max_patience = 55.0 + (GameManager.fan_upgrade_level - 1) * 10.0
		customer_patience = max_patience
		progress_patience.max_value = max_patience

	cust_bubble.text = "Pedas Lvl %d!" % current_order.chili_req
	cust_phase = CustomerPhase.WAITING_FOOD
	spawn_timer = 3.5
	refresh_queue_ui()
	lbl_status.text = "Pesanan %s siap dimasak! Pilih Wajan!" % current_order.cust_name

func refresh_queue_ui() -> void:
	if waiting_orders.size() == 0:
		lbl_queue_info.text = "Belum ada mangkuk antre. Menunggu pembeli..."
		return
	var lines = []
	for idx in range(waiting_orders.size()):
		var o: SeblakOrder = waiting_orders[idx]
		lines.append("[%d] %s (Pedas Lvl %d | Rp %d)
    Topping: %s" % [
			idx + 1, o.cust_name, o.chili_req, o.price, ", ".join(o.items)
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
		lbl_status.text = "Wajan #2 terkunci! Beli di panel kanan (Rp 60.000)!"
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
		open_cashier_modal()

	elif w["state"] == WokState.BURNT:
		# Masak ulang pesanan yang gosong
		var retry_ord: SeblakOrder = w["order"]
		w["state"] = WokState.COOKING
		w["progress"] = 0.0
		w["chili"] = 0
		wok_visuals[w_idx]["liquid"].color = Color("#E07A5F")
		wok_ui[w_idx]["lbl_chili"].text = "Cabai: Lvl 0 (Target: Lvl %d)" % retry_ord.chili_req
		wok_ui[w_idx]["btn_act"].text = "MEREBUS ULANG..."
		AudioManager.play_sizzle()
		lbl_status.text = "Memasak ulang pesanan %s!" % retry_ord.cust_name

func open_cashier_modal() -> void:
	final_bill_amount = ready_to_pay_order.price
	var note = ""
	if ready_chili_used == ready_to_pay_order.chili_req:
		final_bill_amount += 2000
		GameManager.reputation = min(100, GameManager.reputation + 2)
		note = "Pedas PAS Level %d! (+Tip Rp 2.000)" % ready_to_pay_order.chili_req
	else:
		final_bill_amount = int(final_bill_amount * 0.7)
		GameManager.reputation = max(0, GameManager.reputation - 5)
		note = "Salah Level Pedas! (Diskon 30%%)"

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
		var net_profit = GameManager.daily_revenue - GameManager.daily_expense - 15000
		lbl_summary_text.text = "Hari ke-%d Selesai!

Pendapatan Seblak: +Rp %d
Belanja & Upgrade: -Rp %d
Sewa Lapak & Gas: -Rp 15.000

Laba Bersih: Rp %d" % [
			GameManager.day, GameManager.daily_revenue, GameManager.daily_expense, net_profit
		]
		summary_panel.visible = true

func _on_next_day_pressed() -> void:
	AudioManager.play_click()
	summary_panel.visible = false
	day_ended = false
	GameManager.start_next_day()
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
	lbl_day.text = "Hari %d (%d/%d) | Rep: %d%%" % [GameManager.day, GameManager.daily_customers_served, GameManager.customers_per_day, GameManager.reputation]
	
	if GameManager.second_wok_unlocked:
		btn_unlock_wok2.text = "Wajan #2: SUDAH AKTIF"
		btn_unlock_wok2.disabled = true
		wok_ui[1]["panel"].modulate = Color(1, 1, 1, 1)
	else:
		btn_unlock_wok2.text = "Beli Wajan #2 (Rp 60.000)"
		wok_ui[1]["panel"].modulate = Color(0.6, 0.6, 0.6, 0.85)

	btn_upgrade_stove.text = "Upgrade Api Kompor Lvl %d (Rp %d)" % [GameManager.stove_upgrade_level + 1, GameManager.stove_upgrade_level * 35000]
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
		btn.custom_minimum_size = Vector2(320, 38)
		btn.text = "%s (Stok: %d) | +5: Rp %d" % [item["name"], item["stock"], pack_cost]
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
		lbl_status.text = "Wajan #2 terbuka! Kini bisa masak 2 pesanan sekaligus!"
	else:
		AudioManager.play_error()
		lbl_status.text = "Kas belum cukup (Butuh Rp 60.000)!"

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
		lbl_status.text = "Kipas angin dipasang! Pembeli lebih sabar!"
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
	btn_mute.text = "SFX: OFF" if AudioManager.is_muted else "SFX: ON"
