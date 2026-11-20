-- A tab on the game's own Group Finder window that opens OpenGroup in its place, and a tab on
-- OpenGroup's window that goes back. The game's window is only hidden and shown (never changed),
-- and nothing happens in combat, so the game's protected UI stays untouched.
local L = OpenGroup
local T = {}
OpenGroup_GroupFinderTab = T

-- the game's Group Finder frame differs by client; the first that exists wins
local CANDIDATES = { "LFGParentFrame", "PVEFrame", "GroupFinderFrame", "LFGListingFrame" }
local ICON = "Interface\\Icons\\INV_Misc_GroupNeedMore"

local function findFrame()
	for _, name in ipairs(CANDIDATES) do
		local f = _G[name]
		if type(f) == "table" and f.GetObjectType and not (f.IsForbidden and f:IsForbidden()) then return f, name end
	end
end

local function makeTab(parent, icon, tip, onClick)
	local ok, t = pcall(CreateFrame, "Frame", nil, parent, "LargeSideTabButtonTemplate")
	if ok and t and t.Icon then
		t.Icon:SetTexture(icon)
		t.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		t.Icon:SetSize(30, 30)
		if t.SetFillToInterior then t:SetFillToInterior(true) end
		t.tooltipText = tip
		t:SetCustomOnMouseUpHandler(function(_, button, up) if button == "LeftButton" and up then onClick() end end)
	else
		t = CreateFrame("Button", nil, parent)
		t:SetSize(40, 40)
		local tex = t:CreateTexture(nil, "ARTWORK") tex:SetAllPoints() tex:SetTexture(icon) tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		t:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		t:SetScript("OnClick", onClick)
		t:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:SetText(tip) GameTooltip:Show() end)
		t:SetScript("OnLeave", GameTooltip_Hide)
	end
	return t
end

local function hidePanel(f) if HideUIPanel then pcall(HideUIPanel, f) else f:Hide() end end
local function showPanel(f) if ShowUIPanel then pcall(ShowUIPanel, f) else f:Show() end end

local attached
function T.attach()
	if attached then return true end
	local blizz, name = findFrame()
	if not blizz then return false end
	attached = name
	local ui = OpenGroup_UI
	-- on the game's window: "OpenGroup", below any tabs it already has on the right edge
	local tab = makeTab(blizz, ICON, "OpenGroup: groups from every shard", function()
		if InCombatLockdown and InCombatLockdown() then UIErrorsFrame:AddMessage("Not in combat.", 1, .1, .1) return end
		local x, y = blizz:GetLeft(), blizz:GetTop()
		hidePanel(blizz)
		if ui and ui.win then
			if x and y then ui.win:ClearAllPoints() ui.win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y) end
			ui.win:Show()
			if L.scan and L.scan.auto then L.scan.auto() end
		end
	end)
	tab:SetPoint("TOPLEFT", blizz, "TOPRIGHT", 0, -60)
	-- a count of what's listed, on the tab
	local badge = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	badge:SetPoint("BOTTOMRIGHT", -2, 2)
	tab:HookScript("OnShow", function()
		local n = 0
		for _, l in pairs(L.listings) do if time() - (l.got or 0) < 300 then n = n + 1 end end
		badge:SetText(n > 0 and ("|cff40ff40" .. n .. "|r") or "")
	end)
	-- on OpenGroup's window: back to the game's Group Finder
	if ui and ui.win and ui.lastTab then
		local back = makeTab(ui.win, "Interface\\Icons\\INV_Misc_Spyglass_02", "The game's Group Finder (this shard only)", function()
			if InCombatLockdown and InCombatLockdown() then return end
			ui.win:Hide()
			showPanel(blizz)
		end)
		back:SetPoint("TOPLEFT", ui.lastTab, "BOTTOMLEFT", 0, -16)
	end
	return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, ev, name)
	if ev == "ADDON_LOADED" and type(name) == "string" and not name:find("^Blizzard_") then return end
	if T.attach() then f:UnregisterAllEvents() end
end)
