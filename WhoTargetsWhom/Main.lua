-- Goals:
-- 1. Detect if player is in an arena. 
-- 2. Do this by listening for ARENA_OPPONENT_UPDATE. 
-- 3. When we find it, determine arena size.
-- 4. Create up to three transparent clickthrough stripe textures horizontall across the party frames, they'll use the same width as their party frame, and a height of 5px.
---- 4a. These should be stacked on top of eachother, with arena2 vertically centered, arena1 just above it, and arena3 just below it. 
-- 5. As we find enemy classes, create a mapping between arena# -> class color.
---- 5b. Assign those colors to their corresponding stripes on all party members, but keep the stripes hidden for now. 
-- 6. Scan for arena# targets every .5s. 
---- 6a. If they aren't targeting any of our party members, then their correspondng stripe textures should remain invisible.
---- 6b. If arena1 is targeting party1, then party1's arena1 stripe should be revealed and party2 and party3's arena1 stripes should be hidden.
---- 6c. If arena1 is not targeting party1, party2, or party3, then all of arena1's stripes should be hidden.
---- 6d. The same is true for arena2, and arena3, accordingly.
-- 7. If arena# is dead, their stripes should be hidden.
-- 8. If multiple arena# units are targeting a single party# unit, then the arena# stripes associated with those units should be visible.


local interval = 1 -- Time in seconds between checks

local classColors = {
    ["Death Knight"] = {0.77, 0.12, 0.23},
    ["Demon Hunter"] = {0.64, 0.19, 0.79},
    ["Druid"] = {1.00, 0.49, 0.04},
    ["Evoker"] = {0.20, 0.58, 0.50},
    ["Hunter"] = {0.67, 0.83, 0.45},
    ["Mage"] = {0.25, 0.78, 0.92},
    ["Monk"] = {0.00, 1.00, 0.60},
    ["Paladin"] = {0.96, 0.55, 0.73},
    ["Priest"] = {1.00, 1.00, 1.00},
    ["Rogue"] = {1.00, 0.96, 0.41},
    ["Shaman"] = {0.00, 0.44, 0.87},
    ["Warlock"] = {0.53, 0.53, 0.93},
    ["Warrior"] = {0.78, 0.61, 0.43}
}
-- local lastTargetedByArena = {}

local media = LibStub("LibSharedMedia-3.0")
local frame = CreateFrame("Frame")
local cpf = _G["CompactPartyFrame"]
local partyFrames = cpf["memberUnitFrames"]
local width = cpf:GetWidth()
local maxArenaIndex = 3 -- Default to 3v3, will adjust after 45 seconds
local party = {
   {},
   {},
   {}
}

local function CreateStripeTextures()
--    print("CreateStripeTextures")
   for i = 1, 3 do
      local partyFrame = cpf.memberUnitFrames[i]
      for j = 1, maxArenaIndex do
        if not party[i][j] then -- Don't re-create textures we've already made.
            party[i][j] = partyFrame:CreateTexture("party"..i.."arena"..j.."stripe", "OVERLAY")
            party[i][j]:SetTexture("Interface\\AddOns\\Quartz\\textures\\Minimalist")
            party[i][j]:SetWidth(width)
            party[i][j]:SetHeight(5)
            if j == 1 then
                party[i][j]:SetPoint("CENTER", partyFrame, "CENTER", 0, 5)
            elseif j == 2 then
                party[i][j]:SetPoint("CENTER", partyFrame, "CENTER", 0, 0)
            else
                party[i][j]:SetPoint("CENTER", partyFrame, "CENTER", 0, -5)
            end
        end
      end
   end
end

-- Update the texture color based on the class targeting the party member
local function UpdateStripeColor(class, partyN, arenaN)
    local color = classColors[class]
    local targeted = party[partyN][arenaN]

    targeted:Show()
    targeted:SetColorTexture(unpack(color))

    -- hide the stripes for party members who aren't being targeted.
    if arenaN == 1 then
        party[partyN][2]:Hide()
        party[partyN][3]:Hide()
    elseif arenaN == 2 then
        party[partyN][1]:Hide()
        party[partyN][3]:Hide()
    elseif arenaN == 3 then
        party[partyN][1]:Hide()
        party[partyN][2]:Hide()
    end
end

local function UpdateArenaTargets()
    for i = 1, maxArenaIndex do
        local arenaUnit = "arena" .. i
        if UnitExists(arenaUnit) then
            local target = UnitName(arenaUnit.."target")
            if target then
                -- lastTargetedByArena[arenaUnit] = target
                for j = 1, GetNumGroupMembers() do
                    local partyUnit = "raid" .. j
                    if UnitIsUnit(partyUnit, target) then
                        local class = UnitClass(arenaUnit)
                        UpdateStripeColor(class, j, i)
                    end
                end
            else
                -- if they aren't targeting anyone, hide their stripes
                for j = 1, 3 do
                    local stripe = party[j][i]
                    stripe:Hide()
                end
            end
        else
        end
    end
end

local function DetermineArenaSize()
    if UnitExists("arena3") then
        maxArenaIndex = 3
    elseif UnitExists("arena2") then
        maxArenaIndex = 2
    elseif UnitExists("arena1") then
        maxArenaIndex = 1
    end
    CreateStripeTextures()
end

-- Event Registration
frame:RegisterEvent("ARENA_OPPONENT_UPDATE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ARENA_OPPONENT_UPDATE" then
        DetermineArenaSize() -- We wait for everyone to join before setting maxArenaIndex, may need to update later.
    end 
end)

frame:SetScript("OnUpdate", function(self, elapsed)
    if not C_PvP.IsArena() then
        return -- Only update in arenas.
    end

    self.timer = (self.timer or 0) + elapsed
    if self.timer >= interval then
        UpdateArenaTargets()
        self.timer = 0
    end
end)