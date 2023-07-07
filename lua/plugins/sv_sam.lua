hook.Add("dp_itemBought", "dp.samadmin", function(ply,id)
	if dp_donate_pv.isExpired(ply,id) then return end -- Защита от перевыдачи ценной хуйни по типу админки на 30 дней или денег
	local itmt = dp_donate_pv.itableById(dp_donate_pv.items,id)
	
	if itmt != 0 and isstring(dp_donate_pv.items[itmt]["samrank"]) then
		if sam.player.get_rank(ply:SteamID()) != dp_donate_pv.items[itmt]["samrank"] then
			if isnumber(dp_donate_pv.items[itmt]["expire"]) && dp_donate_pv.items[itmt]["expire"] > 0 then
				sam.player.set_rank(ply,dp_donate_pv.items[itmt]["samrank"],dp_donate_pv.items[itmt]["expire"])
			else
				sam.player.set_rank(ply,dp_donate_pv.items[itmt]["samrank"])
			end
		end
	end
end)