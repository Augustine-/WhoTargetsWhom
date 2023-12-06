print("WTW loaded!")
local frame = CreateFrame("Frame")
local interval = 1 -- Time in seconds between checks
local maxArenaIndex = 3 -- Default to 3v3, will adjust after 45 seconds

-- Define class colors
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

-- Function to create a stripe texture for a given raid frame
local function CreateStripeTexture(frame)
    local texture = frame:CreateTexture(nil, "OVERLAY")
    local width = _G["CompactPartyFrame"]:GetWidth()
    texture:SetHeight(5) -- Set the height of the stripe
    texture:SetWidth(width)
    -- Assuming the stripe needs to be positioned in the middle of the frame:
    texture:SetPoint("CENTER", frame, "CENTER", 0, 0)
    return texture
end


-- Update the texture color based on the class targeting the party member
local function UpdateStripeColor(frame, class)
    local color = classColors[class]
    if color then
        frame.stripe:SetColorTexture(unpack(color))
        frame.stripe:Show()
        print("Updated stripe color for", frame:GetName(), "to class", class)
    else
        frame.stripe:Hide()
        print("Hiding stripe for", frame:GetName(), "as no class color found")
    end
end

-- Initialize a table to keep track of arena targets
local lastTargetedByArena = {}

local function UpdateArenaTargets()
    print("Updating arena targets...")

    for i = 1, maxArenaIndex do
        local arenaUnit = "arena" .. i
        if UnitExists(arenaUnit) then
            local target = UnitName(arenaUnit.."target")
            if target then
                print(arenaUnit, "is targeting", target)
                lastTargetedByArena[arenaUnit] = target
                for j = 1, GetNumGroupMembers() do
                    local partyUnit = "raid" .. j
                    if UnitIsUnit(partyUnit, target) then
                        local class = UnitClass(arenaUnit)
                        print(partyUnit.."is being targeted by a: "..class)
                        local raidFrame = _G["CompactPartyFrameMember"..j]
                        if raidFrame then
                            UpdateStripeColor(raidFrame, class)
                        else
                            print("Raid frame not found for unit:", partyUnit)
                        end
                    end
                end
            else
                print(arenaUnit, "has no target.")
                -- Reset the stripe for the party member last targeted by this arena opponent
                local lastTarget = lastTargetedByArena[arenaUnit]
                if lastTarget then
                    for j = 1, GetNumGroupMembers() do
                        local partyUnit = "raid" .. j
                        if UnitIsUnit(partyUnit, lastTarget) then
                            local raidFrame = _G["CompactPartyFrameMember"..j]
                            if raidFrame and raidFrame.stripe then
                                raidFrame.stripe:Hide()
                                print("Resetting stripe for:", raidFrame:GetName())
                            end
                        end
                    end
                    lastTargetedByArena[arenaUnit] = nil -- Clear the last target for this arena opponent
                end
            end
        else
            print(arenaUnit, "does not exist.")
        end
    end
end


-- Initialize stripes for each raid frame when they are created
hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame)
    if frame and not frame.stripe then
        frame.stripe = CreateStripeTexture(frame)
    end
end)

frame:SetScript("OnUpdate", function(self, elapsed)
    self.timer = (self.timer or 0) + elapsed
    if self.timer >= interval then
        local inInstance, instanceType = IsInInstance()
        if not (inInstance and instanceType == "arena") then
            return -- Not in an arena, so don't proceed further
        end

        UpdateArenaTargets()
        self.timer = 0
    end
end)


local function DetermineArenaSize()
    if UnitExists("arena3") then
        print("arena3 found")
        maxArenaIndex = 3
    elseif UnitExists("arena2") then
        print("arena2 found")
        maxArenaIndex = 2
    elseif UnitExists("arena1") then
        print("arena1 found")
        maxArenaIndex = 1
    else
        return
    end
end

frame:RegisterEvent("ARENA_OPPONENT_UPDATE")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ARENA_OPPONENT_UPDATE" then
        DetermineArenaSize()
    end
end)
