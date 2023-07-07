-- Web Functions
function dp_donate_pv.checkVer()
	http.Fetch("https://pastebin.com/raw/TZHqkDda",
	function( body, length, headers, code )
		if dp_donate_pv.ver != body then
			dp_donate_pv.log("Ваша версия устарела! Скачайте новую на github.com/pavetr1337/dpay-autodonate/tree/main",4)
		else
			dp_donate_pv.log("Addon v."..dp_donate_pv.ver,1)
		end
	end,
	function(message)
		dp_donate_pv.log("Version Fetch Error: "..message,4)
	end
	)
end

local lastTrans = ""
function dp_donate_pv.loadTransactions(amount)
	http.Fetch("https://donatepay.ru/api/v1/transactions?access_token="..dp_donate_pv.access_token.."&limit="..tostring(amount).."&status=success&type=donation",
	function( body, length, headers, code )
		lastTrans = body
		if string.find(body,'Too Many Requests') then
			lastTrans = 429
		end
	end,
	function(message)
		dp_donate_pv.log("HTTP Fetch Error: "..message,4)
	end
	)
end

function dp_donate_pv.checkPayment(ply,transtable)
	local retsum = false
	if istable(transtable) and istable(transtable["data"]) then
		for z,trans in ipairs(transtable["data"]) do
			if ply:GetNWString("dp_order") == trans["comment"] and ply:SteamID64() == trans["what"] and ply:GetNWInt("dp_ordersum") == tonumber(trans["sum"]) and (dp_donate_pv.billingExpire==0 or CurTime()-ply:GetNWInt("dp_ordertime") >= dp_donate_pv.billingExpire) and trans["currency"] == dp_donate_pv.paycurrency then
				ply:SetNWString("dp_order","")
				ply:SetNWInt("dp_ordersum",0)
				ply:SetNWInt("dp_ordertime",0)
				retsum = tonumber(trans["sum"])
			end
		end
	end
	return retsum
end

timer.Create("dp_askpayment",dp_donate_pv.refreshRate,0, function()
	dp_donate_pv.loadTransactions(dp_donate_pv.transToLoad)
	local transtable = util.JSONToTable(lastTrans)
	for z,ply in ipairs(player.GetAll()) do
		local validSum = dp_donate_pv.checkPayment(ply,transtable)
		if validSum then
			dp_donate_pv.addMoney(ply,validSum)
			ply:ChatPrint("Вам начислено "..tostring(validSum or 0)..dp_donate_pv.currency.." на донат-счет!")
		end
	end
end)

-- SQL & File Functions
function dp_donate_pv.initMainTable()
	sql.Query( "CREATE TABLE IF NOT EXISTS donatepay_main (sid64 INTEGER, balance INTEGER )" )
end


local dir = "dppv/"
function dp_donate_pv.makefile(sid)
	return dir..sid..".txt"
end

function dp_donate_pv.initItemsData()
	if not file.IsDir(dir,"DATA") then
		file.CreateDir(dir)
	end
end

function dp_donate_pv.validatePlayer(ply)
	if not ply:SteamID64() then return end
	local data = sql.Query( "SELECT * FROM donatepay_main WHERE sid64 = " .. sql.SQLStr( ply:SteamID64() ) .. ";")
	local datait = file.Read(dp_donate_pv.makefile(ply:SteamID64()),"DATA")
	if not data then
		sql.Query("INSERT INTO donatepay_main ( sid64, balance ) VALUES( " .. sql.SQLStr( ply:SteamID64() ) .. ", 0 )")
	end
	if not datait then
		file.Write(dp_donate_pv.makefile(ply:SteamID64()),"")
	end
end

