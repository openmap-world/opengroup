-- The minimap button: the OpenGroup icon on the minimap's edge. It glows while you're listed. Left-click opens OpenGroup, right-click the Network tab; drag it around the edge.
-- /og minimap hides or shows it.
local L = OpenGroup
local M = {}
OpenGroup_Minimap = M

local function db()
	OpenGroupDB.minimap = type(OpenGroupDB.minimap) == "table" and OpenGroupDB.minimap or {}
	return OpenGroupDB.minimap
end

local b = CreateFrame("Button", "OpenGroupMinimapButton", Minimap)
b:SetSize(32, 32)
b:SetFrameStrata("MEDIUM")
b:SetFrameLevel(8)
b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
b:RegisterForDrag("LeftButton")
b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- the glow behind it while listed: a soft green star that turns, and a gold ring that breathes
local glow = b:CreateTexture(nil, "BACKGROUND", nil, -1)
glow:SetSize(58, 58)
glow:SetPoint("CENTER")
glow:SetTexture("Interface\\Cooldown\\star4")
glow:SetBlendMode("ADD")
glow:SetVertexColor(0.4, 1, 0.4, 0.6)
-- a slow breath rather than a spin
local spin = glow:CreateAnimationGroup()
spin:SetLooping("BOUNCE")
local r = spin:CreateAnimation("Alpha") r:SetFromAlpha(0.9) r:SetToAlpha(0.25) r:SetDuration(2.2) r:SetSmoothing("IN_OUT")
glow:Hide()

-- the icon has its own gold ring, so it goes on without the usual minimap frame
local icon = b:CreateTexture(nil, "ARTWORK")
icon:SetSize(31, 31)
icon:SetPoint("CENTER")
icon:SetTexture(L.ICON)

local ring = b:CreateTexture(nil, "OVERLAY", nil, 1)
ring:SetSize(40, 40)
ring:SetPoint("CENTER")
ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
ring:SetBlendMode("ADD")
ring:SetVertexColor(1, 0.82, 0.25)
local breathe = ring:CreateAnimationGroup()
breathe:SetLooping("BOUNCE")
local ba = breathe:CreateAnimation("Alpha") ba:SetFromAlpha(1) ba:SetToAlpha(0.2) ba:SetDuration(0.9) ba:SetSmoothing("IN_OUT")
ring:Hide()

local function place()
	local a = math.rad(tonumber(db().angle) or 200)
	local rad = (Minimap:GetWidth() or 140) / 2 + 6
	b:ClearAllPoints()
	b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * rad, math.sin(a) * rad)
end

local dragging
b:SetScript("OnDragStart", function(self) dragging = true self:LockHighlight() end)
b:SetScript("OnDragStop", function(self) dragging = false self:UnlockHighlight() end)
b:SetScript("OnUpdate", function(_, el)
	if dragging then
		local mx, my = Minimap:GetCenter()
		local cx, cy = GetCursorPosition()
		local s = Minimap:GetEffectiveScale()
		if mx and cx then
			db().angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
			place()
		end
	end
end)

b:SetScript("OnClick", function(_, button)
	if L.scan and L.scan.auto then L.scan.auto(true) end
	if not OpenGroup_UI then return end
	if button == "RightButton" then OpenGroup_UI.toggle("network") else OpenGroup_UI.toggle() end
end)

b:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText("OpenGroup")
	if not L.mine and L.groupListing then
		GameTooltip:AddLine(("Your group is listed for %s (by %s)"):format(L.titleOf(L.groupListing.l), L.groupListing.leader), 0.25, 1, 0.25, true)
	end
	if L.mine then
		GameTooltip:AddLine("Listed: " .. L.titleOf(L.mine), 0.25, 1, 0.25)
		local sec = time() - L.mine.at
		GameTooltip:AddLine(("For %d:%02d, seen on every server you can reach"):format(sec / 60, sec % 60), 0.8, 0.8, 0.8)
	else
		GameTooltip:AddLine("Find groups on every server.", 1, 1, 1)
	end
	local n = 0
	for _, l in pairs(L.listings) do if time() - l.got < 300 then n = n + 1 end end
	GameTooltip:AddLine(("%d listed now   |   %d OpenGroup players known"):format(n, L.count(L.peers)), 0.8, 0.8, 0.8)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Left-click: open   Right-click: Network   Drag: move", 0.5, 0.5, 0.5)
	GameTooltip:Show()
end)
b:SetScript("OnLeave", GameTooltip_Hide)

function M.isLit() return glow:IsShown() end

function M.update()
	-- listed: our own listing, or our party leader's
	local on = L.mine ~= nil or L.groupListing ~= nil
	glow:SetShown(on) ring:SetShown(on)
	if on then spin:Play() breathe:Play() else spin:Stop() breathe:Stop() end
	b:SetShown(not db().hide)
end

-- a bright pulse when someone new fits your listing
local flash = b:CreateTexture(nil, "OVERLAY", nil, 2)
flash:SetSize(64, 64)
flash:SetPoint("CENTER")
flash:SetTexture("Interface\\Cooldown\\star4")
flash:SetBlendMode("ADD")
flash:SetVertexColor(1, 0.85, 0.3)
flash:SetAlpha(0)
local fg = flash:CreateAnimationGroup()
local f1 = fg:CreateAnimation("Alpha") f1:SetFromAlpha(0) f1:SetToAlpha(1) f1:SetDuration(0.15) f1:SetOrder(1)
local f2 = fg:CreateAnimation("Alpha") f2:SetFromAlpha(1) f2:SetToAlpha(0) f2:SetDuration(0.9) f2:SetOrder(2)
local fr = fg:CreateAnimation("Rotation") fr:SetDegrees(-120) fr:SetDuration(1.05)
fg:SetLooping("NONE")
function M.flash() if b:IsShown() then fg:Stop() fg:Play() end end

function M.toggle()
	db().hide = not db().hide
	M.update()
	L.print(db().hide and "minimap button hidden (/og minimap brings it back)." or "minimap button shown.")
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() place() M.update() end)
b:Hide()
