-- globals
BONK = {
	streak_kills = 0,
	recent_kills = 0,
}
SFX = {
	bonk = "bonk.ogg",
	coin = "coin.ogg",
	pew = "pew.ogg",
	pipe = "pipe.ogg",
	awp = "awp.ogg",
	death = "death.ogg",

	double_kill = "double_kill.ogg",
	multi_kill = "multi_kill.ogg",
	ultra_kill = "ultra_kill.ogg",
	monster_kill = "monster_kill.ogg",

	rampage = "rampage.ogg",
	unstoppable = "unstoppable.ogg",
	godlike = "godlike.ogg",
}

local DEFAULT_CONFIG = {
	debug = false,
	recent_timeout = 8,
	announce_delay = 0.3,

	player_kill = {
		melee = SFX.bonk,
		melee_crit = SFX.pipe,
		spell = SFX.pew,
		spell_crit = SFX.awp,
	},
	party_kill = SFX.coin,
	party_death = SFX.death,
	recent_kills = {
		[2] = SFX.double_kill,
		[3] = SFX.multi_kill,
		[4] = SFX.ultra_kill,
		[5] = SFX.monster_kill,
		[6] = SFX.monster_kill,
		[7] = SFX.monster_kill,
		[8] = SFX.monster_kill,
		[9] = SFX.monster_kill,
	},
	kill_streak = {
		[5] = SFX.rampage,
		[10] = SFX.unstoppable,
		[15] = SFX.godlike,
	},
}

local SFX_PATH = "Interface\\AddOns\\Bonk\\sfx\\"
local SFX_CHANNEL = "Master"

BONK.log = function(msg, ...)
	if not BONKC.debug then
		return
	end
	print("[Bonk] " .. format(msg, ...))
end

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

BONK.play_later = function(sound, delay)
	C_Timer.After(delay, function()
		BONK.play(sound)
	end)
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

	if BONK.meleeSpells[spellId] then
		return true
	end

	-- anything else is considered ranged
	return false
end

local function debugSpell(spellId)
	if not spellId or spellId == -1 then
		BONK.log("killing blow: melee swing")
		return
	end

	local name, _, _, _, minRange, maxRange = GetSpellInfo(spellId)
	BONK.log("killing blow: %s (spell: %d, school: %d, range: %d-%d)", name, spellId, spellSchool, minRange, maxRange)
end

local function onPartyKill(sourceName)
	if sourceName ~= UnitName("player") or BONKC.debug then
		-- play party sound
		BONK.log("party kill by %s", sourceName)
		BONK.play(BONKC.party_kill)
	end

	-- update kill streaks
	BONK.streak_kills = BONK.streak_kills + 1
	BONK.recent_kills = BONK.recent_kills + 1

	-- set up recent kill streak reset timer
	local reset_count = BONK.recent_kills
	C_Timer.After(BONKC.recent_timeout, function()
		if BONK.recent_kills == reset_count then
			BONK.log("recent kill streak reset from %d", BONK.recent_kills)
			BONK.recent_kills = 0
		end
	end)

	-- streak effects
	if BONKC.recent_kills[BONK.recent_kills] then
		BONK.log("recent kills: %d", BONK.recent_kills)
		BONK.play_later(BONKC.recent_kills[BONK.recent_kills], BONKC.announce_delay)
	elseif BONKC.kill_streak[BONK.streak_kills] then
		BONK.log("kill streak: %d", BONK.recent_kills)
		BONK.play_later(BONKC.kill_streak[BONK.streak_kills], BONKC.announce_delay)
	end
end

local function onZoneChanged()
	BONK.log("resetting kill streaks due to zone change")
	BONK.streak_kills = 0
	BONK.recent_kills = 0
end

local function onDamage(sourceName, overkill, critical, spellId, spellSchool)
	-- we are only interested in events where the source is the local player
	if sourceName ~= UnitName("player") then
		return
	end

	-- overkill means the target was killed by this event
	local killingBlow = overkill and overkill > 0
	if killingBlow then
		local melee = isMelee(spellId, spellSchool)

		debugSpell(spellId)
		if melee then
			if critical then
				BONK.play(BONKC.player_kill.melee_crit)
			else
				BONK.play(BONKC.player_kill.melee)
			end
		else
			if critical then
				BONK.play(BONKC.player_kill.spell_crit)
			else
				BONK.play(BONKC.player_kill.spell)
			end
		end
	end
end

local function onDeath(name)
	if name == UnitName("player") then
		BONK.log("you died")
		BONK.streak_kills = 0
		BONK.recent_kills = 0
	elseif UnitClass(name) then
		-- party death sound
		BONK.play(BONKC.party_death)
	end
end

local function onCombatLogEvent(event)
	local type, sourceName, destGUID, destName = event[2], event[5], event[8], event[9]

	-- we are only interested in events where the target is a player
	-- /!\ unless we are in debug mode
	if not (guidIsPlayer(destGUID) or BONKC.debug) then
		return
	end

	-- play a sound when a party member kills an enemy
	if type == "PARTY_KILL" then
		onPartyKill(sourceName)
	end

	-- monitor party deaths
	if type == "UNIT_DIED" then
		onDeath(destName)
	end

	-- look for damage events with overkill
	if type == "SPELL_DAMAGE" then
		local spellId, overkill, spellSchool, critical = event[12], event[16], event[17], event[21]
		onDamage(sourceName, overkill, critical, spellId, spellSchool)
	end
	if type == "SWING_DAMAGE" then
		local spellId, overkill, spellSchool, critical = -1, event[13], 1, event[18]
		onDamage(sourceName, overkill, critical, spellId, spellSchool)
	end
	if type == "RANGE_DAMAGE" then
		local spellId, overkill, spellSchool, critical = 5019, event[16], 1, event[21]
		onDamage(sourceName, overkill, critical, spellId, spellSchool)
	end
end

local function onAddonLoaded()
	-- todo: merge saved config with defaults
	BONKC = DEFAULT_CONFIG

	print("Bonk loaded. Debug mode: " .. tostring(BONKC.debug) .. ".")
end

local bonkFrame = CreateFrame("frame", "Bonk")
bonkFrame:RegisterEvent("ADDON_LOADED")
bonkFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
bonkFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
bonkFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local addonName = ...
		if addonName == "Bonk" then
			onAddonLoaded()
		end
	end
	if event == "ZONE_CHANGED_NEW_AREA" then
		onZoneChanged()
	end
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		onCombatLogEvent({ CombatLogGetCurrentEventInfo() })
	end
end)

SLASH_BONK1 = "/bonk"
function SlashCmdList.BONK(msg, editbox)
	BONKC.debug = not BONKC.debug
	print("Bonk debug mode: " .. tostring(BONKC.debug))
	print(msg)
	BONK.play(SFX.bonk)
end
