extends Node2D

enum WokState { EMPTY, COOKING, READY, BURNT }
var wok_state: WokState = WokState.EMPTY
var cook_progress: float = 0.0
var cook_duration: float = 5.0
var added_chili_level: int = 0

var has_customer: bool = false
var customer_name: String = ""
var customer_order: Array = []
var customer_chili_req: int = 0
var customer_patience: float = 45.0
var max_patience: float = 45.0
var order_total_price: int = 0
var spawn_timer: float = 1.5

var lbl_money: Label
var lbl_day: Label
var lbl_status: Label
var lbl_customer_info: Label
var lbl_order_list: Label
var progress_patience: ProgressBar
var progress_wok: ProgressBar
var lbl_wok_chili: Label
var btn_wok_action: Button
var btn_add_chili: Button
var restock_container: VBoxContainer
var btn_upgrade_stove: Button

var customer_names = [
	"Neng Geulis", "Kang Ojol", "Bocil Epep", "Ibu RT", 
	"Mahasiswa Kos", "Food Vlogger", "Teh Dinnar", "Mang Ujang"
]

func _ready() -> void:
	build_isometric_environment()
	build_ui()
	update_hud()
	refresh_restock_shop()
	GameManager.money_changed.connect(func(_m): update_hud())
	GameManager.stock_updated.connect(refresh_restock_shop)

func build_isometric_environment() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color("#2B2118")
	add_child(bg)
	
	var floor_poly = Polygon2D.new()
	floor_poly.polygon = PackedVector2Array([
		Vector2(640, 160),
		Vector2(1140, 390),
		Vector2(640, 620),
		Vector2(140, 390)
	])
	floor_poly.color = Color("#D9AE7E")
	add_child(floor_poly)
	
	var buffet_table = Polygon2D.new()
	buffet_table.polygon = PackedVector2Array([
		Vector2(340, 290),
		Vector2(580, 180),
		Vector2(630, 205),
		Vector2(390, 315)
	])
	buffet_table.color = Color("#8C4A27")
	add_child(buffet_table)
	
	var buffet_label = Label.new()
	buffet_label.text = "RAK PRASMANAN"
	buffet_label.position = Vector2(410, 210)
	buffet_label.rotation = -0.42
	add_child(buffet_label)

	var kitchen_table = Polygon2D.new()
	kitchen_table.polygon = PackedVector2Array([
		Vector2(680, 460),
		Vector2(920, 350),
		Vector2(980, 380),
		Vector2(740, 490)
	])
	kitchen_table.color = Color("#4A4E69")
	add_child(kitchen_table)

	var kitchen_label = Label.new()
	kitchen_label.text = "DAPUR WAJAN SEBLAK"
	kitchen_label.position = Vector2(750, 385)
	kitchen_label.rotation = -0.42
	add_child(kitchen_label)

