hook.Add("PlayerLoadout","dp.gunplugin", function(ply) -- Выдача при спавне
	for z,v in ipairs(dp_donate_pv.getItems(ply)) do
		if not dp_donate_pv.isExpired(ply,v[1]) then
			local itmt = dp_donate_pv.itableById(dp_donate_pv.items,v[1])
			if itmt !=0 and isstring(dp_donate_pv.items[itmt]["weapon"]) then
				ply:Give(dp_donate_pv.items[itmt]["weapon"])
			end
		end
	end
end)

hook.Add("dp_itemBought", "dp.gungive", function(ply,id) -- Выдача при первой покупке
	local itmt = dp_donate_pv.itableById(dp_donate_pv.items,id)
	
	if itmt != 0 and isstring(dp_donate_pv.items[itmt]["weapon"]) then
		ply:Give(dp_donate_pv.items[itmt]["weapon"])
	end
end)