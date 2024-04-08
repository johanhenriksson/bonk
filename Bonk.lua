-- them sounds
local sounds = {
    PLAYER_KILL = {
        spellCrit = "Interface\\AddOns\\Bonk\\sfx\\awp.ogg",
        normal = "Interface\\AddOns\\Bonk\\sfx\\bonk.ogg"
    },
}

local function playSound(soundFilePath)
    if soundFilePath then
        PlaySoundFile(soundFilePath)
    end
end

function eventDestinationIsAnotherPlayer(destGUID)
    local firstPart = strsplit("-", destGUID)[1]
    return firstPart == "Player"
end

function isPartyKill(event)
    return event == "PARTY_KILL"
end

function isRangedSpellDamage(spellId)
    local _, _, spellSchool = GetSpellInfo(spellId)

    -- Spell schools: 1 = Physical, 2 = Holy, 4 = Fire, 8 = Nature, 16 = Frost, 32 = Shadow, 64 = Arcane
    -- Combining spell schools indicates a multi-school spell. For simplicity, this example checks for pure schools.
    -- Note: This is a simplified approach and might not accurately classify all ranged damage correctly.
    local rangedSchools = {
        [4] = true,  -- Fire
        [8] = true,  -- Nature
        [16] = true, -- Frost
        [32] = true, -- Shadow
        [64] = true, -- Arcane
    }

    return rangedSchools[spellSchool] or false
end


local function CombatLogEventHandler(self)
    local _, event, _, _, s_name, _, _, destGUID, _, _, _, spellId, _, _, _, overkill, _, _, _, _, critical = CombatLogGetCurrentEventInfo()
    
    -- if not me, return
    if s_name ~= UnitName("player") then return end
    
    
    if isPartyKill(event) and eventDestinationIsAnotherPlayer(destGUID) then
        local soundToPlay = sounds.PLAYER_KILL.normal
        
        if critical and (overkill and overkill > 0) and isRangedSpellDamage(spellId) then
            soundToPlay = sounds.PLAYER_KILL.spellCrit
        end

        playSound(soundToPlay)
    end

end

local EventFrame = CreateFrame("frame", "EventFrame")
EventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
EventFrame:SetScript("OnEvent", CombatLogEventHandler)