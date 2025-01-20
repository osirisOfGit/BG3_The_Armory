OutfitMatcher = {}

-- Assign a weight to each slot if we want to compute a 'score'.
local SlotWeight = {
  Origin   = 15,
  Hireling = 15,
  Race     = 5,
  Subrace  = 4,
  BodyType = 3,
  Class    = 2,
  Subclass = 1
}

-- Compute a score for a character vs a 7-field outfit.
-- If a slot is non-empty in the outfit, it must match exactly the character's field, else 0 => disqualify.
local function computeScore(char, fields)
  local total = 0
  for i = 1, 7 do
    local val = fields[VanityCharacterCriteriaType[i]]
    if val ~= "" and val ~= nil then
      local slot = VanityCharacterCriteriaType[i]
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
---@param char {[VanityCharacterCriteriaType] : string}
---@param outfits {[VanityCriteriaCompositeKey] : VanityOutfit}
---@return VanityOutfit?, VanityCriteriaCompositeKey?, integer?
function OutfitMatcher.findBestMatch(char, outfits)
  local bestData = nil
  local bestKey = nil
  local highScore = -1

  for key, data in pairs(outfits) do
    local f = ParseCriteriaCompositeKey(key)
    local score = computeScore(char, f)
    if score ~= 0 and score > highScore then
      highScore = score
      bestData = data
      bestKey = key
    end
  end

  return bestData, bestKey, highScore
end
