-- teabagging module

local standing = true
local teabagCooldown = false

BONK.teabag = function()
	if teabagCooldown then
		return
	end

	print("teabag")
	teabagCooldown = true
	if standing then
		DoEmote("sit")
	else
		DoEmote("stand")
	end

	standing = not standing

	C_Timer.After(0.5, function()
		teabagCooldown = false
	end)
end
