hook.Add("dp_itemBought", "dp.badmin", function(ply,id)
	local itmt = dp_donate_pv.itableById(dp_donate_pv.items,id)
	
	if itmt != 0 and isstring(dp_donate_pv.items[itmt]["barank"]) then
		if ply:GetRank() != dp_donate_pv.items[itmt]["barank"] then
			local rnk = ply:GetRank()
			if isnumber(dp_donate_pv.items[itmt]["expire"]) && dp_donate_pv.items[itmt]["expire"] > 0 then
				ba.data.SetRank(ply,dp_donate_pv.items[itmt]["barank"],rnk,dp_donate_pv.items[itmt]["expire"])
			else
				ba.data.SetRank(ply,dp_donate_pv.items[itmt]["barank"])
			end
		end
	end
end)