func build_ui() -> void:
	var ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	var top_panel = PanelContainer.new()
	top_panel.position = Vector2(20, 15)
	top_panel.custom_minimum_size = Vector2(1240, 60)
	ui_layer.add_child(top_panel)

	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 40)
	top_panel.add_child(top_hbox)

	lbl_day = Label.new()
	lbl_day.add_theme_font_size_override("font_size", 24)
	top_hbox.add_child(lbl_day)

	lbl_money = Label.new()
	lbl_money.add_theme_font_size_override("font_size", 24)
	lbl_money.add_theme_color_override("font_color", Color("#80ED99"))
	top_hbox.add_child(lbl_money)

	lbl_status = Label.new()
	lbl_status.add_theme_font_size_override("font_size", 20)
	lbl_status.text = "Menunggu pembeli masuk ke rak prasmanan..."
	top_hbox.add_child(lbl_status)

	var cust_panel = PanelContainer.new()
	cust_panel.position = Vector2(20, 95)
	cust_panel.custom_minimum_size = Vector2(360, 320)
	ui_layer.add_child(cust_panel)

	var cust_vbox = VBoxContainer.new()
	cust_vbox.add_theme_constant_override("separation", 10)
	cust_panel.add_child(cust_vbox)

	lbl_customer_info = Label.new()
	lbl_customer_info.add_theme_font_size_override("font_size", 20)
	lbl_customer_info.text = "Belum Ada Pembeli"
	cust_vbox.add_child(lbl_customer_info)

	progress_patience = ProgressBar.new()
	progress_patience.max_value = 45.0
	progress_patience.value = 45.0
	progress_patience.custom_minimum_size = Vector2(0, 22)
	cust_vbox.add_child(progress_patience)

	lbl_order_list = Label.new()
	lbl_order_list.add_theme_font_size_override("font_size", 16)
	lbl_order_list.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_order_list.text = "Pembeli akan mengambil mangkuk dan memilih topping sendiri dari rak prasmanan."
	cust_vbox.add_child(lbl_order_list)

	var wok_panel = PanelContainer.new()
	wok_panel.position = Vector2(400, 480)
	wok_panel.custom_minimum_size = Vector2(480, 210)
	ui_layer.add_child(wok_panel)

	var wok_vbox = VBoxContainer.new()
	wok_vbox.add_theme_constant_override("separation", 12)
	wok_panel.add_child(wok_vbox)

	var wok_title = Label.new()
	wok_title.text = "KONTROL WAJAN SEBLAK"
	wok_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wok_title.add_theme_font_size_override("font_size", 20)
	wok_vbox.add_child(wok_title)

	progress_wok = ProgressBar.new()
	progress_wok.max_value = 100.0
	progress_wok.value = 0.0
	progress_wok.custom_minimum_size = Vector2(0, 30)
	wok_vbox.add_child(progress_wok)

	lbl_wok_chili = Label.new()
	lbl_wok_chili.text = "Takaran Cabai di Wajan: Level 0"
	lbl_wok_chili.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_wok_chili.add_theme_font_size_override("font_size", 18)
	wok_vbox.add_child(lbl_wok_chili)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 15)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	wok_vbox.add_child(btn_hbox)

	btn_add_chili = Button.new()
	btn_add_chili.text = "+ Tambah Cabai (Lvl +1)"
	btn_add_chili.custom_minimum_size = Vector2(200, 55)
	btn_add_chili.pressed.connect(_on_add_chili_pressed)
	btn_hbox.add_child(btn_add_chili)

	btn_wok_action = Button.new()
	btn_wok_action.text = "MASAK MANGKUK KE WAJAN"
	btn_wok_action.custom_minimum_size = Vector2(230, 55)
	btn_wok_action.pressed.connect(_on_wok_action_pressed)
	btn_hbox.add_child(btn_wok_action)

	var shop_panel = PanelContainer.new()
	shop_panel.position = Vector2(900, 95)
	shop_panel.custom_minimum_size = Vector2(360, 595)
	ui_layer.add_child(shop_panel)

	var shop_vbox = VBoxContainer.new()
	shop_vbox.add_theme_constant_override("separation", 8)
	shop_panel.add_child(shop_vbox)

	var shop_title = Label.new()
	shop_title.text = "GROSIR TOPPING & UPGRADE"
	shop_title.add_theme_font_size_override("font_size", 18)
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_vbox.add_child(shop_title)

	btn_upgrade_stove = Button.new()
	btn_upgrade_stove.custom_minimum_size = Vector2(0, 45)
	btn_upgrade_stove.pressed.connect(_on_upgrade_stove_pressed)
	shop_vbox.add_child(btn_upgrade_stove)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 490)
	shop_vbox.add_child(scroll)

	restock_container = VBoxContainer.new()
	restock_container.add_theme_constant_override("separation", 6)
	scroll.add_child(restock_container)

func _process(delta: float) -> void:
	if not has_customer:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_customer()
	else:
		customer_patience -= delta
		progress_patience.value = customer_patience
		if customer_patience <= 0.0:
			customer_leave_angry()

	if wok_state == WokState.COOKING or wok_state == WokState.READY:
		var speed_multiplier = 1.0 + (GameManager.stove_upgrade_level - 1) * 0.25
		cook_progress += (delta * speed_multiplier / cook_duration) * 100.0
		progress_wok.value = min(cook_progress, 100.0)
		
		if cook_progress >= 70.0 and cook_progress < 100.0:
			if wok_state != WokState.READY:
				wok_state = WokState.READY
				lbl_status.text = "SEBLAK MATANG! Segera angkat sebelum gosong!"
				btn_wok_action.text = "ANGKAT & SAJIKAN SEKARANG!"
		elif cook_progress >= 100.0:
			wok_state = WokState.BURNT
			lbl_status.text = "WADUH GOSONG! Buang seblak dan masak ulang!"
			btn_wok_action.text = "BUANG SEBLAK GOSONG"

func spawn_customer() -> void:
	var available = GameManager.get_available_toppings()
	if available.size() == 0:
		lbl_status.text = "STOK HABIS TOTAL! Beli bahan di panel kanan!"
		spawn_timer = 3.0
		return

	has_customer = true
	customer_name = customer_names[randi() % customer_names.size()]
	customer_chili_req = randi_range(0, 5)
	customer_order.clear()
	order_total_price = 2000

	var item_count = randi_range(2, min(4, available.size()))
	available.shuffle()
	for i in range(item_count):
		var chosen = available[i]
		customer_order.append(chosen["name"])
		order_total_price += int(chosen["sell_price"])
		GameManager.consume_topping(chosen["id"])

	max_patience = 45.0
	customer_patience = max_patience
	progress_patience.max_value = max_patience
	progress_patience.value = max_patience

	lbl_customer_info.text = "Pembeli: %s" % customer_name
	lbl_order_list.text = "Isi Mangkuk Prasmanan:
