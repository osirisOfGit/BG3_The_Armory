local Matcher = {}

-- Define the slot order in the outfit string: "Origin|Hireling|Race|Subrace|BodyType|Class|Subclass"
local SlotOrder = {
  "Origin",    -- 1
  "Hireling",  -- 2
  "Race",      -- 3
  "Subrace",   -- 4
  "BodyType",  -- 5
  "Class",     -- 6
  "Subclass"   -- 7
}

-- Assign a weight to each slot if we want to compute a 'score'.
-- (Origin/Hireling both worth 6, Race=5, Subrace=4, BodyType=3, Class=2, Subclass=1)
local SlotWeight = {
  Origin   = 6,
  Hireling = 6,
  Race     = 5,
  Subrace  = 4,
  BodyType = 3,
  Class    = 2,
  Subclass = 1
}

-- Split "Karlach||Tiefling|Zariel Tiefling|2|Barbarian|Berserker" into a table of 7 fields
local function parseKey(key)
  local fields = {}
  for val in string.gmatch(key, "([^|]*)") do
    fields[#fields + 1] = val
  end
  while #fields < 7 do
    fields[#fields + 1] = ""
  end
  return fields
end

-- Check if an outfit has the mandatory fields:
--  - either fields[1] (Origin) or fields[2] (Hireling) must be non-empty
--  - fields[3] (Race) must be non-empty
--  - fields[5] (BodyType) must be non-empty
--  - fields[6] (Class) must be non-empty
local function passesMandatoryChecks(fields)
  local hasOrigin = (fields[1] ~= "")
  local hasHireling = (fields[2] ~= "")
  if hasOrigin and hasHireling then
    return false  -- domain says can't have both at once
  end
  if (not hasOrigin) and (not hasHireling) then
    return false
  end
  if fields[3] == "" then
    return false
  end
  if fields[5] == "" then
    return false
  end
  if fields[6] == "" then
    return false
  end
  return true
end
-- Compute a score for a character vs a 7-field outfit.
-- If a slot is non-empty in the outfit, it must match exactly the character's field, else 0 => disqualify.
local function computeScore(char, fields)
  local total = 0
  for i = 1, 7 do
    local val = fields[i]
    if val ~= "" then
      local slot = SlotOrder[i]
      local cval = char[slot]
      if slot == "BodyType" and cval then
        cval = tostring(cval)
      end
      if cval == val then
        total = total + (SlotWeight[slot] or 0)
      else
        return 0
      end
    end
  end
  return total
end

-- Single-pass function that loops over all outfits in a dictionary,
-- finds the one that yields the highest score.
function Matcher.findBestMatch(char, outfits)
  local bestData = nil
  local bestKey = nil
  local highScore = -1

  for key, data in pairs(outfits) do
    local f = parseKey(key)
    if passesMandatoryChecks(f) then
      local score = computeScore(char, f)
      if score > highScore then
        highScore = score
        bestData = data
        bestKey = key
      end
    end
  end

  return bestData, bestKey, highScore
end

return Matcher