-- Balance Functions
function dp_donate_pv.setMoney(ply,balance)
	dp_donate_pv.validatePlayer(ply)
	local data = sql.Query( "SELECT * FROM donatepay_main WHERE sid64 = " .. sql.SQLStr( ply:SteamID64() ) .. ";")
	if data then
		sql.Query( "UPDATE donatepay_main SET balance = " .. sql.SQLStr(balance) .. " WHERE sid64 = " .. sql.SQLStr( ply:SteamID64() ) .. ";" )
	else
		dp_donate_pv.log("SQL Error: Player validation failed",4)
	end
end

function dp_donate_pv.addMoney(ply,moneyToAdd)
	dp_donate_pv.setMoney(ply,dp_donate_pv.getMoney(ply)+moneyToAdd)
end

-- Items Functions
function dp_donate_pv.setItems(ply,itemsTable)
	dp_donate_pv.validatePlayer(ply)
	local data = file.Read(dp_donate_pv.makefile(ply:SteamID64()),"DATA")
	if data then
		file.Write(dp_donate_pv.makefile(ply:SteamID64()),util.TableToJSON(itemsTable))
	else
		dp_donate_pv.log("File Error: Player validation failed",4)
	end
end

function dp_donate_pv.addItem(ply,item) -- С версии 1.3 предметы не таблицей! "item"
	local items = dp_donate_pv.getItems(ply)
	dp_donate_pv.setItems(ply,table.Add(items,{{item,os.time()}})) --table[key][1] - айди, table[key][2] без единички - время покупки
end

function dp_donate_pv.removeItem(ply,item)
	local items = dp_donate_pv.getItems(ply)
	local itmsToGive = {}
	for z,itbl in ipairs(items) do
		if itbl[1] != item then
			table.insert(itmsToGive,itbl[1])
		end
	end
	dp_donate_pv.setItems(ply,{})
	for z,id in ipairs(itmsToGive) do
		dp_donate_pv.addItem(ply,id)
		hook.Run("dp_itemBought",ply,id)
	end
end

function dp_donate_pv.reGiveItems(ply)
	local items = dp_donate_pv.getItems(ply)
	local itmsToGive = {}
	for z,itbl in ipairs(items) do
		table.insert(itmsToGive,itbl[1])
	end
	dp_donate_pv.setItems(ply,{})
	for z,id in ipairs(itmsToGive) do
		dp_donate_pv.addItem(ply,id)
		hook.Run("dp_itemBought",ply,id)
	end
end

-- Init
hook.Add("PostGamemodeLoaded","dp_init", function()
	dp_donate_pv.initMainTable()
	dp_donate_pv.initItemsData()
end)
dp_donate_pv.checkVer()

-- Admin Commands
concommand.Add("dp_addmoney", function(ply,cmd,args)
	if not dp_donate_pv.admin_ranks[ply:GetUserGroup()] then return end
	local sid = args[1]
	local val = args[2]
	local targPl = player.GetBySteamID64(sid)
	if not targPl then ply:ChatPrint("Игрока не существует!") return end
	dp_donate_pv.addMoney(targPl,tonumber(val))
	ply:ChatPrint("Вы выдали "..targPl:Nick().." "..val..dp_donate_pv.currency)
end)

concommand.Add("dp_setmoney", function(ply,cmd,args)
	if not dp_donate_pv.admin_ranks[ply:GetUserGroup()] then return end
	local sid = args[1]
	local val = args[2]
	local targPl = player.GetBySteamID64(sid)
	if not targPl then ply:ChatPrint("Игрока не существует!") return end
	dp_donate_pv.setMoney(targPl,tonumber(val))
	ply:ChatPrint("Вы установили баланс "..targPl:Nick().." на "..val..dp_donate_pv.currency)
end)

concommand.Add("dp_additem", function(ply,cmd,args)
	if not dp_donate_pv.admin_ranks[ply:GetUserGroup()] then return end
	local sid = args[1]
	local val = args[2]
	local targPl = player.GetBySteamID64(sid)
	if not targPl then ply:ChatPrint("Игрока не существует!") return end
	dp_donate_pv.addItem(targPl,val)
	ply:ChatPrint("Вы выдали "..val.." игроку "..targPl:Nick())
end)