- %s

Request Pedas: LEVEL %d
Total Bayar: Rp %d" % [
		"
- ".join(customer_order),
		customer_chili_req,
		order_total_price
	]
	lbl_status.text = "%s sudah mengambil mangkuk prasmanan! Klik MASAK MANGKUK!" % customer_name

func _on_add_chili_pressed() -> void:
	if wok_state == WokState.COOKING or wok_state == WokState.READY:
		added_chili_level = (added_chili_level + 1) % 6
		lbl_wok_chili.text = "Takaran Cabai di Wajan: Level %d" % added_chili_level

func _on_wok_action_pressed() -> void:
	if wok_state == WokState.EMPTY:
		if not has_customer:
			lbl_status.text = "Belum ada mangkuk pesanan dari pembeli!"
			return
		wok_state = WokState.COOKING
		cook_progress = 0.0
		added_chili_level = 0
		lbl_wok_chili.text = "Takaran Cabai di Wajan: Level 0"
		btn_wok_action.text = "SEDANG MEREBUS... (Tunggu Hijau)"
		lbl_status.text = "Menumis bumbu kencur... Atur Level Cabai sesuai pesanan!"
		
	elif wok_state == WokState.COOKING:
		lbl_status.text = "Belum matang! Tunggu sampai bar mencapai 70%!"
		
	elif wok_state == WokState.READY:
		serve_seblak()
		
	elif wok_state == WokState.BURNT:
		reset_wok()
		lbl_status.text = "Wajan dibersihkan! Silakan masak ulang pesanan pembeli."

func serve_seblak() -> void:
	if not has_customer:
		reset_wok()
		return
	
	var final_payment = order_total_price
	if added_chili_level == customer_chili_req:
		var tip = 2000
		final_payment += tip
		lbl_status.text = "SEMPURNA! Pedas pas Level %d! Dapat tip +Rp 2.000!" % customer_chili_req
	else:
		final_payment = int(final_payment * 0.7)
		lbl_status.text = "Salah level pedas (Minta Lvl %d, dikasih Lvl %d). Bayar dipotong 30%%!" % [customer_chili_req, added_chili_level]

	GameManager.add_money(final_payment)
	has_customer = false
	spawn_timer = 2.0
	lbl_customer_info.text = "Belum Ada Pembeli"
	lbl_order_list.text = "Menunggu pembeli berikutnya masuk..."
	reset_wok()

func customer_leave_angry() -> void:
	has_customer = false
	spawn_timer = 2.5
	lbl_customer_info.text = "Pembeli Kabur!"
	lbl_order_list.text = "%s kelamaan menunggu dan pergi!" % customer_name
	lbl_status.text = "Pesanan gagal! Jangan sampai pembeli menunggu terlalu lama."
	reset_wok()

func reset_wok() -> void:
	wok_state = WokState.EMPTY
	cook_progress = 0.0
	progress_wok.value = 0.0
	added_chili_level = 0
	lbl_wok_chili.text = "Takaran Cabai di Wajan: Level 0"
	btn_wok_action.text = "MASAK MANGKUK KE WAJAN"

func update_hud() -> void:
	lbl_money.text = "Kas Warung: Rp %d" % GameManager.money
	lbl_day.text = "Hari ke-%d" % GameManager.day
	var upgrade_cost = GameManager.stove_upgrade_level * 35000
	btn_upgrade_stove.text = "Upgrade Kompor Lvl %d (Rp %d)" % [GameManager.stove_upgrade_level + 1, upgrade_cost]

func refresh_restock_shop() -> void:
	for child in restock_container.get_children():
		child.queue_free()

	for i in range(GameManager.toppings.size()):
		var item = GameManager.toppings[i]
		var pack_cost = int(item["buy_price"]) * 5
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(320, 44)
		btn.text = "%s (Stok: %d) | +5 Porsi: Rp %d" % [item["name"], item["stock"], pack_cost]
		btn.pressed.connect(func(): _on_buy_stock(i))
		restock_container.add_child(btn)

func _on_buy_stock(index: int) -> void:
	if GameManager.restock_topping(index):
		lbl_status.text = "Berhasil belanja stok %s!" % GameManager.toppings[index]["name"]
	else:
		lbl_status.text = "Uang kas tidak cukup untuk belanja bahan!"

func _on_upgrade_stove_pressed() -> void:
	if GameManager.upgrade_stove():
		update_hud()
		lbl_status.text = "Kompor di-upgrade ke Level %d! Masak jauh lebih cepat!" % GameManager.stove_upgrade_level
	else:
		lbl_status.text = "Uang kas belum cukup untuk upgrade kompor!"
