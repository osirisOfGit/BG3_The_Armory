--[[
  Approach #1: Hardcoded Fallback
  We explicitly try each scenario in the order:
    1) Origin/Race/Subrace/BodyType/Class/Subclass
    2) Origin/Race/Subrace/BodyType
    3) Origin/Race/BodyType
    4) Origin/Race/Class/Subclass
    5) Origin/BodyType/Class
    6) Origin/Class
  Then we test 6 characters, each fulfilling exactly one scenario.
  Includes a simple profiler with os.clock().
]]

----------------------------------
-- Helper: buildKey
----------------------------------
local function buildKey(origin, hireling, race, subrace, bodytype, class, subclass)
    local o  = origin   or ""
    local hi = hireling or ""
    local r  = race     or ""
    local sr = subrace  or ""
    local bt = bodytype or ""
    local c  = class    or ""
    local sc = subclass or ""
    return table.concat({o, hi, r, sr, bt, c, sc}, "|")
end

----------------------------------
-- Hardcoded fallback function
----------------------------------
local function findOutfit_Hardcoded(character, outfits)
    -- Scenario #1
    do
        local k = buildKey(
            character.Origin,
            character.Hireling,
            character.Race,
            character.Subrace,
            character.BodyType and tostring(character.BodyType) or nil,
            character.Class,
            character.Subclass
        )
        if outfits[k] then return outfits[k], k end
    end

    -- Scenario #2
    do
        local k = buildKey(
            character.Origin,
            character.Hireling,
            character.Race,
            character.Subrace,
            character.BodyType and tostring(character.BodyType) or nil
        )
        if outfits[k] then return outfits[k], k end
    end

    -- Scenario #3
    do
        local k = buildKey(
            character.Origin,
            character.Hireling,
            character.Race,
            nil,
            character.BodyType and tostring(character.BodyType) or nil
        )
        if outfits[k] then return outfits[k], k end
    end

    -- Scenario #4
    do
        local k = buildKey(
            character.Origin,
            character.Hireling,
            character.Race,
            nil,
            nil,
            character.Class,
            character.Subclass
        )
        if outfits[k] then return outfits[k], k end
    end

    -- Scenario #5
    do
        local k = buildKey(
            character.Origin,
            character.Hireling,
            nil, -- Race
            nil, -- Subrace
            character.BodyType and tostring(character.BodyType) or nil,
            character.Class
        )
        if outfits[k] then return outfits[k], k end
    end

    -- Scenario #6
    do
        local k = buildKey(
            character.Origin,
            character.Hireling,
            nil, 
            nil,
            nil,
            character.Class
        )
        if outfits[k] then return outfits[k], k end
    end

    -- None matched
    return nil, nil
end

----------------------------------
-- Test Data
----------------------------------
-- We create 6 outfits (one for each scenario).
local outfits = {
    -- Scenario #1 key: Origin| |Race|Subrace|BodyType|Class|Subclass
    [buildKey("Karlach","","Tiefling","Zariel","2","Barbarian","Berserker")] = "S1_OriginRaceSubraceBodyClassSub",
    -- Scenario #2 key: Origin| |Race|Subrace|BodyType| | 
    [buildKey("Karlach","","Tiefling","Zariel","2","","")]                   = "S2_OriginRaceSubraceBody",
    -- Scenario #3 key: Origin| |Race| |BodyType| | 
    [buildKey("Karlach","","Tiefling","","2","","")]                         = "S3_OriginRaceBody",
    -- Scenario #4 key: Origin| |Race| | |Class|Subclass
    [buildKey("Karlach","","Tiefling","","","Barbarian","Berserker")]        = "S4_OriginRaceClassSub",
    -- Scenario #5 key: Origin| | | |BodyType|Class| 
    [buildKey("Karlach","","","","2","Barbarian","")]                        = "S5_OriginBodyClass",
    -- Scenario #6 key: Origin| | | | |Class| 
    [buildKey("Karlach","","","","","Barbarian","")]                         = "S6_OriginClass",
}

-- 6 Characters, each intended to match exactly one scenario
local characters = {
    -- Matches Scenario #1
    {
      name="Char1-S1",
      Origin="Karlach", Race="Tiefling", Subrace="Zariel", BodyType=2, Class="Barbarian", Subclass="Berserker"
    },
    -- Matches Scenario #2
    {
      name="Char2-S2",
      Origin="Karlach", Race="Tiefling", Subrace="Zariel", BodyType=2
      -- no Class, no Subclass
    },
    -- Matches Scenario #3
    {
      name="Char3-S3",
      Origin="Karlach", Race="Tiefling", BodyType=2
      -- no Subrace, no Class
    },
    -- Matches Scenario #4
    {
      name="Char4-S4",
      Origin="Karlach", Race="Tiefling", Class="Barbarian", Subclass="Berserker"
      -- no Subrace, no BodyType
    },
    -- Matches Scenario #5
    {
      name="Char5-S5",
      Origin="Karlach", BodyType=2, Class="Barbarian"
      -- no Race, no Subrace, no Subclass
    },
    -- Matches Scenario #6
    {
      name="Char6-S6",
      Origin="Karlach", Class="Barbarian"
      -- no Race, no Subrace, no BodyType, no Subclass
    },
}

----------------------------------
-- Demo usage + profiler
----------------------------------
local function main()
    for i, char in ipairs(characters) do
        local startTime = os.clock()
        local outfit, key = findOutfit_Hardcoded(char, outfits)
        local endTime = os.clock()
        print(
            string.format(
                "Hardcoded: %s -> Outfit: %s | Key: %s | Time: %.6f s",
                char.name, tostring(outfit), tostring(key), (endTime - startTime)
            )
        )
    end
end

main()