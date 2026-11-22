-- A tab on the game's own Group Finder window that opens OpenGroup on top of it, and a tab on
-- OpenGroup's window that goes back. The game's window is never shown, hidden, moved or hooked
-- from here: no ShowUIPanel / HideUIPanel (calling the game's panel manager from an addon taints
-- its layout code, and the game later blocks its own protected actions as "UNKNOWN()" and blames
-- OpenGroup), no HookScript on its frames, no anchors to its tabs. OpenGroup just opens above it
-- at the same spot, and going back closes OpenGroup.
local L = OpenGroup
local T = {}
OpenGroup_GroupFinderTab = T

-- the game's Group Finder frame differs by client; the first that exists wins
local CANDIDATES = { "LFGParentFrame", "PVEFrame", "GroupFinderFrame", "LFGListingFrame" }
local ICON = L.ICON

local function findFrame()
	for _, name in ipairs(CANDIDATES) do
		local f = _G[name]
		if type(f) == "table" and f.GetObjectType and not (f.IsForbidden and f:IsForbidden()) then return f, name end
	end
end

-- how much of each icon a tab shows: the ringed icon whole, the square one (which has a wide safety
-- margin round the art) cropped in so the art fills the tab, game icons without their border
function T.coords(icon)
	if icon == ICON then return 0, 1, 0, 1 end
	if icon == L.ICON_SQUARE then return 0.17, 0.83, 0.17, 0.83 end
	return 0.07, 0.93, 0.07, 0.93
end

local function makeTab(parent, icon, tip, onClick)
	local ok, t = pcall(CreateFrame, "Frame", nil, parent, "LargeSideTabButtonTemplate")
	if ok and t and t.Icon then
		t.Icon:SetTexture(icon)
		t.Icon:SetTexCoord(T.coords(icon))
		t.Icon:SetSize(30, 30)
		if t.SetFillToInterior then t:SetFillToInterior(true) end
		if t.SetChecked then t:SetChecked(false) end
		t.tooltipText = tip
		t:SetCustomOnMouseUpHandler(function(_, button, up) if button == "LeftButton" and up then onClick() end end)
	else
		t = CreateFrame("Button", nil, parent)
		t:SetSize(40, 40)
		local tex = t:CreateTexture(nil, "ARTWORK") tex:SetAllPoints() tex:SetTexture(icon)
		tex:SetTexCoord(T.coords(icon))
		t:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		t:SetScript("OnClick", onClick)
		t:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:SetText(tip) GameTooltip:Show() end)
		t:SetScript("OnLeave", GameTooltip_Hide)
	end
	return t
end

local attached
function T.attach()
	if attached then return true end
	local blizz, name = findFrame()
	if not blizz then return false end
	attached = name
	local ui = OpenGroup_UI
	-- on the game's window: open OpenGroup at the same spot, above it (in or out of combat)
	-- a square tab: the art without its ring, cropped like the game's own tab icons
	local tab = makeTab(blizz, L.ICON_SQUARE or ICON, "OpenGroup: groups from every server", function()
		if not (ui and ui.win) then return end
		local x, y = blizz:GetLeft(), blizz:GetTop()
		if x and y then ui.win:ClearAllPoints() ui.win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y) end
		ui.win:Show()
		if ui.win.Raise then ui.win:Raise() end
	end)
	-- below the lowest tab already on the window's right edge (the game's and other addons'), so
	-- it never covers one. Anchored to the window itself at an offset worked out from where the
	-- tabs are, and worked out again each time our tab shows (it shows with the window).
	local function place()
		local right, top = blizz:GetRight(), blizz:GetTop()
		local lowest
		if right and top then
			for _, c in ipairs({ blizz:GetChildren() }) do
				if c ~= tab and c.IsShown and c:IsShown() and c.GetLeft then
					local l, b, t, w = c:GetLeft(), c:GetBottom(), c:GetTop(), c:GetWidth()
					if l and b and t and w and math.abs(l - right) < 12 and w < 80 and t <= top
						and (not lowest or b < lowest) then lowest = b end
				end
			end
		end
		tab:ClearAllPoints()
		tab:SetPoint("TOPLEFT", blizz, "TOPRIGHT", 0, (lowest and top) and (lowest - top - 4) or -60)
	end
	place()
	-- our own frame's script, not the game's: runs whenever the game's window opens
	tab:HookScript("OnShow", function() if C_Timer and C_Timer.After then C_Timer.After(0, place) else place() end end)
	-- a count of what's listed, on the tab
	local badge = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	badge:SetPoint("BOTTOMRIGHT", -2, 2)
	tab:HookScript("OnShow", function()
		local n = 0
		for _, l in pairs(L.listings) do if time() - (l.got or 0) < 300 then n = n + 1 end end
		badge:SetText(n > 0 and ("|cff40ff40" .. n .. "|r") or "")
	end)
	return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, ev, name)
	if ev == "ADDON_LOADED" and type(name) == "string" and not name:find("^Blizzard_") then return end
	if T.attach() then f:UnregisterAllEvents() end
end)
