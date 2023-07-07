-- Networking
if SERVER then
	-- Спасибо Вегабанчику, система жидких пенисов спизжена у IGS ибо нехуй такие комисии делать
	local SERIA_TIME   = 60 -- ~ каждые 60 сек будет сбрасываться счетчик
	local MAX_QUERIES  = 30 -- 30 запросов в минуту, получается
	local KICK_QUERIES = 60 -- 60 запросов в минуту с человека и кик

	local function SeriaTime()
		return os.time() % SERIA_TIME
	end

	local function checkNotReady(pl) -- не даем совершать никакие операции, если автодонат не загрузился (Например, бэкенд сдох)
		local current_frame = SeriaTime()

		local d = pl:GetVar("dp_net_burst", {0,0})
		local last_frame,queries = d[1],d[2]

		queries = (current_frame < last_frame) and 0 or queries + 1
		last_frame = current_frame

		d[1],d[2] = last_frame,queries

		pl:SetVar("dp_net_burst",d)
		if queries > KICK_QUERIES then
			pl:Kick("Пошел нахуй, спамить нетами нехорошо")
			return true
		end

		if queries > MAX_QUERIES then
			return true
		end
	end

	function net_ReceiveProtected(sName, fCallback)
		util.AddNetworkString(sName)
		net.Receive(sName,function(_,pl)
			if checkNotReady(pl) then return end
			fCallback(_,pl)
		end)
	end

	net_ReceiveProtected("dp_updatemoney", function(len,reqPl)
		dp_donate_pv.validatePlayer(reqPl)
		local val = sql.QueryValue("SELECT balance FROM donatepay_main WHERE sid64 = " .. sql.SQLStr( reqPl:SteamID64() ) .. ";")
		reqPl:SetNWInt("dp_balance",tonumber(val))
	end)

	net_ReceiveProtected("dp_updateitems", function(len,ply)
		local reqPl = net.ReadEntity()
		dp_donate_pv.validatePlayer(reqPl)
		local val = file.Read(dp_donate_pv.makefile(reqPl:SteamID64()),"DATA")
		reqPl:SetNWString("dp_items",val)
	end)
	net_ReceiveProtected("dp_buyitem", function(len,ply)
		local item = dp_donate_pv.items[net.ReadInt(32)]
		if dp_donate_pv.affordDonate(ply,item["price"]) then
			if isnumber(item["max"]) and dp_donate_pv.getItemRep(ply,item["id"]) >= item["max"] then ply:ChatPrint(dp_donate_pv.prefix.."Покупка отменена: Достигнут лимит предмета") return end
			dp_donate_pv.addMoney(ply,-item["price"])
			dp_donate_pv.addItem(ply,item["id"])
			hook.Run("dp_itemBought",ply,item["id"])
		end
	end)
	net_ReceiveProtected("dp_refill", function(len,ply)
		local amount = net.ReadInt(32)
		dp_donate_pv.createBill(ply,amount)
	end)
end

-- Util
local charset = {}  do
    for c = 48, 57  do table.insert(charset, string.char(c)) end
    for c = 65, 90  do table.insert(charset, string.char(c)) end
    for c = 97, 122 do table.insert(charset, string.char(c)) end
end

