-- globals
BONK = {
	debug = false,
}

SFX = {
	player_kill = {
		melee = "bonk.ogg",
		spell = "awp.ogg",
	},
}

local SFX_PATH = "Interface\\AddOns\\Bonk\\sfx\\"
local SFX_CHANNEL = "Master"

-- plays a sound effect
BONK.play = function(sound)
	if not sound then
		error("sound effect cant be nil", 1)
	end

	local path = SFX_PATH .. sound
	if not PlaySoundFile(path, SFX_CHANNEL) then
		error("sound effect does not exist: " .. path, 1)
	end
end

-- returns true if the guid is a player
local function guidIsPlayer(guid)
	local firstPart = strsplit("-", guid)
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

local function debugSpell(spellId)
	if not BONK.debug then
		return
	end

	local name, _, _, _, minRange, maxRange = GetSpellInfo(spellId)
	print(format("Bonk: %s (school: %d, minRange: %d, maxRange: %d)", name, spellSchool, minRange, maxRange))
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
	local killingBlow = overkill and overkill > 0
	if killingBlow then
		if isMelee(spellId, spellSchool) then
			BONK.play(SFX.player_kill.melee)
		else
			debugSpell(spellId)
			BONK.play(SFX.player_kill.spell)
		end
	end
end)

if BONK.debug then
	print("Bonk loaded in debug mode")
end
