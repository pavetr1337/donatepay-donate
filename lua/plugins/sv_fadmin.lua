hook.Add("dp_itemBought", "dp.fadmin", function(ply,id)
	local itmt = dp_donate_pv.itableById(dp_donate_pv.items,id)
	if itmt != 0 and isstring(dp_donate_pv.items[itmt]["farank"]) then
		if ply:GetUserGroup() != dp_donate_pv.items[itmt]["farank"] then
			RunConsoleCommand("fadmin","setaccess",ply:Nick(),dp_donate_pv.items[itmt]["farank"])
		end
	end
end)

-- А вот щас лютый приколдес, пишем крут экспайр для админок в которых нет временных рангов
hook.Add("PlayerSpawn", "dp.fadmin_expire", function(ply)
	for z,v in ipairs(dp_donate_pv.getItems(ply)) do
		local itmt = dp_donate_pv.itableById(dp_donate_pv.items,v[1])
		if itmt != 0 and isstring(dp_donate_pv.items[itmt]["farank"]) and dp_donate_pv.items[itmt]["farank"] and dp_donate_pv.isExpired(ply,v[1],dp_donate_pv.items[itmt]["expire"],os.time()) then
			if ply:GetUserGroup() == dp_donate_pv.items[itmt]["farank"] then
				RunConsoleCommand("fadmin","setaccess",ply:Nick(),"user")
			end
			dp_donate_pv.removeItem(ply,dp_donate_pv.items[itmt]["id"])
		end
	end
end)