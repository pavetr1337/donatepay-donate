local logtypes = {
	[1] = Color(255,255,255), -- Info
	[2] = Color(59,219,83), -- Success
	[3] = Color(209,170,40), -- Warning
	[4] = Color(194,48,48), -- Error

	[5] = Color(3,169,244), -- SV
	[6] = Color(222,169,9), -- CL
	[7] = Color(113,169,127), -- SH
}

dp_donate_pv = dp_donate_pv or {}

function dp_donate_pv.log(msg,ltype)
	MsgC(Color(67,167,78), dp_donate_pv.prefix or "[DonatePay] ",IsColor(logtypes[ltype]) and logtypes[ltype] or color_white,msg.."\n")
end

local function AddFile( File, directory )
	local prefix = string.lower( string.Left( File, 3 ) )
	if SERVER and prefix == "sv_" then
		include( directory .. File )
		dp_donate_pv.log("SV include: "..File,5)
	elseif prefix == "sh_" then
		if SERVER then
			AddCSLuaFile( directory .. File )
			dp_donate_pv.log("SH addcs: "..File,7)
		end
		include( directory .. File )
		dp_donate_pv.log("SH include: "..File,7)
	elseif prefix == "cl_" then
		if SERVER then
			AddCSLuaFile( directory .. File )
			dp_donate_pv.log("CL addcs: "..File,6)
		elseif CLIENT then
			include( directory .. File )
			dp_donate_pv.log("CL include: "..File,6)
		end
	end
end
local function IncludeDir( directory )
	directory = directory .. "/"
	local files, directories = file.Find( directory .. "*", "LUA" )
	for _, v in ipairs( files ) do
		if string.EndsWith( v, ".lua" ) then
			AddFile( v, directory )
		end
	end
	for _, v in ipairs( directories ) do
		dp_donate_pv.log("Dir loaded: "..v,1)
		IncludeDir( directory .. v )
	end
end

IncludeDir("config")
local loadad = false
hook.Add("Think","dp.obkakhttp",function()
	if loadad then hook.Remove("Think","dp.obkakhttp") return end -- Из-за того что хттп грузится под конец запуска приходится юзать костыли
	IncludeDir("autodonate")
	loadad = true
end)

IncludeDir("plugins")

dp_donate_pv.log("DonatePay Autodonate",1)
dp_donate_pv.log("by Pavetr",1)
dp_donate_pv.log("pavetr.ru/ds",3)