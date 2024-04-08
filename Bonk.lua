-- globals
BONK = {
	debug = false,
}

local SFX_PATH = "Interface\\AddOns\\Bonk\\sfx\\"
local SFX_CHANNEL = "Master"

local SFX = {
	player_kill = {
		melee = "bonk.ogg",
		spell = "awp.ogg",
	},
}

-- plays a sound effect
local function playSfx(sound)
	if not sound then
		return
	end

	PlaySoundFile(SFX_PATH .. sound, SFX_CHANNEL)
end

-- returns true if the guid is a player
local function guidIsPlayer(guid)
	local firstPart = strsplit("-", guid)[1]
	return firstPart == "Player"
end

-- returns true if the spell is a melee spell
-- this is a rough approximation based on the spell's school and max range
local function isMelee(spellId, spellSchool)
	-- if the spell is not found, we assume it is a melee swing
	if not spellId or spellId == -1 then
		return true
	end

	local _, _, _, _, minRange, maxRange = GetSpellInfo(spellId)

	-- anything with a minimum range is obviously ranged
	if minRange > 0 then
		return false
	end

	-- physical damage with short range is considered melee
	local physical = spellSchool == 1
	if physical and maxRange <= 8 then
		return true
	end

	-- anything else is considered ranged
	return false
end

local function handlePlayerKill(spellId, spellSchool)
	if BONK.debug then
		local name, _, _, _, minRange, maxRange = GetSpellInfo(spellId)
		print(string.format("Bonk: %s (school: %d, minRange: %d, maxRange: %d)", name, spellSchool, minRange, maxRange))
	end

	if isMelee(spellId, spellSchool) then
		playSfx(SFX.player_kill.melee)
	else
		playSfx(SFX.player_kill.spell)
	end
end

local eventFrame = CreateFrame("frame", "Bonk")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:SetScript("OnEvent", function(self)
	local event = { CombatLogGetCurrentEventInfo() }
	local type, sourceName, destGUID = event[2], event[5], event[8]

	-- we are only interested in events where the source is the local player
	if sourceName ~= UnitName("player") then
		return
	end

	-- we are only interested in events where the target is a player
	-- /!\ unless we are in debug mode
	if not (guidIsPlayer(destGUID) or BONK.debug) then
		return
	end

	-- look for damage events with overkill
	local overkill, spellId, spellSchool = false, -1, 1
	if type == "SPELL_DAMAGE" then
		spellId, overkill, spellSchool = event[12], event[16], event[17]
	end
	if type == "SWING_DAMAGE" then
		overkill = event[13]
	end

	-- overkill means the target was killed by this event
	if overkill and overkill > 0 then
		handlePlayerKill(spellId, spellSchool)
	end
end)

if BONK.debug then
	print("Bonk loaded in debug mode")
end
