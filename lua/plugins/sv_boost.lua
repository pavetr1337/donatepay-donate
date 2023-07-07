hook.Add("PlayerLoadout","dp.boost", function(ply) -- Выдача при спавне
	for z,v in ipairs(dp_donate_pv.getItems(ply)) do
		if not dp_donate_pv.isExpired(ply,v[1]) then
			local itmt = dp_donate_pv.itableById(dp_donate_pv.items,v[1])
			if itmt !=0 then
				if isnumber(dp_donate_pv.items[itmt]["hpboost"]) then
					ply:SetHealth(ply:Health()+dp_donate_pv.items[itmt]["hpboost"])
				elseif isnumber(dp_donate_pv.items[itmt]["arboost"]) then
					ply:SetArmor(ply:Armor()+dp_donate_pv.items[itmt]["arboost"])
				end
			end
		end
	end
end)