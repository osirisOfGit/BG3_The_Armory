-- bfs_approach.lua

--[[
  Approach #3: BFS
  We start with all fields that the character has, then systematically remove
  fields one at a time (with domain constraints: removing Race -> remove Subrace,
  removing Class -> remove Subclass). The first match we find is the largest subset.

  We test 6 characters, each matching exactly one scenario. Includes timing.
]]

----------------------------------
-- Helpers
----------------------------------
local function buildKey(origin, hireling, race, subrace, bodytype, class, subclass)
    local o  = origin or ""
    local hi = hireling or ""
    local r  = race or ""
    local sr = subrace or ""
    local bt = bodytype or ""
    local c  = class or ""
    local sc = subclass or ""
    return table.concat({ o, hi, r, sr, bt, c, sc }, "|")
end

local function buildKeyFromSubset(char, slots)
    local order = { "Origin", "Hireling", "Race", "Subrace", "BodyType", "Class", "Subclass" }
    local vals = {}
    for _, slot in ipairs(order) do
        local included = false
        for _, s in pairs(slots) do
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

local function getCharacterSlots(char)
    local order = { "Origin", "Hireling", "Race", "Subrace", "BodyType", "Class", "Subclass" }
    local slots = {}
    for _, slot in ipairs(order) do
        if char[slot] and char[slot] ~= "" then
            table.insert(slots, slot)
        end
    end
    return slots
end

----------------------------------
-- BFS with domain constraints
----------------------------------
local function findOutfit_BFS(character, outfits)
    local startSlots = getCharacterSlots(character)
    local queue = {}
    local front, back = 1, 1

    local visited = {}

    -- local function slotString(tbl)
    --     table.sort(tbl)
    --     return table.concat(tbl, ",")
    -- end

    local function enqueue(tbl)
        local s = buildKeyFromSubset(character, tbl)
        if not visited[s] then
            visited[s] = true
            queue[back] = tbl
            back = back + 1
        end
    end

    for slotIter = 1, 7 do
        enqueue(startSlots)

        while front < back do
            local currentSlots = queue[front]
            front = front + 1

            -- Check match
            local key = buildKeyFromSubset(character, currentSlots)
            if outfits[key] then
                -- found a match
                return outfits[key], key
            end

            -- no match, remove fields
            for i = 7, slotIter + 1, -1 do
                local slotToRemove = currentSlots[i]
                if slotToRemove then
                    local nextSet = {}
                    for j, sl in pairs(currentSlots) do
                        if j ~= i then
                            table.insert(nextSet, sl)
                        end
                    end

                    -- domain constraints
                    if slotToRemove == "Race" then
                        -- remove Subrace
                        local filtered = {}
                        for _, sl in pairs(nextSet) do
                            if sl ~= "Subrace" then
                                table.insert(filtered, sl)
                            end
                        end
                        nextSet = filtered
                    end
                    if slotToRemove == "Class" then
                        -- remove Subclass
                        local filtered = {}
                        for _, sl in pairs(nextSet) do
                            if sl ~= "Subclass" then
                                table.insert(filtered, sl)
                            end
                        end
                        nextSet = filtered
                    end

                    enqueue(nextSet)
                end
            end
        end

        queue = {}
        front, back = 1, 1
        startSlots[slotIter] = nil
    end

    return nil, nil
end

----------------------------------
-- Test Data
----------------------------------
local outfits = {
    -- Scenario #1
    [buildKey("Karlach", "", "Tiefling", "Zariel", "2", "Barbarian", "Berserker")] = "S1_OriginRaceSubraceBodyClassSub",
    -- Scenario #2
    [buildKey("Karlach", "", "Tiefling", "Zariel", "2", "", "")]                   = "S2_OriginRaceSubraceBody",
    -- Scenario #3
    [buildKey("Karlach", "", "Tiefling", "", "2", "", "")]                         = "S3_OriginRaceBody",
    -- Scenario #4
    [buildKey("", "", "Tiefling", "", "", "Barbarian", "Berserker")]               = "S4_OriginRaceClassSub",
    -- Scenario #5
    [buildKey("Karlach", "", "", "", "2", "Barbarian", "")]                        = "S5_OriginBodyClass",
    -- Scenario #6
    [buildKey("", "", "", "", "", "Barbarian", "")]                                = "S6_OriginClass",
    [buildKey("", "", "", "", "2", "Barbarian", "")]                                = "S7_OriginClass",
}

local characters = {
    {
        name = "Char1-S1",
        Origin = "Karlach",
        Race = "Tiefling",
        Subrace = "Zariel",
        BodyType = 2,
        Class = "Barbarian",
        Subclass = "Berserker"
    }
}

----------------------------------
-- Demo usage + profiler
----------------------------------
local function main()
    for outfitKey, outfit in TableUtils:OrderedPairs(outfits, function (key)
        return outfits[key]
    end) do
        local foundOutfit, key = findOutfit_BFS(characters[1], outfits)
        print(
            string.format(
                "BFS: Outfit: %s | Key: %s",
                tostring(foundOutfit), tostring(key)
            )
        )
        outfits[outfitKey] = nil
    end
    
end

main()
