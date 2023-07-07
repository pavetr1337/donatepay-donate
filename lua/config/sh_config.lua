if CLIENT then
	if not file.IsDir("dp_autodonate","DATA") then file.CreateDir("dp_autodonate") end
end
function dp_donate_pv.downloadImage(url,filename)
	if SERVER then return "obkak" end
	http.Fetch(url,
	function(body,len,headers,code)
		file.Write("dp_autodonate/"..filename,body)
	end,
	function(message)
		print("[DonatePay] Image Download Error: "..message)
	end
 	)
 	return "data/dp_autodonate/"..filename
end
//-----|SHARED CONFIG|-----//
dp_donate_pv = dp_donate_pv or {}
dp_donate_pv.currency = "₽" -- Значок валюты
dp_donate_pv.nickname = "@pavetr" -- Никнейм на DonatePay(https://donatepay.ru/donation/settings - все что идет после new.donatepay.ru/ в ссылке, может быть числом либо тегом) 
dp_donate_pv.paycurrency = "RUB" -- ВАЖНО! Валюта, в которой идут все товары, баланс и ОПЛАТА. Может быть RUB,USD,EUR или UAH
dp_donate_pv.bind = KEY_F6 -- Кнопка на открытие меню доната
dp_donate_pv.ccmd = "/donate" -- Команда в чате на открытие меню доната
dp_donate_pv.prefix = "[DonatePay] " -- Префикс логов и сообщений

dp_donate_pv.billingExpire = 0 -- Сколько действует платежная ссылка(в секундах, например 30*60 - полчаса), 0 - чтобы отключить таймер
dp_donate_pv.minsum = 25 -- Минимальная сумма доната в вашей валюте, для рублей это 25

dp_donate_pv.refreshRate = 10 -- Через сколько секунд проверяется баланс, слишком малое значение может нагрузить сервер, из-за слишком большого игрок может не дождаться пополнения и ливнуть

dp_donate_pv.admin_ranks = { -- Ранги, которые могут пользоваться админ-панелью
	["superadmin"] = true
}

dp_donate_pv.defaultImage = "https://i.imgur.com/r6EFPFF.png" -- Стандартная картинка если не установлена другая
dp_donate_pv.defaultDesc = "Купив этот предмет вы будете очень крутым" -- Стандартное описание если не установлено другое
dp_donate_pv.tabs = { -- Категории в донате
	"Группы",
	"Оружие",
	"Деньги",
	"Разное",
}

dp_donate_pv.theme = "brokencock" -- Тема доната

dp_donate_pv.colors = { -- Цвета тем
	["gmod"] = { -- название темы
		["background"] = Color(79,79,79), -- Фон
		["outline"] = Color(54,54,54), -- Обводка
		["second"] = Color(41,128,185), -- Цвет темы
		["third"] = Color(171,171,171), -- Второстепенный цвет
		["text"] = Color(255,255,255), -- Текст
	},
	["brokencock"] = {
		["background"] = Color(22,22,22),
		["outline"] = color_transparent, -- Один из вариантов как можно убрать обводку
		["second"] = Color(118,68,194),
		["third"] = Color(45,45,45),
		["text"] = Color(255,255,255),
	},
	["lolz"] = {
		["background"] = Color(48,48,48),
		["outline"] = color_transparent,
		["second"] = Color(34,142,93),
		["third"] = Color(39,39,39),
		["text"] = Color(255,255,255),
	},
}

dp_donate_pv.icostyle = "flat" -- Стиль иконок

dp_donate_pv.icons = { -- Иконки
	["slik"] = { -- Название стиля
		["refresh"] = "icon16/arrow_refresh.png", -- Путь к иконке, если хотите загрузить с интернета то юзайте функцию dp_donate_pv.downloadImage("урл","иконка.png") как в стиле ниже
		["admin"] = "icon16/shield.png",
		["theme"] = "icon16/color_wheel.png",
	},
	["flat"] = {
		["refresh"] = dp_donate_pv.downloadImage("https://i.imgur.com/cJk5PaX.png","flat_refresh.png"),
		["admin"] = dp_donate_pv.downloadImage("https://i.imgur.com/q9B5sQK.png","flat_admin.png"),
		["theme"] = dp_donate_pv.downloadImage("https://i.imgur.com/qsSmWpo.png","flat_theme.png"),
	},
}

dp_donate_pv.style = { -- Параметры стиля
	["outline"] = 4 -- Размер обводки
}


/*
Обычная дата(Human readable time) 	Секунды
1 минута							60 секунд
1 час								3600 секунд
1 день								86400 секунд
1 неделя							604800 секунд
1 месяц (30.44 дней)				2629743 секунд
1 год (365.24 дней)					31556926 секунд
*/
dp_donate_pv.items = { -- Предметы
	{
		["id"] = "weapon_p228", -- Айди
		["title"] = "Пистолет P228", -- Название
		["category"] = "Оружие", -- Категория - должна быть как в таблице dp_donate_pv.tabs
		["price"] = 25, -- Цена
		["weapon"] = "weapon_pistol", -- [Для оружий] Класс оружия для выдачи
		["desc"] = "Старый пожилой пистолет деда", -- [Необязательно] Описание в карточке
		["image"] = "https://pavetr.ru/static/pvlogo-new.jpg" -- [Необязательно] Прямая ссылка для картинки в карточке
	},
	{
		["id"] = "fa_admin", -- Айди
		["title"] = "Админка", -- Название
		["category"] = "Группы", -- Категория - должна быть как в таблице dp_donate_pv.tabs
		["price"] = 100, -- Цена
		["farank"] = "admin" -- [Для FAdmin] Ранг
	},
	{
		["id"] = "fa_admin_timed", -- Айди
		["title"] = "Админка на 1 минуту", -- Название
		["category"] = "Группы", -- Категория - должна быть как в таблице dp_donate_pv.tabs
		["price"] = 10, -- Цена
		["farank"] = "admin", -- [Для FAdmin] Ранг
		["expire"] = 60, -- Когда истекает в сек.(для бесконечности фадминки не пиши этот параметр)
	},
	--Другие админки
	/*
	{
		["id"] = "sam_admin", -- Айди
		["title"] = "Админка", -- Название
		["category"] = "Группы", -- Категория - должна быть как в таблице dp_donate_pv.tabs
		["price"] = 100, -- Цена
		["expire"] = 0, -- Когда истекает в сек.(0 безлимит)
		["samrank"] = "admin" -- [Для SAM] Ранг
	},
	{
		["id"] = "ba_admin", -- Айди
		["title"] = "Админка", -- Название
		["category"] = "Группы", -- Категория - должна быть как в таблице dp_donate_pv.tabs
		["price"] = 100, -- Цена
		["expire"] = 0, -- Когда истекает в сек.(0 безлимит)
		["barank"] = "admin" -- [Для SAM] Ранг
	},
	*/
	{
		["id"] = "money_100k", -- Айди
		["title"] = "100к Валюты", -- Название
		["category"] = "Деньги", -- Категория - должна быть как в таблице dp_donate_pv.tabs
		["price"] = 10, -- Цена
		["drpmoney"] = 100000 -- [Для DarkRP] Количество денег
	},
	{
		["id"] = "boost_hp", -- Айди
		["title"] = "+10 HP при спавне", -- Название
		["category"] = "Разное", -- Категория - должна быть как в таблице dp_donate_pv.tabs
		["price"] = 25, -- Цена
		["max"] = 2, -- Сколько предметов можно максимально купить? Не ставьте этот параметр если хотите безлимит
		["hpboost"] = 10 -- Буст хп(+10 хп)
	},
	{
		["id"] = "boost_ar", -- Айди
		["title"] = "+10 брони при спавне", -- Название
		["category"] = "Разное", -- Категория - должна быть как в таблице dp_donate_pv.tabs
		["price"] = 25, -- Цена
		["arboost"] = 10 -- Буст брони(+10 брони)
	},
}

dp_donate_pv.locales = { -- Язык
	["window"] = "Автодонат",
	["price"] = "Цена: ",
	["buy"] = "Купить",
	["apanel"] = "Админ-Панель",
	["eval"] = "Введите значение...",
	["run"] = "Выполнить",
	["nickclm"] = "Ник",
	["sidclm"] = "Стимайди",
	["themes"] = "Темы",
	["dontleave"] = "НЕ ВЫХОДИТЕ С СЕРВЕРА ДО ЗАЧИСЛЕНИЯ СРЕДСТВ!",
	["description"] = "Описание",
}

dp_donate_pv.acmd = { -- Админ-Команды
	{
		["label"] = "addmoney", -- Название
		["cb_cmd"] = "dp_addmoney", -- Консольная команда
		["tip"] = "Прибавляет деньги к балансу", -- Подсказка
	},
	{
		["label"] = "setmoney",
		["cb_cmd"] = "dp_setmoney",
		["tip"] = "Устанавливает баланс игрока",
	},
	{
		["label"] = "additem",
		["cb_cmd"] = "dp_additem",
		["tip"] = "Добавляет предмет игроку по id",
	},
	/*{
		["label"] = "setitems",
		["cb_cmd"] = "dp_setitems",
		["tip"] = "ВАЖНО! ВВОД В ФОРМАТЕ JSON ['item']. Устанавливает предметы игрока.",
	},*/ -- Нестабильная параша, лучше не надо
	{
		["label"] = "nullitems",
		["cb_cmd"] = "dp_nullitems",
		["tip"] = 'Обнуляет предметы игрока.',
	},
	{
		["label"] = "getitems",
		["cb_cmd"] = "dp_getitems",
		["tip"] = "Из-за асинхронности нужно ВЫПОЛНИТЬ КОМАНДУ 2 РАЗА! Получение предметов игрока в консоль",
	},
	{
		["label"] = "regive",
		["cb_cmd"] = "dp_regive",
		["tip"] = "Перевыдает игроку все предметы(например, если сработал баг и оружие не выдалось)",
	},
	{
		["label"] = "getmoney",
		["cb_cmd"] = "dp_getmoney",
		["tip"] = "Получение баланса игрока",
	},
}