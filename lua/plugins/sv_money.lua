hook.Add("dp_itemBought", "dp.money", function(ply,id)
	local itmt = dp_donate_pv.itableById(dp_donate_pv.items,id)

	if itmt != 0 and isnumber(dp_donate_pv.items[itmt]["drpmoney"]) then
		ply:addMoney(dp_donate_pv.items[itmt]["drpmoney"])
	end
end)