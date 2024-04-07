local function bonk()
	PlaySoundFile("Interface\\AddOns\\Bonk\\sfx\\bonk.ogg")
end

local function CombatLogEventHandler(self)
	local _, event, _, _, s_name, _, _, d_guid, d_name, _, _ = CombatLogGetCurrentEventInfo()
	if event ~= "PARTY_KILL" then
		return
	end

	local me = UnitName("player")
	if s_name ~= me then
		-- wasnt me
		return
	end

	local info = GetPlayerInfoByGUID(d_guid)
	if info == nil then
		-- wasnt a player
		return
	end

	bonk()
end

local EventFrame = CreateFrame("frame", "EventFrame")
EventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
EventFrame:SetScript("OnEvent", CombatLogEventHandler)
