-- globals
BONK = {
	debug = false,
}

SFX = {
	player_kill = {
		melee = "bonk.ogg",
		meleeCritical = "pipe.ogg",
		spell = "pew.ogg",
		spellCritical = "awp.ogg",
	},
	party_kill = "coin.ogg",
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
	if not spellId or spellId == -1 then
		print("Bonk: melee swing")
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

	-- we are only interested in events where the target is a player
	-- /!\ unless we are in debug mode
	if not (guidIsPlayer(destGUID) or BONK.debug) then
		return
	end

	-- play a sound when a party member kills an enemy
	if type == "PARTY_KILL" and (sourceName ~= UnitName("player") or BONK.debug) then
		BONK.play(SFX.party_kill)
	end

	-- we are only interested in events where the source is the local player
	if sourceName ~= UnitName("player") then
		return
	end

	-- look for damage events with overkill
	local overkill, critical, spellId, spellSchool = false, false, -1, 1
	if type == "SPELL_DAMAGE" then
		spellId, overkill, spellSchool, critical = event[12], event[16], event[17], event[21]
	end
	if type == "SWING_DAMAGE" then
		overkill, critical = event[13], event[21]
	end
	if type == "RANGE_DAMAGE" then
		spellId, overkill, critical = 5019, event[16], event[21]
	end

	-- overkill means the target was killed by this event
	local killingBlow = overkill and overkill > 0
	if killingBlow then
		debugSpell(spellId)
		if isMelee(spellId, spellSchool) then
			if critical then
				BONK.play(SFX.player_kill.meleeCritical)
			else
				BONK.play(SFX.player_kill.melee)
			end
		else
			if critical then
				BONK.play(SFX.player_kill.spellCritical)
			else
				BONK.play(SFX.player_kill.spell)
			end
		end
	end
end)

SLASH_BONK1 = "/bonk"
function SlashCmdList.BONK(msg, editbox) -- 4.
	BONK.debug = not BONK.debug
	print("Bonk debug mode: " .. tostring(BONK.debug))
end
