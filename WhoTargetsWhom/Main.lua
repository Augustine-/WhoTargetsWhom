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

---

-- Issues: 
-- Bars too small
-- Bars default visible
-- 3 Bars in 2s skirmishes
-- Stripe lingers on dead target
-- Stripe doesn't reset when targeter enters stealth


-- Refactor Goals:
-- event hijacking
-- decide how we're going to track who is targeting whom for each update tick
-- figure out how to trigger the timer after the gates open
-- figure out how to get the correct width
-- update max arena enemies/party members based on arena_opponent_update, or something that triggers when allies die?

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

local media = LibStub("LibSharedMedia-3.0")
local frame = CreateFrame("Frame")
local cpf = _G["CompactPartyFrame"]
local partyFrames = cpf["memberUnitFrames"]
local width = cpf:GetWidth()
local maxArenaIndex = 3 

WTW = { }
WTW.eventHandler = CreateFrame("Frame")
WTW.eventHandler.events = { }
WTW.eventHandler:RegisterEvent("PLAYER_LOGIN")
WTW.eventHandler:RegisterEvent("ADDON_LOADED")
WTW.eventHandler:

WTW.party = party = {
    {},
    {},
    {}
 }
 
WTW.eventHandler:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" then
		WTW:OnInitialize()
		WTW:OnEnable()
		WTW.eventHandler:UnregisterEvent("PLAYER_LOGIN")
	else
		local func = self.events[event]
		if type(WTW[func]) == "function" then
			WTW[func](WTW, event, ...)
		end
	end
end)

function WTW:Debug(...)
	print("|cff33ff99Gladius|r:", ...)
end

function WTW:Print(...)
	print("|cff33ff99Gladius|r:", ...)
end

function WTW:RegisterEvent(event, func)
	self.eventHandler.events[event] = func or event
	self.eventHandler:RegisterEvent(event)
end

function WTW:UnregisterEvent(event)
	self.eventHandler.events[event] = nil
	self.eventHandler:UnregisterEvent(event)
end

function WTW:UnregisterAllEvents()
	self.eventHandler:UnregisterAllEvents()
end

function WTW:OnEnable()
	-- register the appropriate events that fires when you enter an arena
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
	-- enable modules
	-- see if we are already in arena
	if IsLoggedIn() then
		WTW:ZONE_CHANGED_NEW_AREA()
	end
end

function WTW:OnDisable()
	self:UnregisterAllEvents()
end

function WTW:ZONE_CHANGED_NEW_AREA()
	local _, instanceType = IsInInstance()
	-- check if we are entering or leaving an arena
	if instanceType == "arena" then
		self:JoinedArena()
	elseif instanceType ~= "arena" and self.instanceType == "arena" then
		self:LeftArena()
	end
	self.instanceType = instanceType
end

function WTW:JoinedArena()
    frame:RegisterEvent("ARENA_OPPONENT_UPDATE")
    frame:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")

    self:HideFrame()

    local numOpps = GetNumArenaOpponentSpecs()
    if numOpps and numOpps > 0 then
        self:ARENA_PREP_OPPONENT_SPECIALIZATIONS()
    end
end

function WTW:ARENA_OPPONENT_UPDATE(event, unit, type)
	if not IsActiveBattlefieldArena() then
		return
	end
	if not self:IsValidUnit(unit) then
		return
	end
	
	local id = string.match(unit, "arena(%d)")
	local specID = GetArenaOpponentSpec(id)
	if specID and specID > 0 then
		local id, name, description, icon, role, class = GetSpecializationInfoByID(specID)
        -- id, class
	end
	self:UpdateUnit(unit)
	self:ShowUnit(unit)
	-- enemy seen
	if type == "seen" then
		self:ShowUnit(unit, false, nil)
	-- enemy stealth
	elseif type == "unseen" then
		self:UpdateAlpha(unit, 0.5)
	-- enemy left arena
	elseif type == "destroyed" then
		self:UpdateAlpha(unit, 0.3)
	-- arena over
	elseif type == "cleared" then
		self:UpdateAlpha(unit, 0)
	end
end

function WTW:ARENA_PREP_OPPONENT_SPECIALIZATIONS()
    -- create stripe textures for new arena
	for i = 1, GetNumGroupMembers() do
		local ally = "party"..i
        local partyFrame = cpf.memberUnitFrames[i]
		for j = 1, GetNumArenaOpponentSpecs() do
            local enemy = "arena"..j
            party[i][j] = partyFrame:CreateTexture(ally..enemy.."stripe", "OVERLAY")
            party[i][j]:SetTexture("Interface\\AddOns\\Quartz\\textures\\Minimalist")
            party[i][j]:SetWidth(width * 2)
            party[i][j]:SetHeight(5)

            if j == 1 then
                party[i][j]:SetPoint("CENTER", partyFrame, "CENTER", 0, 5)
            elseif j == 2 then
                party[i][j]:SetPoint("CENTER", partyFrame, "CENTER", 0, 0)
            elseif j == 3 then
                party[i][j]:SetPoint("CENTER", partyFrame, "CENTER", 0, -5)
            else
                -- do nothing, we don't support arenas larger than 3v3
            end
            party[i][j]:Hide()
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
    for i, p in pairs(party) do
        if (p[arenaN] ~= targeted) then
            p[arenaN]:Hide()
        end
    end
end

local function UpdateArenaTargets()
    for i = 1, maxArenaIndex do
        local arenaUnit = "arena" .. i
        if UnitExists(arenaUnit) then
            local target = UnitName(arenaUnit.."target")
            if target then
                for j = 1, GetNumGroupMembers() do
                    local partyUnit = "raid" .. j
                    if UnitIsUnit(partyUnit, target) then
                        local class = UnitClass(arenaUnit)
                        UpdateStripeColor(class, j, i)
                    end
                end
            else
                -- if they aren't targeting anyone, hide their stripes
                for j = 1, GetNumGroupMembers() do
                    local stripe = party[j][i]
                    stripe:Hide()
                end
            end
        else
            -- if they aren't visible, hide stripes
            for j = 1, GetNumGroupMembers() do
                local stripe = party[j][i]
                stripe:Hide()
            end
        end
    end
end

local function GameStarted()
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "ARENA_OPPONENT_UPDATE" then
           
        end
    end)
end

-- Event Registration
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ZONE_CHANGED_NEW_AREA" then
        local _, instanceType = IsInInstance()
        -- check if we are entering or leaving an arena
        if instanceType == "arena" then
            JoinedArena()
        else
            LeftArena()
        end 
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