concommand.Add("dp_setitems", function(ply,cmd,args)
	if not dp_donate_pv.admin_ranks[ply:GetUserGroup()] then return end
	local sid = args[1]
	local val = args[2]
	local targPl = player.GetBySteamID64(sid)
	if not targPl then ply:ChatPrint("Игрока не существует!") return end
	dp_donate_pv.setItems(targPl,util.JSONToTable(val))
	ply:ChatPrint("Вы сетнули предметы на "..val.." игроку "..targPl:Nick())
end)

concommand.Add("dp_nullitems", function(ply,cmd,args)
	if not dp_donate_pv.admin_ranks[ply:GetUserGroup()] then return end
	local sid = args[1]
	local targPl = player.GetBySteamID64(sid)
	if not targPl then ply:ChatPrint("Игрока не существует!") return end
	dp_donate_pv.setItems(targPl,{})
	ply:ChatPrint("Вы обнулили предметы игроку "..targPl:Nick())
end)

concommand.Add("dp_regive", function(ply,cmd,args)
	if not dp_donate_pv.admin_ranks[ply:GetUserGroup()] then return end
	local sid = args[1]
	local targPl = player.GetBySteamID64(sid)
	if not targPl then ply:ChatPrint("Игрока не существует!") return end
	dp_donate_pv.reGiveItems(targPl)
	ply:ChatPrint("Вы перевыдали предметы игроку "..targPl:Nick())
end)

concommand.Add("dp_getitems", function(ply,cmd,args)
	if not dp_donate_pv.admin_ranks[ply:GetUserGroup()] then return end
	local sid = args[1]
	local targPl = player.GetBySteamID64(sid)
	if not targPl then ply:ChatPrint("Игрока не существует!") return end
	ply:ChatPrint("Предметы игрока "..targPl:Nick().." выведены в консоль!")
	ply:SendLua("PrintTable(dp_donate_pv.getItems(player.GetBySteamID64('"..sid.."')))")
end)

concommand.Add("dp_getmoney", function(ply,cmd,args)
	if not dp_donate_pv.admin_ranks[ply:GetUserGroup()] then return end
	local sid = args[1]
	local targPl = player.GetBySteamID64(sid)
	if not targPl then ply:ChatPrint("Игрока не существует!") return end
	ply:ChatPrint("Баланс игрока "..targPl:Nick()..": "..dp_donate_pv.getMoney(ply)..dp_donate_pv.currency)
end)

-- Debug Commands
if dp_donate_pv.debugMode then
	concommand.Add("dp_trans", function(ply)
		dp_donate_pv.loadTransactions(1)
		print(lastTrans)
	end)

	concommand.Add("dp_getmoney", function(ply)
		ply:ChatPrint(tostring(dp_donate_pv.getMoney(ply)))
	end)

	concommand.Add("dp_addmoney", function(ply)
		dp_donate_pv.addMoney(ply,50)
		ply:ChatPrint(tostring(dp_donate_pv.getMoney(ply)))
	end)

	concommand.Add("dp_resetmoney", function(ply)
		dp_donate_pv.setMoney(ply,0)
		ply:ChatPrint(tostring(dp_donate_pv.getMoney(ply)))
	end)

	concommand.Add("dp_setitems", function(ply)
		dp_donate_pv.setItems(ply,{"aboba","testitem"})
	end)

	concommand.Add("dp_additem", function(ply)
		dp_donate_pv.addItem(ply,"weapon_pavetr")
	end)

	concommand.Add("dp_resetitems", function(ply)
		dp_donate_pv.setItems(ply,{})
	end)

	concommand.Add("dp_getitems", function(ply)
		ply:ChatPrint(util.TableToJSON(dp_donate_pv.getItems(ply)))
	end)
end