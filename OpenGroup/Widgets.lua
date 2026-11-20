-- Small building blocks for the OpenGroup window: dropdowns in the game's own style (with a plain
-- fallback), a suggestion popup for typed searches, round role buttons, and the category banners.
local W = {}
OpenGroup_Widgets = W

W.GOLD, W.GREY, W.GREEN, W.WHITE = "|cffffd100", "|cff8f8f8f", "|cff40ff40", "|cffffffff"

function W.hasAtlas(name)
	return type(name) == "string" and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

function W.classColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	return c and c.colorStr and ("|c" .. c.colorStr) or W.WHITE
end

function W.classAtlas(class)
	if type(class) ~= "string" or class == "" then return nil end
	local a = "groupfinder-icon-class-" .. class:lower()
	return W.hasAtlas(a) and a or nil
end

-- --------------------------------------------------------------------------------------------
-- a dark box with a thin border (popups)

local BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 14,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
function W.box(parent)
	local f = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	if f.SetBackdrop then
		f:SetBackdrop(BACKDROP)
		f:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
		f:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
	end
	return f
end

-- --------------------------------------------------------------------------------------------
-- suggestion popup: a list of choices under an anchor. items = { { text, value, disabled } }

local popup
function W.popup()
	if popup then return popup end
	popup = W.box(UIParent)
	popup:SetFrameStrata("FULLSCREEN_DIALOG")
	popup:SetClampedToScreen(true)
	popup:Hide()
	popup.buttons = {}
	popup.selected = 0
	function popup:Open(anchor, items, onPick, width)
		self.items, self.onPick = items, onPick
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -4, 2)
		self:SetWidth(width or anchor:GetWidth() + 8)
		for i, item in ipairs(items) do
			local b = self.buttons[i]
			if not b then
				b = CreateFrame("Button", nil, self)
				b:SetHeight(20)
				b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 20)
				b:SetPoint("RIGHT", -6, 0)
				b.hl = b:CreateTexture(nil, "HIGHLIGHT")
				b.hl:SetAllPoints()
				b.hl:SetColorTexture(1, 0.82, 0, 0.15)
				b.sel = b:CreateTexture(nil, "BACKGROUND")
				b.sel:SetAllPoints()
				b.sel:SetColorTexture(0.3, 0.55, 1, 0.25)
				b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
				b.text:SetPoint("LEFT", 6, 0)
				b.text:SetPoint("RIGHT", -6, 0)
				b.text:SetJustifyH("LEFT")
				b.text:SetWordWrap(false)
				b:SetScript("OnClick", function(btn) popup:Pick(btn.index) end)
				self.buttons[i] = b
			end
			b.index = i
			b.text:SetText(item.text)
			b:Show()
		end
		for i = #items + 1, #self.buttons do self.buttons[i]:Hide() end
		self:SetHeight(12 + #items * 20)
		self.selected = #items > 0 and 1 or 0
		self:Paint()
		self:SetShown(#items > 0)
	end
	function popup:Paint()
		for i, b in ipairs(self.buttons) do b.sel:SetShown(i == self.selected) end
	end
	function popup:Move(d)
		if not self:IsShown() or not self.items or #self.items == 0 then return end
		self.selected = (self.selected - 1 + d) % #self.items + 1
		self:Paint()
	end
	function popup:Pick(i)
		i = i or self.selected
		local item = self.items and self.items[i]
		self:Hide()
		if item and self.onPick then self.onPick(item.value, item) end
	end
	return popup
end

-- An edit box that suggests as you type: getItems(text) -> items; onPick(value).
function W.autocomplete(editBox, getItems, onPick, width)
	local p = W.popup()
	local function update(self)
		if not self:HasFocus() then return end
		p:Open(self, getItems(self:GetText()), function(v, item) onPick(v, item) end, width)
		p.owner = self
	end
	editBox:HookScript("OnTextChanged", function(self, user) if user then update(self) end end)
	editBox:HookScript("OnEditFocusGained", update)
	editBox:HookScript("OnEditFocusLost", function(self) C_Timer.After(0.15, function() if p.owner == self then p:Hide() end end) end)
	editBox:HookScript("OnKeyDown", function(self, key)
		if p.owner ~= self or not p:IsShown() then return end
		if key == "DOWN" then p:Move(1) elseif key == "UP" then p:Move(-1) end
	end)
	editBox:SetScript("OnEnterPressed", function(self)
		if p.owner == self and p:IsShown() then p:Pick() end
	end)
	editBox:SetScript("OnEscapePressed", function(self) p:Hide() self:ClearFocus() end)
end

-- --------------------------------------------------------------------------------------------
-- dropdowns. The game's WowStyle1DropdownTemplate when there is one (Forever has it, it's what the
-- Group Finder uses), else a plain button that opens the popup above.
--   build(root) adds entries: W.radio(root, text, isSelected, onSelect) / W.check(...)

function W.dropdown(parent, width, defaultText, build)
	local ok, dd = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
	if ok and dd and dd.SetupMenu then
		dd:SetWidth(width)
		dd:SetDefaultText(defaultText)
		dd:SetupMenu(function(_, root) build(root) end)
		function dd:SetLabel(text)
			if self.OverrideText then self:OverrideText(text) else self:SetDefaultText(text) end
		end
		function dd:Refresh() if self.GenerateMenu then self:GenerateMenu() end end
		return dd
	end
	-- fallback
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 24)
	b:SetText(defaultText)
	function b:SetLabel(text) self:SetText(text) end
	function b:Refresh() end
	b:SetScript("OnClick", function(self)
		local items = {}
		local fake = {}
		function fake:CreateRadio(text, isSel, onSel, data)
			items[#items + 1] = { text = (isSel(data) and "> " or "   ") .. text, value = function() onSel(data) end }
		end
		function fake:CreateCheckbox(text, isSel, onSel, data)
			items[#items + 1] = { text = (isSel(data) and "[x] " or "[  ] ") .. text, value = function() onSel(data) end }
		end
		function fake:CreateDivider() end
		function fake:CreateTitle(text) items[#items + 1] = { text = W.GOLD .. text .. "|r", value = function() end } end
		build(fake)
		W.popup():Open(self, items, function(fn) fn() end, width + 60)
	end)
	return b
end

-- --------------------------------------------------------------------------------------------
-- round role button with a check box under it (the old Looking For Group role picker)

W.ROLE_ATLAS = { [1] = "groupfinder-icon-role-large-tank", [2] = "groupfinder-icon-role-large-heal", [4] = "groupfinder-icon-role-large-dps" }
W.ROLE_NAME = { [1] = TANK or "Tank", [2] = HEALER or "Healer", [4] = DAMAGER or "Damage" }

W.ROLE_NAME[0] = "Any role"

function W.className(class)
	return class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or (class:sub(1, 1) .. class:sub(2):lower())) or "Any class"
end

-- a class icon on a texture: the Group Finder's round one, else the old class sheet
function W.setClassIcon(tex, class)
	local atlas = W.classAtlas(class)
	if atlas then tex:SetAtlas(atlas) tex:SetDesaturated(false) tex:SetVertexColor(1, 1, 1) return true end
	local tc = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class or ""]
	if tc then
		tex:SetTexture("Interface\\WorldStateFrame\\Icons-Classes")
		tex:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
		tex:SetDesaturated(false) tex:SetVertexColor(1, 1, 1)
		return true
	end
	return false
end

-- one open spot's icon: its class if set, else its role; "any role" is the damage icon greyed
function W.spotIcon(tex, role, class)
	tex:SetTexCoord(0, 1, 0, 1)
	if class and W.setClassIcon(tex, class) then return end
	tex:SetAtlas(W.ROLE_ATLAS[(role and role ~= 0) and role or 4])
	tex:SetDesaturated(role == 0 or role == nil)
	if role == 0 or role == nil then tex:SetVertexColor(0.8, 0.8, 0.8) else tex:SetVertexColor(1, 1, 1) end
end

-- "52-54", "52+", "up to 54" or ""
function W.levelRange(min, max)
	if min and max then return min == max and tostring(min) or (min .. "-" .. max) end
	if min then return min .. "+" end
	if max then return "up to " .. max end
	return ""
end

-- "Damage: Hunter, 52-54", "Healer: any"
function W.spotText(sp)
	local bits = {}
	if sp.class then bits[#bits + 1] = W.classColor(sp.class) .. W.className(sp.class) .. "|r" end
	local lv = W.levelRange(sp.min, sp.max)
	if lv ~= "" then bits[#bits + 1] = "level " .. lv end
	return W.ROLE_NAME[sp.role or 0] .. ": " .. (#bits > 0 and table.concat(bits, ", ") or "any")
end

-- /og art: what the game's own Group Finder window is drawn with (every texture's atlas or file,
-- coords, size, layer, colour and anchor, and each frame's path), saved to OpenGroupDB.art so the
-- look can be matched. Read-only: it only calls Get* functions, each in a pcall, and skips any
-- value the game won't let addons read.
function W.dumpArt(root, rootName)
	local out = { at = time and time() or 0, root = rootName, items = {} }
	local function ok(v) return v == nil or not canaccessvalue or canaccessvalue(v) end
	local function get(obj, fn, ...)
		if not obj[fn] then return nil end
		local res = { pcall(obj[fn], obj, ...) }
		if not res[1] then return nil end
		for i = 2, #res do if not ok(res[i]) then return nil end end
		return select(2, unpack(res))
	end
	local function name(obj, parentPath)
		local n = get(obj, "GetName")
		if type(n) == "string" and n ~= "" then return n end
		local k = get(obj, "GetParentKey") or get(obj, "GetDebugName")
		if type(k) == "string" and k ~= "" then return parentPath .. "." .. k:gsub("^.*%.", "") end
		return parentPath .. ".?"
	end
	local function round(v) return type(v) == "number" and math.floor(v * 1000 + 0.5) / 1000 or v end
	local function point(obj)
		local p, rel, rp, x, y = get(obj, "GetPoint", 1)
		if not p then return nil end
		local relName = rel and (get(rel, "GetName") or get(rel, "GetDebugName")) or nil
		return { p, type(relName) == "string" and relName or "?", rp, round(x), round(y), n = get(obj, "GetNumPoints") }
	end
	local items = out.items
	local function walk(frame, path, depth)
		if #items >= 2500 or depth > 12 then return end
		local w, h = get(frame, "GetSize")
		items[#items + 1] = { kind = "frame", path = path, type = get(frame, "GetObjectType"), w = round(w), h = round(h),
			shown = get(frame, "IsShown"), level = get(frame, "GetFrameLevel"), strata = get(frame, "GetFrameStrata"), point = point(frame) }
		for _, r in ipairs({ get(frame, "GetRegions") }) do
			if #items >= 2500 then return end
			local t = get(r, "GetObjectType")
			local rpath = name(r, path)
			if t == "Texture" then
				local l, tt, b, ty = get(r, "GetTexCoord")
				local cr, cg, cb, ca = get(r, "GetVertexColor")
				local rw, rh = get(r, "GetSize")
				local layer, sub = get(r, "GetDrawLayer")
				items[#items + 1] = { kind = "tex", path = rpath, atlas = get(r, "GetAtlas"), file = get(r, "GetTextureFilePath") or get(r, "GetTexture"),
					coords = l and { round(l), round(tt), round(b), round(ty) } or nil, w = round(rw), h = round(rh), layer = layer, sub = sub,
					color = cr and { round(cr), round(cg), round(cb), round(ca) } or nil, blend = get(r, "GetBlendMode"),
					desat = get(r, "IsDesaturated"), shown = get(r, "IsShown"), point = point(r) }
			elseif t == "FontString" then
				local text = get(r, "GetText")
				local font = get(r, "GetFontObject")
				items[#items + 1] = { kind = "text", path = rpath, text = type(text) == "string" and text:sub(1, 60) or nil,
					font = font and get(font, "GetName") or nil, color = { get(r, "GetTextColor") }, point = point(r) }
			end
		end
		for _, c in ipairs({ get(frame, "GetChildren") }) do
			if #items >= 2500 then return end
			if not (c.IsForbidden and c:IsForbidden()) then walk(c, name(c, path), depth + 1) end
		end
	end
	walk(root, rootName, 0)
	return out
end

-- the game's Group Finder role art: a coloured round background (93 px around a 64 px button)
-- and the big role icon (85 px), read off its List page with /og art. The small round icons
-- stand in where the client hasn't got them.
W.ROLE_BIG = { [1] = "UI-LFG-RoleIcon-Tank", [2] = "UI-LFG-RoleIcon-Healer", [4] = "UI-LFG-RoleIcon-DPS" }
W.ROLE_BG = { [1] = "UI-LFG-RoleIcon-Tank-Background", [2] = "UI-LFG-RoleIcon-Healer-Background", [4] = "UI-LFG-RoleIcon-DPS-Background" }

-- big role art on a button-sized frame: f.bg and f.icon are made here; role 0 (any) is the damage
-- art greyed out
function W.roleArt(f, size)
	f.bg = f.bg or f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetSize(size * 93 / 64, size * 93 / 64)
	f.bg:SetPoint("CENTER")
	f.icon = f.icon or f:CreateTexture(nil, "ARTWORK")
	f.icon:SetSize(size * 85 / 64, size * 85 / 64)
	f.icon:SetPoint("CENTER")
	function f:SetRole(role, on)
		local r = (role and role ~= 0) and role or 4
		local big = W.hasAtlas(W.ROLE_BIG[r])
		if big then
			self.icon:SetAtlas(W.ROLE_BIG[r])
			self.bg:SetAtlas(W.ROLE_BG[r]) self.bg:Show()
			self.icon:SetSize(size * 85 / 64, size * 85 / 64)
		else
			self.icon:SetAtlas(W.ROLE_ATLAS[r])
			self.icon:SetSize(size, size)
			self.bg:Hide()
		end
		local grey = (role == 0 or role == nil) or on == false
		self.icon:SetDesaturated(grey) self.bg:SetDesaturated(grey)
		self.icon:SetAlpha(on == false and 0.5 or 1) self.bg:SetAlpha(on == false and 0.45 or 1)
	end
	return f
end

function W.roleButton(parent, role, size, onToggle)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	W.roleArt(b, size)
	b:SetRole(role, false)
	b.glow = b:CreateTexture(nil, "HIGHLIGHT")
	b.glow:SetAllPoints(b.icon)
	b.glow:SetAtlas(W.hasAtlas(W.ROLE_BIG[role]) and W.ROLE_BIG[role] or W.ROLE_ATLAS[role])
	b.glow:SetBlendMode("ADD")
	b.glow:SetAlpha(0.4)
	b.check = CreateFrame("CheckButton", nil, b, "UICheckButtonTemplate")
	b.check:SetSize(24, 24)
	b.check:SetPoint("BOTTOMLEFT", -5, -5)
	function b:SetOn(on)
		self.on = on and true or false
		self.check:SetChecked(self.on)
		self:SetRole(role, self.on)
	end
	local function toggle()
		b:SetOn(not b.on)
		onToggle(role, b.on)
		if W.bounce then W.bounce(b, 1.12) end
		if W.sound then W.sound(b.on and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF") end
	end
	b:SetScript("OnClick", toggle)
	b.check:SetScript("OnClick", function() b:SetOn(b.check:GetChecked()) onToggle(role, b.on) if W.bounce then W.bounce(b, 1.12) end end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(W.ROLE_NAME[role])
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	b:SetOn(false)
	return b
end

-- --------------------------------------------------------------------------------------------
-- category banner art. The Group Finder's own banner atlases where the client has them: first
-- read off Blizzard's loaded Group Finder (names vary by client), else a list of known names,
-- else a coloured band.

local CANDIDATES = {
	dungeon = { "groupfinder-button-dungeons" },
	raid = { "groupfinder-button-raids-classic", "groupfinder-button-raids" },
	quest = { "groupfinder-button-questing" },
	battle = { "groupfinder-button-battlegrounds", "groupfinder-button-arenas", "groupfinder-button-pvp" },
	custom = { "groupfinder-button-custom-pve", "groupfinder-button-custom" },
	summon = {},
}
local TINT = { dungeon = { .35, .22, .12 }, raid = { .35, .12, .12 }, quest = { .3, .25, .1 }, battle = { .3, .28, .08 }, custom = { .08, .28, .2 }, summon = { .7, .45, 1 } }

local function kindOf(name)
	name = (name or ""):lower()
	if name:find("dungeon") then return "dungeon" end
	if name:find("raid") then return "raid" end
	if name:find("quest") or name:find("zone") then return "quest" end
	if name:find("battle") or name:find("pvp") or name:find("arena") then return "battle" end
	if name:find("summon") then return "summon" end
	return "custom"
end
W.kindOf = kindOf

local harvested
local function harvest()
	if harvested then return harvested end
	-- only from the game's Group Finder once the player has opened it (we never load it ourselves:
	-- loading Blizzard's protected UI from an addon risks taint)
	local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder_VanillaStyle")
	if not loaded then return {} end
	harvested = {}
	pcall(function()
		local f = EnumerateFrames()
		local n = 0
		while f and n < 20000 do
			n = n + 1
			if f.GetRegions and not (f.IsForbidden and f:IsForbidden()) then
				local atlas, label
				for _, r in ipairs({ f:GetRegions() }) do
					if r.GetAtlas then
						local a = r:GetAtlas()
						-- the category picture, not the frame, cover or highlight drawn over it
						if type(a) == "string" and a:find("^groupfinder%-button%-") and not a:find("select")
							and not a:find("cover") and not a:find("frame") and not a:find("border") and not a:find("highlight") then atlas = a end
					elseif r.GetText then
						local t = r:GetText()
						if type(t) == "string" and t ~= "" then label = t end
					end
				end
				if atlas and label then harvested[kindOf(label)] = harvested[kindOf(label)] or atlas end
			end
			f = EnumerateFrames(f)
		end
	end)
	return harvested
end

-- returns atlas, tint (tint = colour band when no art, or a vertex colour over borrowed art)
function W.bannerAtlas(categoryName)
	local kind = kindOf(categoryName)
	-- the known names first: what's read off Blizzard's window is only a fallback, as it can pick
	-- up a plain frame drawn over the picture
	for _, a in ipairs(CANDIDATES[kind]) do if W.hasAtlas(a) then return a end end
	local h = harvest()
	if h[kind] and W.hasAtlas(h[kind]) then return h[kind] end
	-- Custom has no banner of its own on this client: the Quests art tinted green, the way the
	-- game's own Custom banner looks
	if kind == "custom" or kind == "summon" then
		-- Custom and Summons have no banner of their own: the Quests art, tinted (green for Custom like
		-- the game's own, fel purple for summons)
		local tint = kind == "custom" and { .45, 1, .7 } or { .75, .5, 1 }
		for _, a in ipairs(CANDIDATES.quest) do if W.hasAtlas(a) then return a, tint, true end end
	end
	return nil, TINT[kind]
end

-- The game's category buttons: 418 x 67, the picture inset (5 px in, 8 down, 54 tall) under a frame
-- layer (groupfinder-button-cover) with its own hover and pressed versions.
W.BANNER_COVER = "groupfinder-button-cover"
function W.banner(parent, height)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(height)
	b.art = b:CreateTexture(nil, "BACKGROUND")
	b.art:SetAllPoints()
	local covered = W.hasAtlas(W.BANNER_COVER)
	b.shade = b:CreateTexture(nil, "BORDER")
	b.shade:SetPoint("TOPLEFT") b.shade:SetPoint("BOTTOMLEFT")
	b.shade:SetWidth(height * 4)
	b.shade:SetColorTexture(0, 0, 0, 0.35)
	if b.shade.SetGradient and CreateColor then
		pcall(b.shade.SetGradient, b.shade, "HORIZONTAL", CreateColor(0, 0, 0, .55), CreateColor(0, 0, 0, 0))
	end
	b.edge = b:CreateTexture(nil, "OVERLAY")
	b.edge:SetPoint("TOPLEFT", -1, 1) b.edge:SetPoint("BOTTOMRIGHT", 1, -1)
	b.edge:SetColorTexture(0.55, 0.45, 0.3, 0.6)
	b.edge:SetDrawLayer("BACKGROUND", -1)
	b.hl = b:CreateTexture(nil, "HIGHLIGHT")
	b.hl:SetAllPoints()
	b.hl:SetColorTexture(1, 0.85, 0.5, 0.12)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	b.text:SetPoint("LEFT", 18, 0)
	b.icon = b:CreateTexture(nil, "OVERLAY")
	b.icon:SetSize(height * 0.62, height * 0.62)
	b.icon:SetPoint("RIGHT", -18, 4)
	b.icon:Hide()
	b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.sub:SetPoint("BOTTOMRIGHT", -14, 8)
	if covered then
		-- the picture sits inside the frame; the frame, its hover and its pressed look go on top
		b.art:ClearAllPoints()
		b.art:SetPoint("TOPLEFT", 5, -8 * height / 67)
		b.art:SetPoint("BOTTOMRIGHT", -5, 5 * height / 67)
		b.shade:Hide() b.edge:Hide() b.hl:Hide()
		b.cover = b:CreateTexture(nil, "ARTWORK")
		b.cover:SetAllPoints()
		b.cover:SetAtlas(W.BANNER_COVER)
		b.coverDown = b:CreateTexture(nil, "ARTWORK", nil, 1)
		b.coverDown:SetAllPoints()
		b.coverDown:SetAtlas("groupfinder-button-cover-down")
		b.coverDown:Hide()
		if W.hasAtlas("groupfinder-button-cover-hover") then b:SetHighlightAtlas("groupfinder-button-cover-hover") end
		b:SetScript("OnMouseDown", function(self) self.coverDown:Show() self.cover:Hide() end)
		b:SetScript("OnMouseUp", function(self) self.coverDown:Hide() self.cover:Show() end)
		b.text:SetFontObject("GameFontNormalLarge")
		b.text:SetPoint("LEFT", 20, 0)
		b.sub:SetPoint("BOTTOMRIGHT", -16, 10 * height / 67)
		b.icon:SetPoint("RIGHT", -24, 2)
	end
	if W.hoverLerp then
		W.hoverLerp(b, function(v)
			b.text:SetPoint("LEFT", (covered and 20 or 18) + 8 * v, 0)
			local c = 0.85 + 0.15 * v
			if not b.tinted then b.art:SetVertexColor(c, c, c) end
		end)
	end
	function b:SetCategory(name, sub, icon)
		self.text:SetText(name)
		self.sub:SetText(sub or "")
		self.icon:SetShown(icon ~= nil)
		if icon then self.icon:SetTexture(icon) end
		local atlas, tint, tinted = W.bannerAtlas(name)
		if atlas then
			self.art:SetAtlas(atlas)
			self.art:SetDesaturated(tinted == true)
			self.tinted = tinted == true
			if tinted then self.art:SetVertexColor(tint[1], tint[2], tint[3]) else self.art:SetVertexColor(1, 1, 1) end
		else
			self.art:SetColorTexture(tint[1], tint[2], tint[3], 1)
		end
	end
	return b
end

-- A category tile for the List tab's grid, in the style of the game's Professions cards
-- (Profession-overview-Card, read off its window with /og art): the card's chamfered gold frame,
-- and inside it the category picture at near full brightness, cut to the card's shape by a mask,
-- with only the bottom darkened for the name and count. The picture keeps its proportions and
-- covers the tile (the mask trims what spills over), so nothing depends on texture coordinates.
W.TILE_CARD = "Profession-overview-Card"

-- Bigger pictures for the tiles, where the client has them: the game's loading screens (about
-- 1024 x 768), so a tile never shows a blown-up 54 px banner. The first file that exists is used;
-- with none, the banner picture is pinned to the right at near its own size, as the game's do.
W.TILE_ART = {
	dungeon = { "%sLoadScreenBlackrockDepths", "%sLoadScreenBlackrockSpire", "%sLoadScreenStratholme", "%sLoadScreenScholomance", "%sLoadScreenDeadmines" },
	quest = { "%sLoadScreenKalimdor", "%sLoadScreenEasternKingdom", "%sLoadScreenEasternKingdoms", "%sLoadScreenKalimdor2" },
	battle = { "%sLoadScreenWarsongGulch", "%sLoadScreenArathiBasin", "%sLoadScreenPvPBattleground", "%sLoadScreenAlteracValley" },
	custom = { "%sLoadScreenDireMaul", "%sLoadScreenMonastery", "%sLoadScreenUldaman", "%sLoadScreenEasternKingdom", "%sLoadScreenKalimdor" },
	summon = { "%sLoadScreenEasternKingdom" },
}
local artFound = {}
function W.tileArt(kind)
	if artFound[kind] ~= nil then return artFound[kind] or nil end
	artFound[kind] = false
	if not GetFileIDFromPath then return nil end
	for _, f in ipairs(W.TILE_ART[kind] or {}) do
		local path = f:format("Interface\\Glues\\LoadingScreens\\")
		local ok, id = pcall(GetFileIDFromPath, path)
		if ok and id then artFound[kind] = path return path end
	end
	return nil
end

function W.tile(parent)
	local b = CreateFrame("Button", nil, parent)
	local card = W.hasAtlas(W.TILE_CARD)
	local inset = card and 5 or 2
	b.inset, b.cardArt = inset, card
	if card then
		b.card = b:CreateTexture(nil, "BACKGROUND", nil, -8)
		b.card:SetAllPoints()
		b.card:SetAtlas(W.TILE_CARD)
	end
	-- the window the picture shows through, and its chamfered shape
	b.window = CreateFrame("Frame", nil, b)
	b.window:SetPoint("TOPLEFT", inset, -inset)
	b.window:SetPoint("BOTTOMRIGHT", -inset, inset)
	b.window:SetFrameLevel(b:GetFrameLevel())
	b.art = b:CreateTexture(nil, "BORDER", nil, 0)
	b.art:SetPoint("RIGHT", b.window, "RIGHT")
	b.mask = b.CreateMaskTexture and b:CreateMaskTexture() or nil
	if b.mask then
		b.mask:SetAllPoints(b.window)
		if card then b.mask:SetAtlas(W.TILE_CARD) else b.mask:SetColorTexture(1, 1, 1, 1) end
		b.art:AddMaskTexture(b.mask)
	end
	b.fade = b:CreateTexture(nil, "BORDER", nil, 2)
	b.fade:SetPoint("BOTTOMLEFT", b.window, "BOTTOMLEFT")
	b.fade:SetPoint("BOTTOMRIGHT", b.window, "BOTTOMRIGHT")
	b.fade:SetColorTexture(0, 0, 0, 0.6)
	if b.fade.SetGradient and CreateColor then
		pcall(b.fade.SetGradient, b.fade, "VERTICAL", CreateColor(0, 0, 0, 0.9), CreateColor(0, 0, 0, 0))
	end
	if b.mask then b.fade:AddMaskTexture(b.mask) end
	if not card then W.edge(b, 0.62, 0.48, 0.22, 1) end
	b.hl = b:CreateTexture(nil, "HIGHLIGHT")
	b.hl:SetAllPoints(b.window)
	b.hl:SetColorTexture(1, 0.85, 0.5, 0.14)
	b.hl:SetBlendMode("ADD")
	if b.mask then b.hl:AddMaskTexture(b.mask) end
	b.down = b:CreateTexture(nil, "ARTWORK", nil, 1)
	b.down:SetAllPoints(b.window)
	b.down:SetColorTexture(0, 0, 0, 0.3)
	if b.mask then b.down:AddMaskTexture(b.mask) end
	b.down:Hide()
	b:SetScript("OnMouseDown", function(self) self.down:Show() end)
	b:SetScript("OnMouseUp", function(self) self.down:Hide() end)
	-- hover lifts the faded picture a little
	b:SetScript("OnEnter", function(self) if self.file then self.art:SetAlpha(0.5) end end)
	b:SetScript("OnLeave", function(self) if self.file then self.art:SetAlpha(0.3) end self.down:Hide() end)
	b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	b.sub:SetPoint("BOTTOMLEFT", b.window, "BOTTOMLEFT", 14, 12)
	b.sub:SetPoint("RIGHT", b.window, "RIGHT", -12, 0)
	b.sub:SetJustifyH("LEFT")
	b.sub:SetWordWrap(false)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	b.text:SetPoint("BOTTOMLEFT", b.sub, "TOPLEFT", 0, 3)
	b.text:SetPoint("RIGHT", b.window, "RIGHT", -12, 0)
	b.text:SetJustifyH("LEFT")
	b.icon = b:CreateTexture(nil, "OVERLAY")
	b.icon:SetSize(40, 40)
	b.icon:SetPoint("TOPRIGHT", b.window, "TOPRIGHT", -10, -10)
	b.icon:Hide()
	-- the picture covers the window at its own proportions (right part kept); the mask trims it
	local function size(self)
		local w, h = self.window:GetSize()
		if not (w and h and w > 0 and h > 0) then return end
		if self.file then
			-- a loading screen (4:3): zoomed well in on its lower middle, past the logo at the top
			local ratio, zoom = 4 / 3, 1.8
			local aw, ah
			if w / h > ratio then aw, ah = w, w / ratio else aw, ah = h * ratio, h end
			aw, ah = aw * zoom, ah * zoom
			self.art:ClearAllPoints()
			self.art:SetPoint("CENTER", self.window, "CENTER", 0, ah * 0.14)
			self.art:SetSize(aw, ah)
		else
			-- the banner (408 x 54): pinned top right, at most 1.4x its own height, over the dark card
			local info = self.atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(self.atlas)
			local aw, ah = (info and info.width and info.width > 0) and info.width or 408, (info and info.height and info.height > 0) and info.height or 54
			local ratio = aw / ah
			local ht = math.min(h, ah * 1.4)
			self.art:ClearAllPoints()
			self.art:SetPoint("TOPRIGHT", self.window, "TOPRIGHT")
			self.art:SetSize(math.max(w, ht * ratio), math.max(w, ht * ratio) / ratio)
		end
		self.fade:SetHeight(math.floor(h * 0.45))
		if not self.mask then
			-- no masks on this client: fit the picture inside instead
			self.art:SetSize(math.min(w, h * ratio), math.min(h, w / ratio))
		end
	end
	b.window:SetScript("OnSizeChanged", function() size(b) end)
	function b:SetCategory(name, sub, icon)
		self.text:SetText(name)
		self.sub:SetText(sub or "")
		self.icon:SetShown(icon ~= nil)
		if icon then self.icon:SetTexture(icon) end
		local atlas, tint, tinted = W.bannerAtlas(name)
		self.atlas = atlas
		self.file = W.tileArt(W.kindOf(name))
		if self.file then
			-- a quiet background: grey and faded, so the name stays the thing you read
			self.art:SetTexture(self.file)
			self.art:SetTexCoord(0, 1, 0, 1)
			self.art:SetDesaturated(true)
			self.art:SetVertexColor(1, 1, 1)
			self.art:SetAlpha(0.3)
		elseif atlas then
			self.art:SetAtlas(atlas)
			self.art:SetDesaturated(tinted == true)
			if tinted then self.art:SetVertexColor(tint[1], tint[2], tint[3]) else self.art:SetVertexColor(1, 1, 1) end
			self.art:SetAlpha(1)
		else
			self.art:SetColorTexture(tint[1], tint[2], tint[3], 1)
		end
		size(self)
	end
	return b
end

-- --------------------------------------------------------------------------------------------
-- animation and sound helpers

function W.sound(key, fallback)
	local id = SOUNDKIT and SOUNDKIT[key] or fallback
	if id and PlaySound then pcall(PlaySound, id) end
end

-- fade a frame in from transparent (tab switches, panels)
function W.fadeIn(frame, dur)
	if not frame.fadeAnim then
		local g = frame:CreateAnimationGroup()
		local a = g:CreateAnimation("Alpha")
		a:SetFromAlpha(0) a:SetToAlpha(1)
		a:SetSmoothing("OUT")
		g.a = a
		frame.fadeAnim = g
	end
	frame.fadeAnim.a:SetDuration(dur or 0.18)
	frame.fadeAnim:Stop()
	frame.fadeAnim:Play()
end

-- a quick grow-and-settle (role buttons, the toast)
function W.bounce(frame, amount)
	if not frame.bounceAnim then
		local g = frame:CreateAnimationGroup()
		local up = g:CreateAnimation("Scale")
		up:SetOrder(1) up:SetDuration(0.08) up:SetSmoothing("OUT")
		local down = g:CreateAnimation("Scale")
		down:SetOrder(2) down:SetDuration(0.14) down:SetSmoothing("IN_OUT")
		g.up, g.down = up, down
		frame.bounceAnim = g
	end
	local s = amount or 1.15
	local g = frame.bounceAnim
	if g.up.SetScaleFrom then
		g.up:SetScaleFrom(1, 1) g.up:SetScaleTo(s, s)
		g.down:SetScaleFrom(s, s) g.down:SetScaleTo(1, 1)
	else
		g.up:SetScale(s, s) g.down:SetScale(1 / s, 1 / s)
	end
	g:Stop() g:Play()
end

-- a texture that spins while shown (search in progress)
function W.spinner(parent, size, texture)
	local t = parent:CreateTexture(nil, "OVERLAY")
	t:SetSize(size, size)
	t:SetTexture(texture or "Interface\\Buttons\\UI-RefreshButton")
	local g = t:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	local r = g:CreateAnimation("Rotation")
	r:SetDegrees(-360) r:SetDuration(1)
	t.anim = g
	function t:Start() self:Show() self.anim:Play() end
	function t:Stop() self.anim:Stop() self:Hide() end
	t:Hide()
	return t
end

-- a looping soft pulse (the "Listed" light, empty-state art)
function W.pulse(region, low, dur)
	local g = region:CreateAnimationGroup()
	g:SetLooping("BOUNCE")
	local a = g:CreateAnimation("Alpha")
	a:SetFromAlpha(1) a:SetToAlpha(low or 0.35)
	a:SetDuration(dur or 0.9)
	a:SetSmoothing("IN_OUT")
	region.pulseAnim = g
	return g
end

-- Smoothly move a value toward a target every frame (hover effects): calls set(v) with v in 0..1.
function W.hoverLerp(frame, set, speed)
	frame.hoverV, frame.hoverT = 0, 0
	frame:HookScript("OnEnter", function(self) self.hoverT = 1 end)
	frame:HookScript("OnLeave", function(self) self.hoverT = 0 end)
	frame:HookScript("OnUpdate", function(self, el)
		if self.hoverV == self.hoverT then return end
		local d = (speed or 8) * el
		if self.hoverV < self.hoverT then self.hoverV = math.min(self.hoverT, self.hoverV + d)
		else self.hoverV = math.max(self.hoverT, self.hoverV - d) end
		set(self.hoverV)
	end)
end

-- --------------------------------------------------------------------------------------------
-- The Forever look: warm dark-brown bars with a thin bronze-gold edge (the profession and quest
-- log headers), and the gold underline that marks a selected entry.

-- a left-to-right fade on a texture; old and new clients spell it differently
function W.gradient(tex, r1, g1, b1, a1, r2, g2, b2, a2)
	tex:SetColorTexture(1, 1, 1, 1)
	if CreateColor and tex.SetGradient and pcall(tex.SetGradient, tex, "HORIZONTAL", CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2)) then return end
	if tex.SetGradientAlpha and pcall(tex.SetGradientAlpha, tex, "HORIZONTAL", r1, g1, b1, a1, r2, g2, b2, a2) then return end
	tex:SetColorTexture(r1, g1, b1, (a1 + a2) / 2)
end

-- a 1px border of four textures (crisper than a backdrop edge at any UI scale)
function W.edge(f, r, g, b, a, layer)
	f.edges = f.edges or {}
	local spec = { { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }
	for i, s in ipairs(spec) do
		local t = f.edges[i] or f:CreateTexture(nil, layer or "BORDER")
		t:ClearAllPoints()
		t:SetPoint(s[1]) t:SetPoint(s[2])
		if s[3] then t:SetWidth(s[3]) end
		if s[4] then t:SetHeight(s[4]) end
		t:SetColorTexture(r, g, b, a or 1)
		f.edges[i] = t
	end
	function f:SetEdgeColor(r2, g2, b2, a2) for _, t in ipairs(self.edges) do t:SetColorTexture(r2, g2, b2, a2 or 1) end end
	return f.edges
end

-- the header bar: dark brown, a lighter top line, bronze edge
function W.bar(f)
	f.barBG = f.barBG or f:CreateTexture(nil, "BACKGROUND")
	f.barBG:SetAllPoints()
	W.gradient(f.barBG, 0.24, 0.14, 0.05, 0.98, 0.13, 0.075, 0.03, 0.98)
	f.barShine = f.barShine or f:CreateTexture(nil, "BORDER")
	f.barShine:SetPoint("TOPLEFT", 1, -1) f.barShine:SetPoint("TOPRIGHT", -1, -1)
	f.barShine:SetHeight(8)
	W.gradient(f.barShine, 1, 0.85, 0.5, 0.10, 1, 0.85, 0.5, 0.02)
	W.edge(f, 0.62, 0.48, 0.22, 1)
	return f
end

-- the selection mark: a warm wash and a gold line along the bottom that fades out to the right
function W.selectMark(f)
	local wash = f:CreateTexture(nil, "BACKGROUND", nil, 2)
	wash:SetAllPoints()
	W.gradient(wash, 1, 0.75, 0.25, 0.16, 1, 0.75, 0.25, 0.0)
	local line = f:CreateTexture(nil, "ARTWORK", nil, 2)
	line:SetPoint("BOTTOMLEFT", 0, 0) line:SetPoint("BOTTOMRIGHT", 0, 0)
	line:SetHeight(2)
	W.gradient(line, 1, 0.82, 0.1, 1, 1, 0.82, 0.1, 0)
	local mark = { wash = wash, line = line }
	function mark:SetShown(on) wash:SetShown(on) line:SetShown(on) end
	mark:SetShown(false)
	return mark
end

-- a soft light moving across a frame now and then (the queued banner); holder clips it
function W.sheen(holder, width, every)
	holder:SetClipsChildren(true)
	local inner = CreateFrame("Frame", nil, holder)
	inner:SetAllPoints()
	local t = inner:CreateTexture(nil, "OVERLAY")
	t:SetPoint("TOPLEFT", -width, 0) t:SetPoint("BOTTOMLEFT", -width, 0)
	t:SetWidth(width)
	t:SetBlendMode("ADD")
	W.gradient(t, 1, 0.9, 0.55, 0, 1, 0.9, 0.55, 0.35)
	local t2 = inner:CreateTexture(nil, "OVERLAY")
	t2:SetPoint("TOPLEFT", t, "TOPRIGHT") t2:SetPoint("BOTTOMLEFT", t, "BOTTOMRIGHT")
	t2:SetWidth(width / 2)
	t2:SetBlendMode("ADD")
	W.gradient(t2, 1, 0.9, 0.55, 0.35, 1, 0.9, 0.55, 0)
	local g = inner:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	local m = g:CreateAnimation("Translation")
	m:SetOffset(holder:GetWidth() + width * 2, 0) m:SetDuration(1.1) m:SetSmoothing("IN_OUT") m:SetOrder(1)
	local wait = g:CreateAnimation("Alpha") wait:SetFromAlpha(1) wait:SetToAlpha(1) wait:SetDuration(every or 3) wait:SetOrder(2)
	g.move = m
	holder:HookScript("OnSizeChanged", function(self, w) m:SetOffset((w or self:GetWidth()) + width * 2, 0) end)
	return g
end

-- the colour of a dungeon name by level, as the game's Group Finder does
function W.levelText(id, lvl)
	local A = OpenGroup_Activities
	if not A or not A.get(id) then return "?" end
	local hex = A.levelColor(id, lvl or UnitLevel("player"))
	local r = A.range(id)
	return hex .. (A.name(id) or "?") .. (r ~= "" and ("  " .. r) or "") .. "|r"
end