local function randomString(length)
    if not length or length <= 0 then return '' end
    math.randomseed(os.clock()^5)
    return randomString(length - 1) .. charset[math.random(1, #charset)]
end

function dp_donate_pv.itableById(tbl,id)
	local tret = 0
	if not tbl or not #tbl then return end
	for i=1,#tbl do
		if tbl[i]["id"] == id then
			tret = i
		end
	end
	return tret
end

-- Main
function dp_donate_pv.createBill(ply,sum)
	if SERVER then
		if sum >= dp_donate_pv.minsum then
			local orderNum = randomString(10)
			ply:SetNWString("dp_order",orderNum)
			ply:SetNWInt("dp_ordersum",sum)
			ply:SetNWInt("dp_ordertime",CurTime())
			ply:SendLua('gui.OpenURL("https://new.donatepay.ru/'..dp_donate_pv.nickname..'?name=provider%5Bundefined%5D%5B'..ply:SteamID64()..'%5D&amount='..tostring(sum)..'&currency='..dp_donate_pv.paycurrency..'&message='..orderNum..'")')
			if dp_donate_pv.billingExpire ~= 0 then
				ply:ChatPrint("У вас есть "..math.Round(dp_donate_pv.billingExpire/60).." минут чтобы оплатить счет!")
			end
			ply:ChatPrint(dp_donate_pv.locales["dontleave"])
			ply:ChatPrint("Баланс обновляется автоматически каждые "..dp_donate_pv.refreshRate.." секунд")
		else
			ply:SendLua('Derma_Message("Минимальная сумма пополнения "..dp_donate_pv.minsum..dp_donate_pv.currency.."!","Автодонат")')
		end
	end
end

function dp_donate_pv.getMoney(ply)
	if SERVER then
		dp_donate_pv.validatePlayer(ply)
		local val = sql.QueryValue( "SELECT balance FROM donatepay_main WHERE sid64 = " .. sql.SQLStr( ply:SteamID64() ) .. ";" )
		return tonumber(val)
	elseif CLIENT then
		net.Start("dp_updatemoney")
		net.SendToServer()
		return ply:GetNWInt("dp_balance")
	end
end

function dp_donate_pv.affordDonate(ply,amount)
	if dp_donate_pv.getMoney(ply) >= amount then
		return true
	else
		return false
	end
end

function dp_donate_pv.getItems(ply)
	if SERVER then
		dp_donate_pv.validatePlayer(ply)
		local val = file.Read(dp_donate_pv.makefile(ply:SteamID64()),"DATA")
		return isstring(val) and util.JSONToTable(val) or {}
	elseif CLIENT then
		net.Start("dp_updateitems")
		net.WriteEntity(ply)
		net.SendToServer()
		return isstring(ply:GetNWString("dp_items")) and util.JSONToTable(ply:GetNWString("dp_items")) or {}
	end
end

function dp_donate_pv.isExpired(ply,item,exp,ostime)
	local items = dp_donate_pv.getItems(ply)
	for z,itbl in ipairs(items) do
		local id = itbl[1]
		local time = itbl[2]
		local item = dp_donate_pv.items[dp_donate_pv.itableById(dp_donate_pv.items,id)]
		if not exp or not time then return false end
		if ostime - time > exp then
			return true
		else
			return false
		end
	end
end

function dp_donate_pv.getItemRep(ply,item)
	local reps = 0
	local itemst = dp_donate_pv.getItems(ply)

	for z,itable in ipairs(itemst) do
		if itable[1] == item then
			reps = reps+1
		end
	end
	return reps
end

--Menu
if CLIENT then
	if file.Exists("dp_autodonate/theme.txt","DATA") then
		local theme = file.Read("dp_autodonate/theme.txt","DATA")
		if istable(dp_donate_pv.colors[theme]) then
			dp_donate_pv.theme = theme
		end
	end

	if file.Exists("dp_autodonate/icostyle.txt","DATA") then
		local icons = file.Read("dp_autodonate/icostyle.txt","DATA")
		if istable(dp_donate_pv.icons[icons]) then
			dp_donate_pv.icostyle = icons
		end
	end

	surface.CreateFont("dp.main", {
		font = "Arial",
		extended = true,
		size = 23,
		weight = 500,
		antialias = true,
	})
	surface.CreateFont("dp.min", {
		font = "Arial",
		extended = true,
		size = 18,
		weight = 600,
		antialias = true,
	})
	local sw = ScrW()
	local sh = ScrH()
	local lp = LocalPlayer()
	local uiSize = 20
	local curtab = 0
	function dp_donate_pv.lightcol(color,mul)
		return Color(color.r*mul,color.g*mul,color.b*mul,color.a or 255)
	end
	local cardtgle = false
	function dp_donate_pv.showItemCard(inum)
		if cardtgle then chat.AddText(dp_donate_pv.prefix.."Закройте предыдущую вкладку с товаром!") return end
		cardtgle = true
		local itable = dp_donate_pv.items[inum]
		if not istable(itable) then return end

		local cfr = vgui.Create("DFrame")
		cfr:SetTitle("")
		cfr:SetSize(sw/5,sh/2)
		cfr:Center()	
		cfr:ShowCloseButton(false)		
		cfr:MakePopup()
		local padding = 30
		cfr.Paint = function(self,w,h)
			draw.RoundedBox(15,0,0,w,h,dp_donate_pv.colors[dp_donate_pv.theme]["outline"])
			draw.RoundedBox(15,dp_donate_pv.style["outline"],dp_donate_pv.style["outline"],w-dp_donate_pv.style["outline"]*2,h-dp_donate_pv.style["outline"]*2,dp_donate_pv.colors[dp_donate_pv.theme]["background"])
			draw.RoundedBox(10,dp_donate_pv.style["outline"],dp_donate_pv.style["outline"],w-dp_donate_pv.style["outline"]*2,25,dp_donate_pv.colors[dp_donate_pv.theme]["second"])
			draw.RoundedBox(10,padding/2,padding/2+25,w-padding,h-padding-25,dp_donate_pv.colors[dp_donate_pv.theme]["third"])
		end
		local fw = cfr:GetWide()
		local fh = cfr:GetTall()
		local dw = fw-padding
		local dh = fh-padding-25
		local dx = padding/2
		local dy = padding/2+25
		local b_close = vgui.Create("DButton",cfr)
		b_close:SetText("")
		b_close:SetPos(7,6)
		b_close:SetSize(uiSize,uiSize)
		b_close.Paint = function(self,w,h)
			if self:IsHovered() then
				draw.RoundedBox(40,0,0,w,h,Color(230,50,86))
				draw.SimpleText("X","dp.main",w/2,0,Color(92,92,92,200),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
			else
				draw.RoundedBox(40,0,0,w,h,Color(202,19,55))
			end
		end
		b_close.DoClick = function()
			cardtgle = false
			cfr:Close()
		end
		local b_max = vgui.Create("DPanel",cfr)
		b_max:SetText("")
		b_max:SetPos(7+uiSize*1.2,6)
		b_max:SetSize(uiSize,uiSize)
		b_max.Paint = function(self,w,h)
			draw.RoundedBox(40,0,0,w,h,Color(227,152,37))
		end
		local b_min = vgui.Create("DPanel",cfr)
		b_min:SetText("")
		b_min:SetPos(7+uiSize*2.4,6)
		b_min:SetSize(uiSize,uiSize)
		b_min.Paint = function(self,w,h)
			draw.RoundedBox(40,0,0,w,h,Color(32,159,34))
		end

		local itemname = vgui.Create("DButton",cfr)
		itemname:SetFont("dp.main")
		itemname:SetTextColor(dp_donate_pv.colors[dp_donate_pv.theme]["text"])
		itemname:SetText(itable["title"])
		itemname:SetSize(dw,25)
		itemname:SetPos(dx,dy)
		itemname.Paint = function(self,w,h)
			draw.RoundedBox(5,0,0,w,h,dp_donate_pv.colors[dp_donate_pv.theme]["second"])
		end
		itemname:SetMouseInputEnabled(false)

		local itemmat = "icon16/error.png"
		if isstring(itable["image"]) then
			itemmat = dp_donate_pv.downloadImage(itable["image"],string.sub(itable["image"],#itable["image"]-8,#itable["image"]))
		elseif isstring(dp_donate_pv.defaultImage) then
			itemmat = dp_donate_pv.downloadImage(dp_donate_pv.defaultImage,"default_donate.png")
		end

		local item_img = vgui.Create("DImage", cfr)
		item_img:SetPos(dx+10,dy+25+10)
		item_img:SetSize(100,100)		
		item_img:SetImage(itemmat)

		local itemprice = vgui.Create("DButton",cfr)
		itemprice:SetFont("dp.main")
		itemprice:SetTextColor(dp_donate_pv.colors[dp_donate_pv.theme]["text"])
		itemprice:SetText(itable["price"]..dp_donate_pv.currency)
		itemprice:SetSize(dw-130,25*3)
		itemprice:SetPos(dx+120,dy+35+27)
		itemprice.Paint = function(self,w,h)
			draw.RoundedBox(5,0,0,w,h,dp_donate_pv.colors[dp_donate_pv.theme]["background"])
		end
		itemprice:SetMouseInputEnabled(false)

		local itempricehdr = vgui.Create("DButton",cfr)
		itempricehdr:SetFont("dp.main")
		itempricehdr:SetTextColor(dp_donate_pv.colors[dp_donate_pv.theme]["text"])
		itempricehdr:SetText("Цена")
		itempricehdr:SetSize(dw-130,25)
		itempricehdr:SetPos(dx+120,dy+35)
		itempricehdr.Paint = function(self,w,h)
			draw.RoundedBox(5,0,0,w,h,dp_donate_pv.colors[dp_donate_pv.theme]["second"])
		end
		itempricehdr:SetMouseInputEnabled(false)

		local itemdesc = vgui.Create("RichText",cfr)
		itemdesc:SetSize(dw-20,25+dh/2.1)
		itemdesc:SetPos(dx+10,dy+145+50+25)
		itemdesc.Paint = function(self,w,h)
			draw.RoundedBox(5,0,0,w,h,dp_donate_pv.colors[dp_donate_pv.theme]["background"])
		end
		function itemdesc:PerformLayout()
			self:SetFontInternal("dp.main")
			self:SetFGColor(dp_donate_pv.colors[dp_donate_pv.theme]["text"])
		end

		local desc = "Купив этот предмет вы будете очень крутым"
		if isstring(itable["desc"]) then
			desc = itable["desc"]
		elseif isstring(dp_donate_pv.defaultDesc) then
			desc = dp_donate_pv.defaultDesc
		end
		itemdesc:SetText(desc)

		local itemdeschdr = vgui.Create("DButton",cfr)
		itemdeschdr:SetFont("dp.main")
		itemdeschdr:SetTextColor(dp_donate_pv.colors[dp_donate_pv.theme]["text"])
		itemdeschdr:SetText(dp_donate_pv.locales["description"])
		itemdeschdr:SetSize(dw-20,25)
		itemdeschdr:SetPos(dx+10,dy+145+50)
		itemdeschdr.Paint = function(self,w,h)
			draw.RoundedBox(5,0,0,w,h,dp_donate_pv.colors[dp_donate_pv.theme]["second"])
		end
		itemdeschdr:SetMouseInputEnabled(false)

		local itembuy = vgui.Create("DButton",cfr)
		itembuy:SetFont("dp.main")
		itembuy:SetTextColor(dp_donate_pv.colors[dp_donate_pv.theme]["text"])
		itembuy:SetText(dp_donate_pv.locales["buy"])
		itembuy:SetSize(dw-20,40)
		itembuy:SetPos(dx+10,dy+145)
		itembuy.Paint = function(self,w,h)
			if self:IsHovered() then
				draw.RoundedBox(5,0,0,w,h,dp_donate_pv.lightcol(dp_donate_pv.colors[dp_donate_pv.theme]["second"],1.2))
			else
				draw.RoundedBox(5,0,0,w,h,dp_donate_pv.colors[dp_donate_pv.theme]["second"])
			end
		end
		itembuy.DoClick = function()
			local lp = LocalPlayer()
			if isnumber(itable["max"]) and not table.IsEmpty(dp_donate_pv.getItems(lp)) and dp_donate_pv.getItemRep(lp,itable["id"]) >= itable["max"] then Derma_Message("Вы достигли лимита покупки этого предмета!") return end
			if dp_donate_pv.affordDonate(lp,itable["price"]) then
				net.Start("dp_buyitem")
				net.WriteInt(inum,32)
				net.SendToServer()
				Derma_Message("Вы успешно купили "..itable["title"].."!","Автодонат")
			else
				Derma_Query(
				    "Вам не хватает "..itable["price"]-dp_donate_pv.getMoney(lp)..dp_donate_pv.currency.."! Хотите пополнить счет?",
				    "Автодонат",
				    "Да",
				    function()
				    	Derma_StringRequest(
							"Автодонат", 
							"Введите сумму для пополнения. ВАЖНО: При пополнении не меняйте никакие данные!",
							tostring(itable["price"]),
							function(text)
								if tonumber(text) then
									net.Start("dp_refill")
							    	net.WriteInt(text,32)
							    	net.SendToServer()
							    else
							    	chat.AddText("Вы ввели некорректное число!")
							    end
							end,
							function(text) chat.AddText("Вы закрыли окно пополнения!") end
						)
				    end,
					"Нет",
					function() end
				)
			end
		end
	end

	local atoggle = false
	function dp_donate_pv.showAdminPanel()
		if not dp_donate_pv.admin_ranks[LocalPlayer():GetUserGroup()] then chat.AddText("Вы не админ!") return end
		if atoggle then return end
		atoggle = true
		local cmd_to_run = ""
		local afr = vgui.Create("DFrame")
		afr:SetTitle("")
		afr:SetSize(sw/5,sh/2)
		afr:Center()	
		afr:ShowCloseButton(false)		
		afr:MakePopup()
		afr.Paint = function(self,w,h)
			draw.RoundedBox(15,0,0,w,h,dp_donate_pv.colors[dp_donate_pv.theme]["outline"])
			draw.RoundedBox(15,dp_donate_pv.style["outline"],dp_donate_pv.style["outline"],w-dp_donate_pv.style["outline"]*2,h-dp_donate_pv.style["outline"]*2,dp_donate_pv.colors[dp_donate_pv.theme]["background"])
			draw.RoundedBox(10,dp_donate_pv.style["outline"],dp_donate_pv.style["outline"],w-dp_donate_pv.style["outline"]*2,25,dp_donate_pv.colors[dp_donate_pv.theme]["second"])
			draw.SimpleText(dp_donate_pv.locales["apanel"],"dp.main",w/2,3,dp_donate_pv.colors[dp_donate_pv.theme]["text"],TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
			draw.RoundedBox(10,5,30,w/3+6,h-35,dp_donate_pv.colors[dp_donate_pv.theme]["third"])
		end
		local fw = afr:GetWide()
		local fh = afr:GetTall()
		local b_close = vgui.Create("DButton",afr)
		b_close:SetText("")
		b_close:SetPos(7,6)
		b_close:SetSize(uiSize,uiSize)
		b_close.Paint = function(self,w,h)
			if self:IsHovered() then
				draw.RoundedBox(40,0,0,w,h,Color(230,50,86))
				draw.SimpleText("X","dp.main",w/2,0,Color(92,92,92,200),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
			else
				draw.RoundedBox(40,0,0,w,h,Color(202,19,55))
			end
		end
		b_close.DoClick = function()
			atoggle = false
			afr:Close()
		end
		local b_max = vgui.Create("DPanel",afr)
		b_max:SetText("")
		b_max:SetPos(7+uiSize*1.2,6)
		b_max:SetSize(uiSize,uiSize)
		b_max.Paint = function(self,w,h)
			draw.RoundedBox(40,0,0,w,h,Color(227,152,37))
		end
		local b_min = vgui.Create("DPanel",afr)
		b_min:SetText("")
		b_min:SetPos(7+uiSize*2.4,6)
		b_min:SetSize(uiSize,uiSize)
		b_min.Paint = function(self,w,h)
			draw.RoundedBox(40,0,0,w,h,Color(32,159,34))
		end

		local ascroll = vgui.Create("DScrollPanel",afr)
		ascroll:SetPos(fw/10+12,32)
		ascroll:SetSize(fw-(16+fw/3),fh-30-5)
		local acmdgrid = vgui.Create("DGrid", scroll)
		acmdgrid:SetPos(2,0)
		acmdgrid:SetCols(4)
		acmdgrid:SetColWide((fw-(36+fw/3))/4)
		acmdgrid:SetRowHeight(100)

		local atabs = vgui.Create("DScrollPanel",afr)
		atabs:SetPos(8,35)
		atabs:SetSize(fw/3,fh-30)

		local arg = vgui.Create("DTextEntry", afr)
		arg:SetPos(fw-ascroll:GetWide(),32)
		arg:SetSize(ascroll:GetWide()-10,28)
		arg:SetPlaceholderText(dp_donate_pv.locales["eval"])

		local plylst = vgui.Create("DListView", afr)
		plylst:SetPos(fw-ascroll:GetWide(),37+arg:GetTall())
		plylst:SetSize(ascroll:GetWide()-10,fh-(77+arg:GetTall()))
		plylst:SetMultiSelect(false)
		plylst:AddColumn(dp_donate_pv.locales["nickclm"])
		plylst:AddColumn(dp_donate_pv.locales["sidclm"])

		for z,v in ipairs(player.GetAll()) do
			plylst:AddLine(v:Nick(),v:SteamID())
		end

		local clck
		for i=1,#dp_donate_pv.acmd do
			local atab = atabs:Add("DButton")
			atab:SetFont("dp.min")
			atab:SetHeight(30)
			atab:SetTextColor(dp_donate_pv.colors[dp_donate_pv.theme]["text"])
			atab:SetText(dp_donate_pv.acmd[i]["label"])
			if isstring(dp_donate_pv.acmd[i]["tip"]) then
				atab:SetTooltip(dp_donate_pv.acmd[i]["tip"])
			end
			atab:Dock(TOP)
			atab:DockMargin(0,0,0,5)
			
			atab.Paint = function(self,w,h)
				if self:IsHovered() or clck==self then
					draw.RoundedBox(5,0,0,w,h,dp_donate_pv.lightcol(dp_donate_pv.colors[dp_donate_pv.theme]["second"],1.2))
				else
					draw.RoundedBox(5,0,0,w,h,dp_donate_pv.colors[dp_donate_pv.theme]["second"])
				end
			end
			atab.DoClick = function()
				cmd_to_run = dp_donate_pv.acmd[i]["cb_cmd"]
				dp_donate_pv.tabsreload(acmdgrid,fw,fh,true)
				clck = atab
			end
		end

		local exec = vgui.Create("DButton",afr) -- екзек обкак, не смотрите на название
		exec:SetFont("dp.main")
		exec:SetTextColor(dp_donate_pv.colors[dp_donate_pv.theme]["text"])
		exec:SetText(dp_donate_pv.locales["run"])
		exec:SetSize(ascroll:GetWide()-10,28)
		exec:SetPos(fw-ascroll:GetWide(),fh-exec:GetTall()-9)
		exec.Paint = function(self,w,h)
			if self:IsHovered() then
				draw.RoundedBox(5,0,0,w,h,dp_donate_pv.lightcol(dp_donate_pv.colors[dp_donate_pv.theme]["second"],1.2))
			else
				draw.RoundedBox(5,0,0,w,h,dp_donate_pv.colors[dp_donate_pv.theme]["second"])
			end
		end
		exec.DoClick = function()
			if not cmd_to_run or string.len(cmd_to_run) < 1 then chat.AddText("Вы не выбрали команду!") return end
			local ln,lpnl = plylst:GetSelectedLine()
			if not lpnl then chat.AddText("Вы не выбрали игрока!") return end
			local sid = lpnl:GetColumnText(2)
			if not player.GetBySteamID(sid) then chat.AddText("Игрок не на сервере!") return end

			local consid = util.SteamIDTo64(sid)

			if arg:GetValue() then
				RunConsoleCommand(cmd_to_run,consid,arg:GetValue())
			else
				RunConsoleCommand(cmd_to_run,consid)
			end
		end
	end

	function dp_donate_pv.menu()
		if IsValid(fr) then fr:Remove() end
		local fr = vgui.Create("DFrame")
		fr:SetTitle("")
		fr:SetSize(sw/2,sh/2)
		fr:Center()	
		fr:ShowCloseButton(false)		
		fr:MakePopup()
		fr.Paint = function(self,w,h)
			draw.RoundedBox(15,0,0,w,h,dp_donate_pv.colors[dp_donate_pv.theme]["outline"])
			draw.RoundedBox(15,dp_donate_pv.style["outline"],dp_donate_pv.style["outline"],w-dp_donate_pv.style["outline"]*2,h-dp_donate_pv.style["outline"]*2,dp_donate_pv.colors[dp_donate_pv.theme]["background"])
			draw.RoundedBox(10,dp_donate_pv.style["outline"],dp_donate_pv.style["outline"],w-dp_donate_pv.style["outline"]*2,25,dp_donate_pv.colors[dp_donate_pv.theme]["second"])
			draw.SimpleText(dp_donate_pv.locales["window"],"dp.main",w/2,3,dp_donate_pv.colors[dp_donate_pv.theme]["text"],TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
			draw.RoundedBox(10,5,30,w/10+6,h-35,dp_donate_pv.colors[dp_donate_pv.theme]["third"])
		end
		local fw = fr:GetWide()
		local fh = fr:GetTall()
		local b_close = vgui.Create("DButton",fr)
		b_close:SetText("")
		b_close:SetPos(7,6)
		b_close:SetSize(uiSize,uiSize)
		b_close.Paint = function(self,w,h)
			if self:IsHovered() then
				draw.RoundedBox(40,0,0,w,h,Color(230,50,86))
				draw.SimpleText("X","dp.main",w/2,0,Color(92,92,92,200),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
			else
				draw.RoundedBox(40,0,0,w,h,Color(202,19,55))
			end
		end
		b_close.DoClick = function()
			fr:Close()
		end
		local b_max = vgui.Create("DPanel",fr)
		b_max:SetText("")
		b_max:SetPos(7+uiSize*1.2,6)
		b_max:SetSize(uiSize,uiSize)
		b_max.Paint = function(self,w,h)
			draw.RoundedBox(40,0,0,w,h,Color(227,152,37))
		end
		local b_min = vgui.Create("DPanel",fr)
		b_min:SetText("")
		b_min:SetPos(7+uiSize*2.4,6)
		b_min:SetSize(uiSize,uiSize)
		b_min.Paint = function(self,w,h)
			draw.RoundedBox(40,0,0,w,h,Color(32,159,34))
		end

		local b_bal = vgui.Create("DButton",fr)
		b_bal:SetFont("dp.min")
		b_bal:SetTextColor(dp_donate_pv.colors[dp_donate_pv.theme]["text"])
		b_bal:SetText(dp_donate_pv.getMoney(lp)..dp_donate_pv.currency)
		b_bal:SetPos(fw-surface.GetTextSize(dp_donate_pv.getMoney(lp)..dp_donate_pv.currency)-20,6)
		b_bal:SetTooltip("Пополнить")
		b_bal.DoClick = function()
			Derma_StringRequest(
				"Автодонат", 
				"Введите сумму для пополнения. ВАЖНО: При пополнении не меняйте никакие данные!",
				tostring(dp_donate_pv.minsum),
				function(text)
					if tonumber(text) then
						net.Start("dp_refill")
						net.WriteInt(text,32)
						net.SendToServer()
					else
						chat.AddText("Вы ввели некорректное число!")
					end
				end,
				function(text) chat.AddText("Вы закрыли окно пополнения!") end
			)
		end

		b_bal:SizeToContents()
		b_bal.Paint = function(self,w,h)
			if self:IsHovered() then
				draw.RoundedBox(0,0,0,w,h,Color(54,201,62,200))
			end
		end

		local b_rel = vgui.Create("DButton",fr)
		b_rel:SetText("")
		b_rel:SetPos(b_bal:GetPos()-(10+uiSize),6)
		b_rel:SetSize(uiSize,uiSize)
		b_rel:SetTooltip("Перезагрузить")
		b_rel.Paint = function(self,w,h)
			surface.SetDrawColor(255,255,255)
			surface.SetMaterial(Material(dp_donate_pv.icons[dp_donate_pv.icostyle]["refresh"]))
			surface.DrawTexturedRect(0,0,w,h)
		end
		b_rel.DoClick = function()
			net.Start("dp_updatemoney")
			net.SendToServer()
			fr:Close()
			dp_donate_pv.menu()
		end

		local b_col = vgui.Create("DButton",fr)
		b_col:SetText("")
		b_col:SetPos(b_bal:GetPos()-(10+uiSize)*2,6)
		b_col:SetSize(uiSize,uiSize)
		b_col:SetTooltip("Выбрать тему")
		b_col.Paint = function(self,w,h)
			surface.SetDrawColor(255,255,255)
			surface.SetMaterial(Material(dp_donate_pv.icons[dp_donate_pv.icostyle]["theme"]))
			surface.DrawTexturedRect(0,0,w,h)
		end
		local coltbl = dp_donate_pv.colors
		b_col.DoClick = function()
			local theme = DermaMenu()
			local header = theme:AddOption(dp_donate_pv.locales["themes"])
			header:SetIcon("icon16/color_wheel.png")
			header:SetTextColor(dp_donate_pv.colors[dp_donate_pv.theme]["text"])
			header.OnMousePressed = function() end
			theme:AddSpacer()
		    for title, _ in pairs(dp_donate_pv.colors) do
		        theme:AddOption(title, function()
		            dp_donate_pv.theme = title
		            file.Write("dp_autodonate/theme.txt",title)

		        end):SetTextColor(dp_donate_pv.colors[dp_donate_pv.theme]["text"])
		    end
		    theme:AddSpacer()

		    local icoheader = theme:AddOption("Иконки")
			icoheader:SetIcon("icon16/status_online.png")
			icoheader:SetTextColor(dp_donate_pv.colors[dp_donate_pv.theme]["text"])
			icoheader.OnMousePressed = function() end
			theme:AddSpacer()

		    for title, _ in pairs(dp_donate_pv.icons) do
		        theme:AddOption(title, function()
		            dp_donate_pv.icostyle = title
		            file.Write("dp_autodonate/icostyle.txt",title)
		        end):SetTextColor(dp_donate_pv.colors[dp_donate_pv.theme]["text"])
		    end

		    theme:Open()
		    theme.Paint = function(self,w,h)
		    	draw.RoundedBox(5,0,0,w,h,dp_donate_pv.colors[dp_donate_pv.theme]["second"])
		   	end
		end

		if dp_donate_pv.admin_ranks[LocalPlayer():GetUserGroup()] then
			local b_admin = vgui.Create("DButton",fr)
			b_admin:SetText("")
			b_admin:SetPos(b_bal:GetPos()-(10+uiSize)*3,6)
			b_admin:SetSize(uiSize,uiSize)
			b_admin:SetTooltip("Админ-Панель")
			b_admin.Paint = function(self,w,h)
				surface.SetDrawColor(255,255,255)
				surface.SetMaterial(Material(dp_donate_pv.icons[dp_donate_pv.icostyle]["admin"]))
				surface.DrawTexturedRect(0,0,w,h)
			end
			b_admin.DoClick = function()
				dp_donate_pv.showAdminPanel()
			end
		end

		local scroll = vgui.Create("DScrollPanel",fr)
		scroll:SetPos(fw/10+12,32)
		scroll:SetSize(fw-(16+fw/10),fh-30-5)
		local listitems = vgui.Create("DGrid", scroll)
		listitems:SetPos(2,0)
		listitems:SetCols(4)
		listitems:SetColWide((fw-(36+fw/10))/4)
		listitems:SetRowHeight(100)

		local tabs = vgui.Create("DScrollPanel",fr)
		tabs:SetPos(8,35)
		tabs:SetSize(fw/10,fh-30)

		for i=1,#dp_donate_pv.tabs do
			local tab = tabs:Add("DButton")
			tab:SetFont("dp.min")
			tab:SetHeight(30)
			tab:SetTextColor(dp_donate_pv.colors[dp_donate_pv.theme]["text"])
			tab:SetText(dp_donate_pv.tabs[i])
			tab:Dock(TOP)
			tab:DockMargin(0,0,0,5)
			tab.Paint = function(self,w,h)
				if self:IsHovered() then
					draw.RoundedBox(5,0,0,w,h,dp_donate_pv.lightcol(dp_donate_pv.colors[dp_donate_pv.theme]["second"],1.2))
				else
					draw.RoundedBox(5,0,0,w,h,dp_donate_pv.colors[dp_donate_pv.theme]["second"])
				end
			end
			tab.DoClick = function()
				curtab = i
				dp_donate_pv.tabsreload(listitems,fw,fh)
			end
		end
	end

	function dp_donate_pv.tabsreload(list,fw,fh,remonly)
		remonly = remonly or false
		
		for z,v in ipairs(list:GetItems()) do
			v:Remove()
		end

		if remonly then return end

		for i = 1,#dp_donate_pv.items do
			if dp_donate_pv.items[i]["category"] == dp_donate_pv.tabs[curtab] then
				local card = vgui.Create("DPanel")
				card:SetSize((fw-(36+fw/10))/4-4,96)
				card.Paint = function(self,w,h)
					draw.RoundedBox(5,0,0,w,h,dp_donate_pv.colors[dp_donate_pv.theme]["third"])
				end
				local cw = (fw-(36+fw/10))/4-4
				local ch = 96
				local label = vgui.Create("DButton",card)
				label:SetFont("dp.main")
				label:SetTextColor(dp_donate_pv.colors[dp_donate_pv.theme]["text"])
				label:SetText(dp_donate_pv.items[i]["title"])
				label:SetSize(cw,30)
				label:SetPos(0,0)
				label.Paint = function(self,w,h)
				end
				label:SetMouseInputEnabled(false)
				--label:SetSize(cw,30)
				local price = vgui.Create("DButton",card)
				price:SetFont("dp.main")
				price:SetTextColor(dp_donate_pv.colors[dp_donate_pv.theme]["second"])
				price:SetText(dp_donate_pv.locales["price"]..dp_donate_pv.items[i]["price"]..dp_donate_pv.currency)
				price:SetSize(cw,30)
				price:SetPos(0,cw/6)
				price.Paint = function(self,w,h)
				end
				price:SetMouseInputEnabled(false)
				local showDesc = vgui.Create("DButton",card)
				showDesc:SetFont("dp.main")
				showDesc:SetTextColor(dp_donate_pv.colors[dp_donate_pv.theme]["text"])
				showDesc:SetText(dp_donate_pv.locales["buy"])
				showDesc:SetSize(cw,30)
				showDesc:SetPos(0,ch-30)
				showDesc.Paint = function(self,w,h)
					if self:IsHovered() then
						draw.RoundedBox(5,0,0,w,h,dp_donate_pv.lightcol(dp_donate_pv.colors[dp_donate_pv.theme]["second"],1.2))
					else
						draw.RoundedBox(5,0,0,w,h,dp_donate_pv.colors[dp_donate_pv.theme]["second"])
					end
				end
				showDesc.DoClick = function()
					dp_donate_pv.showItemCard(i)
				end

				list:AddItem(card)
			end
		end
	end

	hook.Add( "PlayerButtonDown", "dp_bind", function(ply, button)
		if IsFirstTimePredicted() && button == dp_donate_pv.bind then 
			dp_donate_pv.menu()
		end
	end)

	hook.Add( "OnPlayerChat", "dp_ccmd", function( ply, strText, bTeam, bDead ) 
	    if ply != LocalPlayer() then return end
		strText = string.lower(strText)
		if strText == dp_donate_pv.ccmd then
			dp_donate_pv.menu()
			return true
		end
	end)
end