-- subset_weight.lua

--[[
  Approach #2: Subset + Weight
  We define a set of valid subsets (one for each scenario),
  define a weight function to prioritize them, then try each in descending order.

  We test 6 characters, each fulfilling exactly one scenario.
  Includes timing with os.clock().
]]

----------------------------------
-- Helpers
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

local function buildKeyFromSubset(char, subset)
    local order = {"Origin","Hireling","Race","Subrace","BodyType","Class","Subclass"}
    local vals = {}
    for _,slot in ipairs(order) do
        local included = false
        for _,s in ipairs(subset) do
            if s == slot then
                included = true
                break
            end
        end
        if included then
            local v = char[slot]
            if slot == "BodyType" and v then
                v = tostring(v)
            end
            table.insert(vals, v or "")
        else
            table.insert(vals, "")
        end
    end
    return table.concat(vals, "|")
end

----------------------------------
-- Weight function
----------------------------------
local function getWeight(fields)
    -- turn fields into a set
    local setF = {}
    for _,f in ipairs(fields) do setF[f] = true end

    -- scenario #1
    if setF["Origin"] and setF["Race"] and setF["Subrace"] and setF["BodyType"] and setF["Class"] and setF["Subclass"] then
       return 1000
    end
    -- scenario #2
    if setF["Origin"] and setF["Race"] and setF["Subrace"] and setF["BodyType"] then
       return 900
    end
    -- scenario #3
    if setF["Origin"] and setF["Race"] and setF["BodyType"] then
       return 800
    end
    -- scenario #4
    if setF["Origin"] and setF["Race"] and setF["Class"] and setF["Subclass"] then
       return 700
    end
    -- scenario #5
    if setF["Origin"] and setF["BodyType"] and setF["Class"] then
       return 600
    end
    -- scenario #6
    if setF["Origin"] and setF["Class"] then
       return 500
    end
    return 0
end

----------------------------------
-- Subset approach function
----------------------------------
local function findOutfit_SubsetPriority(character, outfits)
    -- Each scenario is one subset
    local validSubsets = {
        {"Origin","Race","Subrace","BodyType","Class","Subclass"},  -- #1
        {"Origin","Race","Subrace","BodyType"},                     -- #2
        {"Origin","Race","BodyType"},                               -- #3
        {"Origin","Race","Class","Subclass"},                       -- #4
        {"Origin","BodyType","Class"},                              -- #5
        {"Origin","Class"},                                         -- #6
    }

    -- sort by getWeight descending
    table.sort(validSubsets, function(a,b)
        return getWeight(a) > getWeight(b)
    end)

    -- check each subset
    for _,subset in ipairs(validSubsets) do
        local key = buildKeyFromSubset(character, subset)
        if outfits[key] then
            return outfits[key], key
        end
    end

    return nil, nil
end

----------------------------------
-- Test Data
----------------------------------
-- 6 outfits, each for one scenario
local outfits = {
    -- Scenario #1
    [buildKey("Karlach","","Tiefling","Zariel","2","Barbarian","Berserker")] = "S1_OriginRaceSubraceBodyClassSub",
    -- Scenario #2
    [buildKey("Karlach","","Tiefling","Zariel","2","","")]                   = "S2_OriginRaceSubraceBody",
    -- Scenario #3
    [buildKey("Karlach","","Tiefling","","2","","")]                         = "S3_OriginRaceBody",
    -- Scenario #4
    [buildKey("Karlach","","Tiefling","","","Barbarian","Berserker")]        = "S4_OriginRaceClassSub",
    -- Scenario #5
    [buildKey("Karlach","","","","2","Barbarian","")]                        = "S5_OriginBodyClass",
    -- Scenario #6
    [buildKey("Karlach","","","","","Barbarian","")]                         = "S6_OriginClass",
}

local characters = {
    {
      name="Char1-S1",
      Origin="Karlach", Race="Tiefling", Subrace="Zariel", BodyType=2, Class="Barbarian", Subclass="Berserker"
    },
    {
      name="Char2-S2",
      Origin="Karlach", Race="Tiefling", Subrace="Zariel", BodyType=2
    },
    {
      name="Char3-S3",
      Origin="Karlach", Race="Tiefling", BodyType=2
    },
    {
      name="Char4-S4",
      Origin="Karlach", Race="Tiefling", Class="Barbarian", Subclass="Berserker"
    },
    {
      name="Char5-S5",
      Origin="Karlach", BodyType=2, Class="Barbarian"
    },
    {
      name="Char6-S6",
      Origin="Karlach", Class="Barbarian"
    },
}

----------------------------------
-- Demo usage + profiler
----------------------------------
local function main()
    for i, char in ipairs(characters) do
        local startTime = os.clock()
        local outfit, key = findOutfit_SubsetPriority(char, outfits)
        local endTime = os.clock()
        print(
            string.format(
                "Subset+Weight: %s -> Outfit: %s | Key: %s | Time: %.6f s",
                char.name, tostring(outfit), tostring(key), (endTime - startTime)
            )
        )
    end
end

main()