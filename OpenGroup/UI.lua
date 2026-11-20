-- The OpenGroup window, laid out like the game's own Looking For Group window: a portrait frame with
-- side tabs (Browse, List a group, Network), Category / activity dropdowns, Groups and Players
-- sections, round role buttons, category banners and a typed dungeon search.
local L = OpenGroup
local P = OpenGroup_Proto
local A = OpenGroup_Activities
local W = OpenGroup_Widgets
local Q = OpenGroup_Quests
local SUMMON_ICON = "Interface\\Icons\\Spell_Shadow_Twilight"
local BGQ_ICON = (UnitFactionGroup("player") == "Horde") and "Interface\\Icons\\INV_BannerPVP_01" or "Interface\\Icons\\INV_BannerPVP_02"
local function isBGQ(cat) return P.isBGQ(cat) end
local function bgNames(l)
	local out = {}
	for _, id in ipairs(l.acts or {}) do out[#out + 1] = A.name(id) or "?" end
	if #out == 0 then out[1] = (l.title ~= "" and l.title) or "a battleground" end
	return table.concat(out, ", ")
end
local function coins(copper)
	if not copper or copper <= 0 then return "Free" end
	if GetCoinTextureString then return GetCoinTextureString(copper) end
	return ("%dg %ds"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100)
end
local GOLD, GREY, GREEN, WHITE = W.GOLD, W.GREY, W.GREEN, W.WHITE

local WIDTH, HEIGHT = 540, 640
local ROW_H, HEAD_H = 46, 30
local COMPACT_ROW_H, COMPACT_HEAD_H = 24, 26
local ROLES = { P.TANK, P.HEALER, P.DAMAGE }

local function has(bits, b) return (bits or 0) % (b * 2) >= b end
local function ago(sec) sec = math.max(0, sec) return sec < 60 and (sec .. "s") or (math.floor(sec / 60) .. "m") end
local function db() return OpenGroupDB end
-- the roles we play: our solo listing's, else the ones last picked for a solo listing (0 = let
-- our class decide)
local function myRoles()
	if L.mine and GetNumGroupMembers() <= 1 then return L.mine.need or 0 end
	local d = db() and db().draft
	return type(d) == "table" and P.int(d.need, 0, 7) or 0
end
-- the open spot we'd fit best, or nil
local function myFit(spots)
	if GetNumGroupMembers() > 1 then return nil end
	local i = P.bestSpot(spots, select(2, UnitClass("player")), UnitLevel("player"), myRoles())
	return i
end

-- --------------------------------------------------------------------------------------------
-- frame

local win = CreateFrame("Frame", "OpenGroupFrame", UIParent, "PortraitFrameTemplate")
win:SetSize(WIDTH, HEIGHT)
win:SetPoint("CENTER")
win:SetFrameStrata("HIGH")
win:SetToplevel(true)
win:SetMovable(true)
win:SetClampedToScreen(true)
win:EnableMouse(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart", win.StartMoving)
local function savePlace()
	local x, y = win:GetCenter()
	local ux, uy = UIParent:GetCenter()
	if x and ux then db().pos = { x - ux, y - uy } end
end
win:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	savePlace()
end)

-- drag the bottom-right corner to resize; the default size is also the smallest
local MAX_W, MAX_H = 1100, 1000
win:SetResizable(true)
if win.SetResizeBounds then win:SetResizeBounds(WIDTH, HEIGHT, MAX_W, MAX_H)
elseif win.SetMinResize then win:SetMinResize(WIDTH, HEIGHT) win:SetMaxResize(MAX_W, MAX_H) end
local grip = CreateFrame("Button", nil, win)
grip:SetSize(16, 16)
grip:SetPoint("BOTTOMRIGHT", -4, 4)
grip:SetFrameLevel(win:GetFrameLevel() + 30)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
grip:SetScript("OnMouseDown", function(_, button)
	if button ~= "LeftButton" then return end
	-- pin the top-left corner first: sizing a frame anchored by its centre grows it both ways at once
	local l, t = win:GetLeft(), win:GetTop()
	if l and t then win:ClearAllPoints() win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t) end
	win.sizing = true
	win:StartSizing("BOTTOMRIGHT")
end)
grip:SetScript("OnMouseUp", function()
	win:StopMovingOrSizing()
	win.sizing = nil
	-- lay out once at the new size (not on every pixel of the drag)
	if win.afterSizing then win.afterSizing() end
	local w, h = win:GetSize()
	if w and h then db().size = { math.floor(w + 0.5), math.floor(h + 0.5) } end
	savePlace()
end)
local function restoreSize()
	local sz = db().size
	local w, h = type(sz) == "table" and tonumber(sz[1]), type(sz) == "table" and tonumber(sz[2])
	if w and h and w == w and h == h then
		win:SetSize(math.min(math.max(w, WIDTH), MAX_W), math.min(math.max(h, HEIGHT), MAX_H))
	end
end
win:Hide()
tinsert(UISpecialFrames, "OpenGroupFrame")
if win.SetTitle then win:SetTitle("OpenGroup  |cff9d9d9d" .. L.VERSION .. "|r") end
pcall(function() win:SetPortraitToAsset(L.ICON) end)
if win.CloseButton then win.CloseButton:SetScript("OnClick", function() win:Hide() end) end

-- the body well every tab draws into (the Group Finder's inset, below a header strip)
local HEADER_H = 84
local body = CreateFrame("Frame", nil, win, "InsetFrameTemplate")
body:SetPoint("TOPLEFT", 4, -(24 + HEADER_H))
body:SetPoint("BOTTOMRIGHT", -6, 40)
-- the game's Group Finder look (read off its window with /og art): a header strip behind the top
-- of each page, and the inset's own background and ornate border. Kept as the template is where
-- the client lacks them.
if W.hasAtlas("groupfinder-background") and W.hasAtlas("common-insideframe") then
	if body.Bg then body.Bg:Hide() end
	if body.NineSlice then body.NineSlice:Hide() end
	body.customBG = body:CreateTexture(nil, "BACKGROUND")
	body.customBG:SetPoint("TOPLEFT", 2, -3)
	body.customBG:SetPoint("BOTTOMRIGHT", -2, 3)
	body.customBG:SetAtlas("groupfinder-background")
	body.border = body:CreateTexture(nil, "BORDER")
	body.border:SetPoint("TOPLEFT", 0, 0)
	body.border:SetPoint("BOTTOMRIGHT", 0, 0)
	body.border:SetAtlas("common-insideframe")
end
local strip = win:CreateTexture(nil, "BORDER")
strip:SetPoint("TOPLEFT", 2, -21)
strip:SetPoint("BOTTOMRIGHT", body, "TOPRIGHT", 4, -2)
if W.hasAtlas("groupfinder-roles-background") then strip:SetAtlas("groupfinder-roles-background") else strip:Hide() end

local pages, tabs = {}, {}
local function page(key)
	local header = CreateFrame("Frame", nil, win)
	header:SetPoint("TOPLEFT", 60, -24)
	header:SetPoint("TOPRIGHT", -8, -24)
	header:SetHeight(HEADER_H)
	local content = CreateFrame("Frame", nil, body)
	content:SetPoint("TOPLEFT", 0, 0)
	content:SetPoint("BOTTOMRIGHT", 0, 0)
	local footer = CreateFrame("Frame", nil, win)
	footer:SetPoint("BOTTOMLEFT", 6, 6)
	footer:SetPoint("BOTTOMRIGHT", -24, 6)
	footer:SetHeight(30)
	local pg = { key = key, header = header, content = content, footer = footer }
	pages[key] = pg
	return pg
end

-- while listed, the queued banner sits at the top of the body and every page starts below it
local QBAR_H = 0
local function placeContent()
	for _, pg in pairs(pages) do
		pg.content:ClearAllPoints()
		pg.content:SetPoint("TOPLEFT", 0, -QBAR_H)
		pg.content:SetPoint("BOTTOMRIGHT", 0, 0)
	end
end

local function showPage(key)
	body:SetPoint("TOPLEFT", 4, -(24 + (pages[key].headerH or HEADER_H)))
	body:SetPoint("BOTTOMRIGHT", -6, pages[key].bodyBottom or 40)
	for k, pg in pairs(pages) do
		local on = k == key
		pg.header:SetShown(on) pg.content:SetShown(on) pg.footer:SetShown(on)
		if tabs[k] and tabs[k].SetChecked then tabs[k]:SetChecked(on) end
	end
	local changed = db().tab ~= key
	db().tab = key
	if pages[key].onShow then pages[key].onShow() end
	if changed and win:IsShown() then
		W.fadeIn(pages[key].header, 0.2) W.fadeIn(pages[key].content, 0.25)
		W.sound("IG_CHARACTER_INFO_TAB")
	end
end

-- side tabs, the game's own (LargeSideTabButtonTemplate), with a plain fallback
local function sideTab(key, icon, tip, prev)
	local ok, t = pcall(CreateFrame, "Frame", nil, win, "LargeSideTabButtonTemplate")
	if ok and t and t.Icon then
		t.Icon:SetTexture(icon)
		t.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		t.Icon:SetSize(30, 30)
		if t.SetFillToInterior then t:SetFillToInterior(true) end
		t.tooltipText = tip
		t:SetCustomOnMouseUpHandler(function(_, button, up) if button == "LeftButton" and up then showPage(key) L.scan.auto(false) end end)
	else
		t = CreateFrame("CheckButton", nil, win)
		t:SetSize(40, 40)
		local tex = t:CreateTexture(nil, "ARTWORK") tex:SetAllPoints() tex:SetTexture(icon)
		t:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
		t:SetScript("OnClick", function() showPage(key) L.scan.auto(false) end)
		t:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:SetText(tip) GameTooltip:Show() end)
		t:SetScript("OnLeave", GameTooltip_Hide)
	end
	if prev then t:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4) else t:SetPoint("TOPLEFT", win, "TOPRIGHT", 0, -60) end
	tabs[key] = t
	return t
end

-- --------------------------------------------------------------------------------------------
-- BROWSE

local browse = page("browse")
browse.headerH = 38
browse.header:SetHeight(38)
local filterCat = nil         -- category id, nil = all
local filterActs = {}         -- [activityID] = true
local selected = nil          -- leader name of the selected row
local collapsed = {}          -- ["groups"|"players"] = true
local asked = {}              -- [leader] = true

-- Search: the game's red button. One click = one Group Finder search (the category Browse is
-- filtered to, else dungeons and the rest in turn), and it asks the OpenGroup players you know
-- what's listed. Reads "Search Group Finder" while its results are missing or old.
local refreshBtn = CreateFrame("Button", nil, browse.header, "UIPanelButtonTemplate")
refreshBtn:SetSize(132, 22)
refreshBtn:SetText("Search Group Finder")
function browse.searchClick()
	L.askAll()
	-- one click-only call per click: the Group Finder search, else (too soon) a /who
	L.scan.auto(true, true, true, filterCat)
	L.onChange()
	W.sound("U_CHAT_SCROLL_BUTTON")
end
refreshBtn:SetScript("OnClick", function() browse.searchClick() end)
refreshBtn:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	GameTooltip:SetText(self:GetText())
	GameTooltip:AddLine("Searches the game's Group Finder on your server, one category per click, and asks the OpenGroup players you know what's listed. The game only lets addons search when you click.", 1, 1, 1, true)
	GameTooltip:Show()
end)
refreshBtn:SetScript("OnLeave", GameTooltip_Hide)

-- one row, like the game's crafting window: a search box, a Filter button (with a red X while any
-- filter is set), and Refresh. The Filter menu holds Category, Activity, Where, Group by, All
-- levels and Compact.
browse.WHERE = { { "all", "All" }, { "other", "Other servers" }, { "mine", "Your server" }, { "finder", "Group Finder" }, { "chat", "LFG chat" }, { "og", "OpenGroup players" } }
browse.GROUPS = { { "act", "Activity" }, { "shard", "Server" }, { "off", "Off" } }
browse.search = ""
browse.HEADER_H = 38

function browse.filtersActive()
	local d = db() or {}
	return filterCat ~= nil or next(filterActs) ~= nil or (d.where or "all") ~= "all" or d.allLevels == true
end
function browse.resetFilters()
	filterCat, filterActs = nil, {}
	db().where, db().allLevels = "all", false
	W.sound("IG_MAINMENU_OPTION_CHECKBOX_OFF")
	L.onChange()
end
-- the menu; submenus where the client's menus have them, else titled sections
function browse.buildFilter(root)
	local function section(text)
		if root.CreateButton then
			local ok, b = pcall(root.CreateButton, root, text)
			if ok and type(b) == "table" and b.CreateRadio then return b end
		end
		if root.CreateTitle then root:CreateTitle(text) end
		return root
	end
	local c = section("Category")
	c:CreateRadio("All categories", function() return filterCat == nil end, function() filterCat = nil filterActs = {} L.onChange() end)
	for _, cat in ipairs(A.load()) do
		c:CreateRadio(cat.name, function() return filterCat == cat.id end, function() filterCat = cat.id filterActs = {} L.onChange() end)
	end
	local a = section("Activity")
	if a ~= root and a.SetScrollMode then pcall(a.SetScrollMode, a, 420) end
	local lvl = UnitLevel("player")
	for _, cat in ipairs(A.load()) do
		if (not filterCat or cat.id == filterCat) and #cat.acts > 0 then
			if not filterCat and a.CreateTitle then a:CreateTitle(cat.name) end
			for _, id in ipairs(cat.acts) do
				a:CreateCheckbox(W.levelText(id, lvl), function() return filterActs[id] == true end,
					function() filterActs[id] = (not filterActs[id]) or nil L.onChange() end)
			end
		end
	end
	local w = section("Where")
	for _, o in ipairs(browse.WHERE) do
		w:CreateRadio(o[2], function() return (db().where or "all") == o[1] end, function()
			db().where = o[1]
			if o[1] == "finder" or o[1] == "chat" or o[1] == "all" then db().nearby = nil end
			L.onChange()
		end)
	end
	-- the Group Finder search's languages (Search sends them; results don't say which they are)
	local Nb = OpenGroup_Nearby
	local lg = section("Language")
	lg:CreateCheckbox("All languages", function() return Nb.allLanguages() end, function() db().langAll = not Nb.allLanguages() L.onChange() end)
	local locked = Nb.lockedLanguages()
	for _, code in ipairs(Nb.offeredLanguages()) do
		if locked[code] then
			lg:CreateCheckbox(Nb.languageName(code) .. GREY .. " (always)|r", function() return true end, function() end)
		else
			lg:CreateCheckbox(Nb.languageName(code), function() return Nb.allLanguages() or (type(db().langs) == "table" and db().langs[code] == true) end, function()
				if Nb.allLanguages() then
					-- unticking one from All: keep the rest
					db().langAll = false
					db().langs = {}
					for _, c2 in ipairs(Nb.offeredLanguages()) do if c2 ~= code then db().langs[c2] = true end end
				else
					db().langs = type(db().langs) == "table" and db().langs or {}
					db().langs[code] = (not db().langs[code]) or nil
				end
				L.onChange()
			end)
		end
	end
	local g = section("Group by")
	for _, o in ipairs(browse.GROUPS) do
		g:CreateRadio(o[2], function() return (db().groupBy or "act") == o[1] end, function() db().groupBy = o[1] collapsed = {} L.onChange() end)
	end
	if root.CreateDivider then root:CreateDivider() end
	root:CreateCheckbox("All levels", function() return db().allLevels == true end, function() db().allLevels = not db().allLevels L.onChange() end)
	root:CreateCheckbox("Compact rows", function() return db().compact == true end, function() db().compact = not db().compact L.onChange() end)
end

local searchBox = CreateFrame("EditBox", nil, browse.header, "SearchBoxTemplate")
searchBox:SetHeight(22)
searchBox:SetAutoFocus(false)
if searchBox.Instructions then searchBox.Instructions:SetText("Search names, activities or notes, or shift-click a quest") end
searchBox:HookScript("OnTextChanged", function(self)
	local t = (self:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if t ~= browse.search then browse.search = t L.onChange() end
end)
searchBox:SetScript("OnEnterPressed", searchBox.ClearFocus)
browse.searchBox = searchBox

local okF, filterBtn = pcall(CreateFrame, "DropdownButton", nil, browse.header, "WowStyle1FilterDropdownTemplate")
if okF and filterBtn and filterBtn.SetupMenu then
	filterBtn:SetupMenu(function(_, root) browse.buildFilter(root) end)
	if filterBtn.SetIsDefaultCallback then filterBtn:SetIsDefaultCallback(function() return not browse.filtersActive() end) end
	if filterBtn.SetDefaultCallback then filterBtn:SetDefaultCallback(browse.resetFilters) end
else
	filterBtn = W.dropdown(browse.header, 94, "Filter", browse.buildFilter)
end
filterBtn:SetWidth(94)
-- the red X to clear filters, where the template doesn't bring its own
if not filterBtn.ResetButton then
	local x = CreateFrame("Button", nil, filterBtn)
	x:SetSize(18, 18)
	x:SetPoint("CENTER", filterBtn, "TOPRIGHT", -4, -4)
	x:SetFrameLevel(filterBtn:GetFrameLevel() + 5)
	if W.hasAtlas("auctionhouse-ui-filter-redx") then x:SetNormalAtlas("auctionhouse-ui-filter-redx")
	else x.t = x:CreateFontString(nil, "OVERLAY", "GameFontNormal") x.t:SetPoint("CENTER") x.t:SetText("|cffff4040x|r") end
	x:SetScript("OnClick", browse.resetFilters)
	x:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:SetText("Clear filters") GameTooltip:Show() end)
	x:SetScript("OnLeave", GameTooltip_Hide)
	x:Hide()
	browse.filterX = x
end
browse.filterBtn = filterBtn

refreshBtn:ClearAllPoints()
refreshBtn:SetPoint("TOPRIGHT", -2, -4)
filterBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -8, 0)
searchBox:SetPoint("LEFT", browse.header, "TOPLEFT", 8, -19)
searchBox:SetPoint("RIGHT", filterBtn, "LEFT", -12, 0)

-- shift-clicked quest: only people on it
local questFilter = nil
local chip = CreateFrame("Button", nil, browse.header)
chip:Hide()


local box = CreateFrame("Frame", nil, browse.content, "WowScrollBoxList")
box:SetPoint("TOPLEFT", 6, -24)
box:SetPoint("BOTTOMRIGHT", -24, 6)

-- the column headers above the list: click one to sort by it, again to reverse, a third time for
-- the default order (what suits you best first)
browse.COL_LABELS = { cls = "", lvl = "Lvl", leader = "Leader", act = "Activity", levels = "Levels", size = "Size", needs = "Needs", where = "Where", age = "Age" }
browse.colHead = CreateFrame("Frame", nil, browse.content)
browse.colHead:SetHeight(18)
browse.colButtons = {}
for _, c in ipairs(L.COLUMNS) do
	if c.key ~= "cls" then
		local b = CreateFrame("Button", nil, browse.colHead)
		b:SetHeight(18)
		b.text = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		b.text:SetPoint("LEFT", 0, 0)
		b.text:SetText(browse.COL_LABELS[c.key])
		b.arrow = b:CreateTexture(nil, "ARTWORK")
		b.arrow:SetSize(9, 8)
		b.arrow:SetPoint("LEFT", b.text, "RIGHT", 3, 0)
		b.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
		b.arrow:Hide()
		b.hl = b:CreateTexture(nil, "HIGHLIGHT")
		b.hl:SetAllPoints()
		b.hl:SetColorTexture(1, 0.82, 0, 0.08)
		b.key = c.key
		b:SetScript("OnClick", function(self)
			local d = db()
			if d.sortKey ~= self.key then d.sortKey, d.sortDesc = self.key, false
			elseif not d.sortDesc then d.sortDesc = true
			else d.sortKey, d.sortDesc = nil, nil end
			W.sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
			L.onChange()
		end)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText("Sort by " .. browse.COL_LABELS[self.key]:lower())
			GameTooltip:AddLine("Click again to reverse, a third time to go back to what suits you best.", 1, 1, 1, true)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", GameTooltip_Hide)
		browse.colButtons[c.key] = b
	end
end
-- the row's inside starts 10 px in; the headers line up with it
function browse.layoutColumns(cols)
	for key, b in pairs(browse.colButtons) do
		local at = cols.at[key]
		if key == "lvl" and cols.at.cls then at = { x = cols.at.cls.x, w = cols.at.cls.w + L.COL_GAP + cols.at.lvl.w } end
		if at then
			b:ClearAllPoints()
			b:SetPoint("LEFT", browse.colHead, "LEFT", 10 + at.x, 0)
			b:SetWidth(math.max(12, at.w))
			b:Show()
		else
			b:Hide()
		end
		local on = db().sortKey == key
		b.text:SetTextColor(on and 1 or 0.85, on and 1 or 0.72, on and 1 or 0.3)
		b.arrow:SetShown(on)
		if on then if db().sortDesc then b.arrow:SetTexCoord(0, 0.5625, 1, 0) else b.arrow:SetTexCoord(0, 0.5625, 0, 1) end end
	end
end

-- the quest card: when a quest is picked (shift-click), it sits above the list like a page from
-- the quest log: the quest's level and name in its difficulty colour, your objectives, how many
-- people are on it, and a button to list yourself for it
local qcard = CreateFrame("Frame", nil, browse.content)
qcard:SetPoint("TOPLEFT", 8, -8)
qcard:SetPoint("TOPRIGHT", -8, -8)
qcard:SetHeight(76)
qcard.bg = qcard:CreateTexture(nil, "BACKGROUND")
qcard.bg:SetAllPoints()
W.gradient(qcard.bg, 0.22, 0.17, 0.08, 0.97, 0.1, 0.08, 0.04, 0.97)
qcard.border = CreateFrame("Frame", nil, qcard, BackdropTemplateMixin and "BackdropTemplate" or nil)
qcard.border:SetPoint("TOPLEFT", -5, 5) qcard.border:SetPoint("BOTTOMRIGHT", 5, -5)
if qcard.border.SetBackdrop then
	qcard.border:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16 })
	qcard.border:SetBackdropBorderColor(0.8, 0.65, 0.4, 1)
end
qcard.icon = qcard:CreateTexture(nil, "ARTWORK")
qcard.icon:SetSize(32, 32)
qcard.icon:SetPoint("TOPLEFT", 10, -10)
qcard.icon:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
qcard.title = qcard:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
qcard.title:SetPoint("TOPLEFT", qcard.icon, "TOPRIGHT", 8, -2)
qcard.title:SetJustifyH("LEFT")
qcard.title:SetWordWrap(false)
qcard.objs = qcard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
qcard.objs:SetPoint("TOPLEFT", qcard.title, "BOTTOMLEFT", 0, -5)
qcard.objs:SetJustifyH("LEFT")
qcard.objs:SetSpacing(2)
qcard.close = CreateFrame("Button", nil, qcard, "UIPanelCloseButton")
qcard.close:SetSize(24, 24)
qcard.close:SetPoint("TOPRIGHT", -2, -2)
qcard.list = CreateFrame("Button", nil, qcard, "UIPanelButtonTemplate")
qcard.list:SetSize(130, 22)
qcard.list:SetPoint("BOTTOMRIGHT", -10, 8)
qcard.list:SetText("List me for it")
qcard.count = qcard:CreateFontString(nil, "ARTWORK", "GameFontNormal")
qcard.count:SetPoint("BOTTOMRIGHT", qcard.list, "TOPRIGHT", 0, 6)
qcard.title:SetPoint("RIGHT", qcard.close, "LEFT", -6, 0)
qcard.objs:SetPoint("RIGHT", qcard.list, "LEFT", -10, 0)
qcard:Hide()
local bar = CreateFrame("EventFrame", nil, browse.content, "MinimalScrollBar")
bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, 0)
bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 0)

local emptyArt = browse.content:CreateTexture(nil, "ARTWORK")
emptyArt:SetSize(72, 72)
emptyArt:SetPoint("CENTER", 0, 92)
emptyArt:SetTexture(L.ICON)
emptyArt:SetDesaturated(true)
emptyArt:SetAlpha(0.35)
W.pulse(emptyArt, 0.12, 1.6):Play()
-- in the empty list: the same search, in reach
local emptySearch = CreateFrame("Button", nil, browse.content, "UIPanelButtonTemplate")
emptySearch:SetSize(170, 26)
emptySearch:SetText("Search Group Finder")
emptySearch:SetScript("OnClick", function() browse.searchClick() end)
emptySearch:Hide()
browse.emptySearch = emptySearch
local empty = browse.content:CreateFontString(nil, "ARTWORK", "GameFontDisable")
empty:SetPoint("CENTER", 0, 20)
empty:SetWidth(400)
empty:SetSpacing(4)

local function listingTitle(l) return L.titleOf(l) end

-- Listings that fit what we're listed for: the same dungeon (any overlap), the same quest, or the
-- same Custom title. A group leader sees matching players; a solo player sees matching groups.
local function sameThing(m, l)
	if (m.quest or 0) > 0 then return l.quest == m.quest end
	for _, a in ipairs(m.acts or {}) do for _, b in ipairs(l.acts or {}) do if a == b then return true end end end
	if #(m.acts or {}) == 0 and (m.title or "") ~= "" then return (l.title or ""):lower() == m.title:lower() end
	return false
end
local function iAmLeader() return GetNumGroupMembers() > 1 end
local function matchesMine(l)
	local m = L.mine
	if not m or m.cat == P.SUMMON_CAT or l.cat == P.SUMMON_CAT or L.isMe(l.leader) then return false end
	-- battleground queues: offers match requests for the same battleground, and the other way round
	if isBGQ(m.cat) or isBGQ(l.cat) then
		if not (isBGQ(m.cat) and isBGQ(l.cat) and m.cat ~= l.cat) then return false end
		if #(m.acts or {}) == 0 or #(l.acts or {}) == 0 then return true end
		return sameThing(m, l)
	end
	if iAmLeader() ~= (l.size <= 1) then return false end   -- leaders want players, players want groups
	return sameThing(m, l)
end
-- does this listing bring (or want) a role we want (or bring)?
local function roleFit(l)
	local m = L.mine
	if not m then return false end
	for _, r in ipairs(ROLES) do if has(m.need, r) and has(l.need, r) then return true end end
	return false
end

local function buildRow(row)
	-- header parts: the profession-window bar (dark brown, bronze edge, gold title, minus/plus)
	row.head = CreateFrame("Frame", nil, row)
	row.head:SetPoint("TOPLEFT", 2, -3) row.head:SetPoint("BOTTOMRIGHT", -2, 3)
	W.bar(row.head)
	row.headText = row.head:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	row.headText:SetPoint("LEFT", 12, 0)
	row.headText:SetPoint("RIGHT", -40, 0)
	row.headText:SetJustifyH("LEFT")
	row.headText:SetWordWrap(false)
	row.headSign = row.head:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
	row.headSign:SetPoint("RIGHT", -14, 1)
	row.headBar = row.head:CreateTexture(nil, "ARTWORK")
	row.headBar:SetSize(18, 4)
	row.headBar:SetPoint("RIGHT", -14, 0)
	row.headBar:SetColorTexture(1, 0.82, 0, 1)
	row.headBar2 = row.head:CreateTexture(nil, "ARTWORK")
	row.headBar2:SetSize(4, 18)
	row.headBar2:SetPoint("CENTER", row.headBar, "CENTER")
	row.headBar2:SetColorTexture(1, 0.82, 0, 1)
	-- listing parts: a dark panel with a thin edge, warm and gold-underlined when selected
	row.panel = CreateFrame("Frame", nil, row)
	row.panel:SetPoint("TOPLEFT", 2, -2) row.panel:SetPoint("BOTTOMRIGHT", -2, 2)
	row.panel:SetFrameLevel(math.max(0, row:GetFrameLevel() - 1))
	row.panel.bg = row.panel:CreateTexture(nil, "BACKGROUND")
	row.panel.bg:SetAllPoints()
	W.gradient(row.panel.bg, 0.11, 0.08, 0.05, 0.95, 0.06, 0.045, 0.035, 0.95)
	W.edge(row.panel, 0.36, 0.29, 0.2, 1)
	row.mark = W.selectMark(row.panel)
	row.accent = row.panel:CreateTexture(nil, "ARTWORK")
	row.accent:SetPoint("TOPLEFT", 1, -1) row.accent:SetPoint("BOTTOMLEFT", 1, 1)
	row.accent:SetWidth(3)
	row.bg = row.panel   -- shown/hidden with the listing parts
	row.sel = row:CreateTexture(nil, "BACKGROUND")   -- kept for setListingShown; the mark carries selection
	row.sel:SetColorTexture(0, 0, 0, 0)
	row.hl = row:CreateTexture(nil, "HIGHLIGHT")
	row.hl:SetPoint("TOPLEFT", 5, -5) row.hl:SetPoint("BOTTOMRIGHT", -5, 5)
	row.hl:SetColorTexture(1, 0.9, 0.6, 0.06)
	row.hl:SetBlendMode("ADD")
	-- one part per column; each is placed from the column layout (browse.cols)
	local function fs(font, justify)
		local f = row:CreateFontString(nil, "ARTWORK", font)
		f:SetJustifyH(justify or "LEFT")
		f:SetWordWrap(false)
		return f
	end
	row.class = row:CreateTexture(nil, "ARTWORK")
	row.class:SetSize(16, 16)
	row.level = fs("GameFontHighlightSmall", "RIGHT")
	row.name = fs("GameFontNormal")
	row.act = fs("GameFontHighlight")
	row.levels = fs("GameFontHighlightSmall")
	row.size = fs("GameFontHighlightSmall")
	row.shard = fs("GameFontNormalSmall")
	row.age = fs("GameFontDisableSmall", "RIGHT")
	row.note = fs("GameFontNormalSmall")
	row.note:SetTextColor(0.25, 1, 0.25)
	row.rolesLabel = fs("GameFontHighlight")   -- the summons / queue icon in the Needs column
	row.roles = {}
	for i = 1, P.MAX_SPOTS do row.roles[i] = row:CreateTexture(nil, "ARTWORK") end
	row.askCheck = row:CreateTexture(nil, "OVERLAY")
	row.askCheck:SetSize(14, 14)
	row.askCheck:SetAtlas("groupfinder-icon-greencheckmark")

	-- new-listing entrance: slide in from the right, fade up, a gold flash that fades out
	row.flash = row:CreateTexture(nil, "OVERLAY")
	row.flash:SetPoint("TOPLEFT", 3, -3) row.flash:SetPoint("BOTTOMRIGHT", -3, 1)
	row.flash:SetColorTexture(1, 0.82, 0.2, 1)
	row.flash:SetBlendMode("ADD")
	row.flash:SetAlpha(0)
	local fg = row.flash:CreateAnimationGroup()
	local fa = fg:CreateAnimation("Alpha") fa:SetFromAlpha(0.45) fa:SetToAlpha(0) fa:SetDuration(1.2) fa:SetSmoothing("OUT")
	row.flashAnim = fg
	local eg = row:CreateAnimationGroup()
	local t1 = eg:CreateAnimation("Translation") t1:SetOffset(24, 0) t1:SetDuration(0) t1:SetOrder(1)
	local t2 = eg:CreateAnimation("Translation") t2:SetOffset(-24, 0) t2:SetDuration(0.28) t2:SetOrder(2) t2:SetSmoothing("OUT")
	local a1 = eg:CreateAnimation("Alpha") a1:SetFromAlpha(0) a1:SetToAlpha(1) a1:SetDuration(0.28) a1:SetOrder(2)
	row.enterAnim = eg

	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetScript("OnClick", function(self, button)
		local d = self.data
		if not d then return end
		if button == "RightButton" then
			if d.l then selected = d.l.leader L.onChange() browse.personMenu(self, d.l.leader, d.l) end
			return
		end
		if d.header then collapsed[d.header] = not collapsed[d.header] W.sound("IG_MAINMENU_OPTION_CHECKBOX_ON") L.onChange() return end
		selected = d.l.leader
		W.sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
		L.onChange()
	end)
	row:SetScript("OnDoubleClick", function(self)
		local d = self.data
		if d and d.l then selected = d.l.leader browse.primary() end
	end)
	row:SetScript("OnEnter", function(self)
		local d = self.data
		if not d or not d.l then return end
		local l, r = d.l, d.r
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(listingTitle(l), 1, 1, 1, true)
		if #(l.acts or {}) > 1 then
			GameTooltip:AddLine("Queued for:", 1, .82, 0)
			for _, id in ipairs(l.acts) do GameTooltip:AddLine("  " .. (A.name(id) or ("activity " .. id)) .. (r and id == r.act and "  <" or ""), .8, .8, .8) end
		end
		if r and r.min > 0 then GameTooltip:AddLine(("Levels %s"):format(r.min == r.max and r.min or (r.min .. " to " .. r.max)), .8, .8, .8) end
		if l.note ~= "" then GameTooltip:AddLine(l.note, .25, 1, .25, true) end
		if l.size > 1 and type(l.spots) == "table" and #l.spots > 0 then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(myFit(l.spots) and "Open spots (you fit one)" or "Open spots", 1, .82, 0)
			for _, sp in ipairs(l.spots) do GameTooltip:AddLine("  " .. W.spotText(sp), .9, .9, .9) end
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(("%s%s|r%s"):format(W.classColor(l.class), L.short(l.leader), l.level > 0 and ("  level " .. l.level) or ""))
		GameTooltip:AddLine(("%s   |   %s"):format(OpenGroup_Nearby.whereTip(l.shard), l.size <= 1 and "solo" or l.sizeGuess and "a group" or (l.size .. " in group")), .8, .8, .8)
		if l.src == "remote" then GameTooltip:AddLine(("Seen in the Group Finder on " .. L.CHAN .. " %d by %s, %s ago"):format(l.shard, l.reporter or "?", ago(time() - (l.got or time()))), .5, .5, .5, true)
		elseif l.src == "remotechat" then GameTooltip:AddLine(("Posted in LookingForGroup on " .. L.CHAN .. " %d, passed on by %s, %s ago"):format(l.shard, l.reporter or "?", ago(time() - (l.got or time()))), .5, .5, .5, true)
		elseif l.src == "finder" then GameTooltip:AddLine("Listed in the game's Group Finder (your server only)", .5, .5, .5)
		elseif l.src == "chat" then GameTooltip:AddLine(("Posted in %s chat (your server only)"):format(l.chan or "a"), .5, .5, .5)
		else GameTooltip:AddLine(l.hops == 0 and "Heard from them directly" or ("Passed on by %s"):format(L.short(l.via)), .5, .5, .5) end
		if l.unconfirmed then GameTooltip:AddLine("Not confirmed by the leader yet. OpenGroup is checking with them.", 1, .6, .2, true) end
		if r and r.dim then GameTooltip:AddLine(l.size >= 5 and "This group is full." or "They don't need a role you play.", 1, .5, .3) end
		GameTooltip:AddLine(l.size > 1 and "Double-click to ask to join." or "Double-click to invite.", 0, 1, 0)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)
	row.built = true
end

-- place the parts on the columns. Roomy rows: one line of columns with the note under the activity;
-- compact rows: the line alone. Rows are recycled, so this runs on each fill (cheap when unchanged).
local function at(r, ...) r:ClearAllPoints() r:SetPoint(...) end
local function layoutRow(row, compact)
	local cols = browse.cols
	local sig = (cols and cols.sig or "") .. (compact and "c" or "r")
	if row.layoutSig == sig or not cols then return end
	row.layoutSig = sig
	local y = compact and 0 or 8
	local function put(part, key, justify)
		local c = cols.at[key]
		if not c then part:Hide() part.colHidden = true return end
		part.colHidden = nil
		at(part, "LEFT", row, "LEFT", 10 + c.x, y)
		if part.SetWidth and part.GetObjectType and part:GetObjectType() == "FontString" then part:SetWidth(c.w) end
	end
	row.name:SetFontObject(compact and "GameFontNormal" or "GameFontNormalLarge")
	row.act:SetFontObject(compact and "GameFontHighlight" or "GameFontHighlightLarge")
	row.class:SetSize(compact and 14 or 16, compact and 14 or 16)
	put(row.class, "cls") put(row.level, "lvl") put(row.name, "leader") put(row.act, "act")
	put(row.levels, "levels") put(row.size, "size") put(row.shard, "where") put(row.age, "age")
	local needs = cols.at.needs
	local s = compact and 15 or 17
	for i, t in ipairs(row.roles) do
		t:SetSize(s, s)
		at(t, "LEFT", row, "LEFT", 10 + needs.x + (i - 1) * (s + 2), y)
	end
	at(row.rolesLabel, "LEFT", row, "LEFT", 10 + needs.x, y)
	local actCol = cols.at.act
	at(row.note, "TOPLEFT", row, "LEFT", 10 + actCol.x, y - 8)
	local noteRight = cols.at.where or cols.at.needs
	row.note:SetWidth(math.max(60, (noteRight.x + noteRight.w) - actCol.x))
end

local function setListingShown(row, on)
	for _, r in ipairs({ row.bg, row.name, row.level, row.act, row.levels, row.size, row.note, row.shard, row.rolesLabel, row.age }) do r:SetShown(on) end
	for _, t in ipairs(row.roles) do t:SetShown(on) end
	if not on then row.class:Hide() row.sel:Hide() row.askCheck:Hide() row.hl:SetAlpha(0) else row.hl:SetAlpha(0.5) end
	row.head:SetShown(not on)
	row.headSign:Hide() row.headBar2:SetShown(false)
	row:SetAlpha(1)
end

local function rangeText(r, hex)
	if r.min <= 0 then return "" end
	return hex .. (r.min == r.max and tostring(r.min) or (r.min .. "-" .. r.max)) .. "|r"
end

local function fillRow(row, d)
	if not row.built then buildRow(row) end
	row.data = d
	if d.header then
		setListingShown(row, false)
		row.headText:SetText(d.text .. "  " .. GREY .. "(" .. d.count .. ")|r")
		row.headBar2:SetShown(collapsed[d.header] == true)
		return
	end
	setListingShown(row, true)
	local compact = db().compact == true
	layoutRow(row, compact)
	local l, r, myShard = d.l, d.r, L.shard()
	local lvl = UnitLevel("player")
	row.name:SetText(W.classColor(l.class) .. L.short(l.leader) .. "|r")
	row.level:SetText(l.level > 0 and tostring(l.level) or "")
	local atlas = W.classAtlas(l.class)
	if atlas and not row.class.colHidden then row.class:SetAtlas(atlas) row.class:Show() else row.class:Hide() end
	local acts = l.acts or {}
	local summon, bgq, quest = r.kind == "summon", r.kind == "bgq", (l.quest or 0) > 0
	-- the activity's colour: the game's difficulty colour for the range (white when there is none)
	local hex = WHITE
	if r.act then hex = A.levelColor(r.act, lvl)
	elseif quest and r.min > 0 and GetQuestDifficultyColor then
		local c = GetQuestDifficultyColor(r.min)
		if c then hex = ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) end
	end
	local note = l.note or ""
	if bgq then
		row.act:SetText((l.cat == P.BGQ_OFFER and "|cffff7060Can queue you for|r " or "|cffff7060Wants a queue for|r ") .. bgNames(l))
	elseif summon then
		row.act:SetText("|cffc8a0ffSummon to|r " .. l.title)
		note = GOLD .. coins(l.price) .. "|r" .. (note ~= "" and (GREY .. "  -  " .. note .. "|r") or "")
	elseif quest then
		row.act:SetText("|TInterface\\GossipFrame\\ActiveQuestIcon:14|t " .. hex .. listingTitle(l) .. "|r")
		if Q.onLog(l.quest) then note = "You're on this quest" .. (note ~= "" and ("  -  " .. note) or "") end
	elseif #acts > 1 and r.act then
		row.act:SetText(hex .. (A.name(r.act) or "?") .. "|r " .. GREY .. "+" .. (#acts - 1) .. "|r")
	elseif r.act then
		row.act:SetText(hex .. (A.name(r.act) or "?") .. "|r")
	else
		row.act:SetText(listingTitle(l))
	end
	row.levels:SetText(summon and (GOLD .. coins(l.price) .. "|r") or rangeText(r, hex))
	row.size:SetText(r.kind == "group" and (l.sizeGuess and (GREY .. "group|r") or (l.size .. "/5")) or r.kind == "player" and (GREY .. "solo|r") or "")
	row.note:SetText(note)
	row.note:SetShown(not compact and note ~= "")
	row.shard:SetText((r.where == "finder" and (GREY .. "Group Finder|r") or r.where == "chat" and (GREY .. (l.chan or "LFG chat") .. "|r")
		or r.where == "mine" and (GREY .. "Your server|r") or (GOLD .. OpenGroup_Nearby.whereText(l.shard) .. "|r")) .. (l.unconfirmed and (GREY .. " ?|r") or "")
		.. (r.gf and (GREY .. " GF|r") or ""))
	if r.chatPost then row.shard:SetText(GOLD .. "LFG " .. l.shard .. "|r") end
	-- Needs: one icon per open spot (the class where one is set), else the role bits; groups show
	-- what they want, players the roles they play
	local icons = {}
	local spots = (l.size > 1 and type(l.spots) == "table" and #l.spots > 0) and l.spots or nil
	if spots then
		for _, sp in ipairs(spots) do icons[#icons + 1] = { role = sp.role, class = sp.class } end
	elseif not (summon or bgq) then
		for _, b in ipairs(ROLES) do if has(l.need, b) then icons[#icons + 1] = { role = b } end end
	end
	for k, t in ipairs(row.roles) do
		local ic = icons[k]
		if ic then
			W.spotIcon(t, ic.role, ic.class)
			t:SetAlpha((not spots and d.match and not has(L.mine and L.mine.need or 0, ic.role)) and 0.3 or 1)
			t:Show()
		else
			t:Hide()
		end
	end
	if summon or bgq then
		row.rolesLabel:SetText(("|T%s:16|t"):format(summon and SUMMON_ICON or BGQ_ICON))
		row.rolesLabel:Show()
	else
		row.rolesLabel:Hide()
	end
	row.age:SetText(ago(time() - l.got))
	row.age:SetShown(not row.age.colHidden)
	row.size:SetShown(not row.size.colHidden)
	row.shard:SetShown(not row.shard.colHidden)
	local isSel = selected == l.leader
	row.mark:SetShown(isSel)
	row.panel:SetEdgeColor(isSel and 0.85 or 0.36, isSel and 0.68 or 0.29, isSel and 0.3 or 0.2, 1)
	-- the strip on the left: a match for your listing or a spot you fit (green), summons (purple),
	-- queues (red), your server's Group Finder and chat (blue), another shard (gold), yours (grey)
	if d.match then row.accent:SetColorTexture(0.25, 1, 0.25, 0.95)
	elseif r.fit then row.accent:SetColorTexture(0.4, 0.85, 0.4, 0.8)
	elseif summon then row.accent:SetColorTexture(0.62, 0.4, 1, 0.9)
	elseif bgq then row.accent:SetColorTexture(1, 0.35, 0.25, 0.9)
	elseif l.src then row.accent:SetColorTexture(0.45, 0.6, 0.8, 0.7)
	elseif l.shard ~= myShard then row.accent:SetColorTexture(1, 0.78, 0.2, 0.9)
	else row.accent:SetColorTexture(0.5, 0.5, 0.5, 0.6) end
	-- asked already: a small check after the name
	row.askCheck:ClearAllPoints()
	row.askCheck:SetPoint("LEFT", row.name, "LEFT", math.min(row.name:GetStringWidth() or 0, row.name:GetWidth() or 0) + 3, 0)
	row.askCheck:SetShown(asked[l.leader] == true)
	-- a group we can't join sits at the bottom, greyed
	row:SetAlpha(r.dim and 0.5 or 1)
	-- first time this listing (this version of it) is drawn while fresh: the entrance
	local key = l.leader .. ":" .. l.seq
	browse.seen = browse.seen or {}
	if not browse.seen[key] then
		browse.seen[key] = true
		if time() - l.got < 10 and browse.ready then
			row.enterAnim:Stop() row.enterAnim:Play()
			row.flashAnim:Stop() row.flashAnim:Play()
		end
	end
end

local view = CreateScrollBoxListLinearView()
view:SetElementExtentCalculator(function(_, d)
	local c = db().compact == true
	if d.header then return c and COMPACT_HEAD_H or HEAD_H end
	return c and COMPACT_ROW_H or ROW_H
end)
view:SetElementInitializer("Button", fillRow)
ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)

-- footer: Send Message | Ask to Join / Group Invite
local sendBtn = CreateFrame("Button", nil, browse.footer, "UIPanelButtonTemplate")
sendBtn:SetSize(150, 24)
sendBtn:SetPoint("LEFT", 0, 0)
sendBtn:SetText("Send Message")
local actBtn = CreateFrame("Button", nil, browse.footer, "UIPanelButtonTemplate")
actBtn:SetSize(150, 24)
actBtn:SetPoint("RIGHT", 0, 0)
local countText = browse.footer:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
countText:SetPoint("CENTER")

local function selectedListing() return selected and (L.listings[selected] or L.nearby[selected] or (L.remote and L.remote[selected])) end

local function openWhisper(name, text)
	local tell = ChatFrame_SendTell or (ChatFrameUtil and ChatFrameUtil.SendTell)
	if tell then
		tell(name)
		if text then
			local eb = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
			if eb then eb:Insert(text) end
		end
	end
end

sendBtn:SetScript("OnClick", function() local l = selectedListing() if l and browse.openWhisper then browse.openWhisper(l.leader) end end)

function browse.primary()
	local l = selectedListing()
	if not l then return end
	if l.cat == P.BGQ_OFFER then
		local text = ("Hi! Could you invite me and queue us for %s? (OpenGroup)"):format(bgNames(l))
		local ok = pcall(C_ChatInfo.SendChatMessage or SendChatMessage, text, "WHISPER", nil, l.leader)
		if not ok then openWhisper(l.leader, text) end
		asked[l.leader] = true
	elseif l.cat == P.BGQ_WANT then
		local inv = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
		if inv then pcall(inv, l.leader) end
		asked[l.leader] = true
	elseif l.cat == P.SUMMON_CAT then
		local g, sv = math.floor(l.price / 10000), math.floor(l.price / 100) % 100
		local price = l.price <= 0 and "free" or (g > 0 and (g .. "g" .. (sv > 0 and (" " .. sv .. "s") or "")) or (sv .. "s"))
		local text = ("Hi! Could I get a summon to %s? %s works for me (OpenGroup)"):format(l.title, price)
		local ok = pcall(C_ChatInfo.SendChatMessage or SendChatMessage, text, "WHISPER", nil, l.leader)
		if not ok then openWhisper(l.leader, text) end
		asked[l.leader] = true
	elseif l.size > 1 then
		local text = ("Hi! Inv please for %s (OpenGroup, " .. L.CHAN .. " %d)"):format(listingTitle(l), L.shard())
		if l.src then
			-- they may not have OpenGroup, and they're on our shard anyway
			local what = (#(l.acts or {}) > 0) and listingTitle(l) or "your group"
			text = ("Hi! Inv please for %s, I'm a level %d %s"):format(what, UnitLevel("player"), UnitClass("player") or "")
		end
		local ok = pcall(C_ChatInfo.SendChatMessage or SendChatMessage, text, "WHISPER", nil, l.leader)
		if not ok then openWhisper(l.leader, text) end
		-- an OpenGroup leader also gets our class, level and roles, so their auto invite can act on it
		if not l.src then
			local roles = myRoles()
			-- a group with open spots: ask as the role of the spot we fit best
			if type(l.spots) == "table" and #l.spots > 0 then
				local _, r = P.bestSpot(l.spots, select(2, UnitClass("player")), UnitLevel("player"), roles)
				if r then roles = r end
			end
			L.send(l.leader, P.join(select(2, UnitClass("player")), UnitLevel("player"), roles))
		end
		asked[l.leader] = true
	else
		local inv = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
		if inv then pcall(inv, l.leader) end
		asked[l.leader] = true
	end
	W.sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
	W.bounce(actBtn, 1.06)
	-- asks that go out as a whisper open that conversation (invites don't)
	if l.cat == P.BGQ_OFFER or l.cat == P.SUMMON_CAT or (l.size > 1 and not isBGQ(l.cat)) then
		if browse.openWhisper then browse.openWhisper(l.leader) end
	end
	L.onChange()
end
actBtn:SetScript("OnClick", browse.primary)

-- Right-click on a person (a Browse row or a Whispers contact): Whisper, Invite, Ask to Join (when
-- they lead a group with room), Open in Whispers, Add friend, Ignore. Each runs from the menu click.
function browse.personItems(name, l)
	local items = {}
	local function add(key, text, fn) items[#items + 1] = { key = key, text = text, fn = fn } end
	if not name or L.isMe(name) then return items end
	add("whisper", "Whisper", function() openWhisper(name) end)
	add("invite", "Invite", function()
		local inv = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
		if inv then inv(name) end
	end)
	if l and (l.size or 1) > 1 and (l.size or 1) < 5 and l.cat ~= P.SUMMON_CAT and not isBGQ(l.cat) then
		add("ask", "Ask to Join", function() selected = l.leader browse.primary() end)
	end
	add("open", "Open in Whispers", function() if browse.openWhisper then browse.openWhisper(name) end end)
	add("friend", "Add friend", function()
		if C_FriendList and C_FriendList.AddFriend then C_FriendList.AddFriend(name) elseif AddFriend then AddFriend(name) end
	end)
	add("ignore", "Ignore", function()
		if C_FriendList and C_FriendList.AddIgnore then C_FriendList.AddIgnore(name) elseif AddIgnore then AddIgnore(name) end
	end)
	return items
end
function browse.personMenu(owner, name, l)
	local items = browse.personItems(name, l)
	if #items == 0 then return end
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(owner, function(_, root)
			root:CreateTitle(W.classColor(l and l.class) .. L.short(name) .. "|r")
			for _, it in ipairs(items) do root:CreateButton(it.text, it.fn) end
		end)
	else
		local list = {}
		for _, it in ipairs(items) do list[#list + 1] = { text = it.text, value = it.fn } end
		W.popup():Open(owner, list, function(fn) fn() end, 160)
	end
end

local function matchesFilter(l)
	if questFilter and l.quest ~= questFilter.id then return false end
	if filterCat and l.cat ~= filterCat then
		-- older or fallback listings may carry no category: match by activity
		local hit = false
		for _, id in ipairs(l.acts or {}) do if A.get(id) and A.get(id).cat == filterCat then hit = true end end
		if not hit then return false end
	end
	if next(filterActs) then
		for _, id in ipairs(l.acts or {}) do if filterActs[id] then return true end end
		-- free-text listings: match the picked names in the title
		local t = (l.title or ""):lower()
		for id in pairs(filterActs) do local n = A.name(id) if n and t:find(n:lower(), 1, true) then return true end end
		return false
	end
	return true
end

-- what we are, for fitting rows: class, level, the roles we play, and our listing's needs
function browse.me()
	return { class = select(2, UnitClass("player")), level = UnitLevel("player") or 0, roles = myRoles(),
		grouped = GetNumGroupMembers() > 1, need = L.mine and L.mine.need or 0 }
end

function browse.refresh()
	local d0 = L.migrateBrowse(db())
	local myShard = L.shard()
	if browse.filterX then browse.filterX:SetShown(browse.filtersActive()) end
	if browse.filterBtn.ValidateResetState then pcall(browse.filterBtn.ValidateResetState, browse.filterBtn) end

	-- every listing, OpenGroup's and your server's (Group Finder, chat), as one kind of row
	local lvl, me = UnitLevel("player") or 0, browse.me()
	local rows, matches, total, outside = {}, {}, 0, 0
	-- someone queued for several: show them under the one you filtered or searched for
	local q0 = browse.search or ""
	local function prefer(id)
		if filterActs[id] then return true end
		if q0 == "" then return false end
		return A.searchText(id):find(q0, 1, true) ~= nil
	end
	local function consider(l)
		if L.ignored(l.leader) then return end
		total = total + 1
		local r = L.rowOf(l, myShard, prefer)
		r.dist = L.levelDistance(r, lvl)
		r.fit, r.dim = L.rowFit(r, me)
		if not L.whereOK(r, d0.where) or not matchesFilter(l) then return end
		-- the search box: names, activities and notes (searching looks at every level)
		local q = browse.search or ""
		if q ~= "" and not (r.leader .. " " .. tostring(r.title) .. " " .. tostring(r.groupName) .. " " .. (r.actNames or "") .. " " .. r.note):lower():find(q, 1, true) then return end
		if matchesMine(l) then matches[#matches + 1] = r return end
		if not d0.allLevels and q == "" and not questFilter and not filterActs[r.act or 0] and not L.inBand(r, lvl) then outside = outside + 1 return end
		rows[#rows + 1] = r
	end
	for _, l in pairs(L.listings) do consider(l) end
	for name, l in pairs(L.nearby) do
		if not L.listings[name] and not L.isMe(name) then consider(l) end
	end
	-- other servers' Group Finder groups
	for name, l in pairs(L.remote or {}) do
		if not L.listings[name] and not L.nearby[name] and not L.isMe(name) then consider(l) end
	end
	L.sortRows(rows, d0.sortKey, d0.sortDesc)
	L.sortRows(matches, nil, false)
	browse.matchCount = #matches

	local items = {}
	local function header(key, text, count) items[#items + 1] = { header = key, text = text, count = count } end
	local function add(list, match) for _, r in ipairs(list) do items[#items + 1] = { l = r.l, r = r, match = match } end end
	if #matches > 0 then
		local title = L.mine and isBGQ(L.mine.cat) and ((L.mine.cat == P.BGQ_OFFER and "Wanting a queue for " or "Can queue you for ") .. bgNames(L.mine))
			or ((iAmLeader() and "Players for " or "Groups for ") .. (L.mine and L.titleOf(L.mine) or ""))
		header("matches", title, #matches)
		if not collapsed.matches then add(matches, true) end
	end
	local groups = L.groupRows(rows, d0.groupBy)
	if groups then
		for _, g in ipairs(groups) do
			local text = g.text
			-- activity headers: the name and range in the game's difficulty colour
			local r1 = g.rows[1]
			if d0.groupBy == "act" and r1 and r1.act then
				local hex = A.levelColor(r1.act, lvl)
				text = hex .. g.text .. "|r" .. (r1.min > 0 and ("  " .. hex .. (r1.min == r1.max and r1.min or (r1.min .. "-" .. r1.max)) .. "|r") or "")
			end
			header(g.key, text, #g.rows)
			if not collapsed[g.key] then add(g.rows) end
		end
	else
		add(rows)
	end
	browse.cols = browse.cols or L.columns(440)
	box:SetDataProvider(CreateDataProvider(items), ScrollBoxConstants.RetainScrollPosition)

	local peers = L.count(L.peers)
	local shown = #rows + #matches
	if shown > 0 then empty:Hide()
	elseif questFilter then
		empty:SetText("Nobody is listed for this quest yet.\n\nList yourself and anyone on any server who picks it will find you.")
		empty:Show()
	elseif outside > 0 then empty:SetText(("Nothing at your level right now. %d %s outside it: tick All levels to see them."):format(outside, outside == 1 and "listing is" or "listings are")) empty:Show()
	elseif total > 0 then empty:SetText("No groups match your filters.") empty:Show()
	elseif peers == 0 then
		empty:SetText("No OpenGroup players found yet.\n\nOpenGroup looks for them as you use it (friends, guild, group, " ..
			"whispers, and a /who search now and then). Click " .. GOLD .. "Refresh|r to look again. Anything they list, on any server, shows up here.")
		empty:Show()
	else
		empty:SetText(("Nobody is listed right now.\n\n%d OpenGroup %s known. List your own group in the %sList a group|r tab."):format(peers, peers == 1 and "player" or "players", GOLD))
		empty:Show()
	end
	local shardText = "You're on " .. L.CHAN .. " " .. GOLD .. (myShard > 0 and myShard or "?") .. "|r"
	if total == 0 then countText:SetText(shardText)
	elseif outside > 0 then countText:SetText(("%s   %d shown, %d outside your level"):format(shardText, shown, outside))
	else countText:SetText(shardText .. "   " .. shown .. " of " .. total) end

	local l = selectedListing()
	if selected and not l then selected = nil end
	sendBtn:SetEnabled(l ~= nil)
	actBtn:SetEnabled(l ~= nil)
	actBtn:SetText(l and l.cat == P.BGQ_OFFER and (asked[l.leader] and "Ask Again" or "Ask for a Queue")
		or l and l.cat == P.BGQ_WANT and "Invite to Queue"
		or l and l.cat == P.SUMMON_CAT and (asked[l.leader] and "Ask Again" or "Request Summon")
		or l and l.size <= 1 and "Group Invite" or (l and asked[l.leader] and "Ask Again" or "Ask to Join"))
	chip:Hide()
	qcard:SetShown(questFilter ~= nil)
	local top = questFilter and -92 or -4
	browse.colHead:ClearAllPoints()
	browse.colHead:SetPoint("TOPLEFT", 6, top)
	browse.colHead:SetPoint("RIGHT", box, "RIGHT", 0, 0)
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", 6, top - 20)
	box:SetPoint("BOTTOMRIGHT", -24, 6)
	browse.layoutColumns(browse.cols)
	if questFilter then
		local q = questFilter
		local c = GetQuestDifficultyColor and GetQuestDifficultyColor(q.level or 0)
		local hex = c and ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) or GOLD
		qcard.title:SetText(("%s[%d] %s|r"):format(hex, q.level or 0, q.title))
		local lines = {}
		for i, o in ipairs(Q.objectives(q.id)) do
			if i > 3 then break end
			lines[#lines + 1] = (o.done and GREEN or WHITE) .. "- " .. o.text .. "|r"
		end
		if #lines == 0 then lines[1] = GREY .. (Q.onLog(q.id) and "On your quest log" or "Not on your quest log") .. "|r" end
		qcard.objs:SetText(table.concat(lines, "\n"))
		local onIt = shown
		qcard.count:SetText(onIt == 0 and (GREY .. "Nobody listed yet|r") or (GREEN .. onIt .. (onIt == 1 and " player" or " players") .. " on it|r"))
		qcard.list:SetEnabled(not (L.mine and L.mine.quest == q.id))
		qcard.list:SetText(L.mine and L.mine.quest == q.id and "You're listed" or "List me for it")
	end
	emptyArt:SetShown(empty:IsShown())
	-- Group Finder results missing or old: say Search, and offer it in an empty list
	local Nb = OpenGroup_Nearby
	local stale = Nb and Nb.stale() or false
	refreshBtn:SetText(stale and "Search Group Finder" or "Refresh")
	local wantsFinder = d0.where == "all" or d0.where == "finder" or d0.where == "mine"
	browse.emptySearch:ClearAllPoints()
	browse.emptySearch:SetPoint("TOP", empty, "BOTTOM", 0, -14)
	browse.emptySearch:SetShown(empty:IsShown() and stale and wantsFinder and not questFilter)
	browse.ready = true
end
-- the columns follow the list's width (the window can be resized)
box:HookScript("OnSizeChanged", function(self, w)
	if win.sizing then return end   -- done once when the drag ends
	w = (w or self:GetWidth() or 0) - 20
	if w <= 0 then return end
	local cols = L.columns(w)
	local sig = {}
	for _, c in ipairs(cols.order) do sig[#sig + 1] = c.key .. c.x .. ":" .. c.w end
	cols.sig = table.concat(sig, ",")
	if browse.cols and browse.cols.sig == cols.sig then return end
	browse.cols = cols
	if browse.colHead then browse.layoutColumns(cols) end
	if win:IsShown() then L.onChange() end
end)
win.afterSizing = function()
	local w = (box:GetWidth() or 0) - 20
	if w > 0 then
		local cols = L.columns(w)
		local sig = {}
		for _, c in ipairs(cols.order) do sig[#sig + 1] = c.key .. c.x .. ":" .. c.w end
		cols.sig = table.concat(sig, ",")
		browse.cols = cols
		if browse.colHead then browse.layoutColumns(cols) end
	end
	if pages.list and pages.list.layoutBanners and pages.list.content:IsVisible() then pages.list.layoutBanners() end
	L.onChange()
end
function browse.setQuest(q) questFilter = q collapsed = {} L.onChange() end
browse.onShow = function() L.migrateBrowse(db()) end

-- --------------------------------------------------------------------------------------------
-- LIST A GROUP

local list = page("list")
list.footer:SetHeight(54)
list.bodyBottom = 64
local draft = { cat = nil, acts = {}, need = 0, note = "", title = "", quest = nil, mode = "quests", dest = "", gold = 0, silver = 0, bgMode = "group" }
local function isWarlock() return select(2, UnitClass("player")) == "WARLOCK" end
local function catKind(c) return c and (c.summon and "summon" or W.kindOf(c.name)) or "custom" end

local step2 -- the category page, built below
-- header: the role buttons
local roleTitle = list.header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
roleTitle:SetPoint("TOPLEFT", 4, -4)
local roleButtons = {}
for i, r in ipairs(ROLES) do
	local b = W.roleButton(list.header, r, 44, function(role, on)
		draft.need = on and (has(draft.need, role) and draft.need or draft.need + role) or (has(draft.need, role) and draft.need - role or draft.need)
	end)
	b:SetPoint("TOPLEFT", roleTitle, "BOTTOMLEFT", 16 + (i - 1) * 72, -6)
	roleButtons[r] = b
end
local roleHint = list.header:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
roleHint:SetPoint("TOPLEFT", roleButtons[P.DAMAGE], "TOPRIGHT", 22, -2)
roleHint:SetWidth(170)
roleHint:SetJustifyH("LEFT")

-- the open spots and auto invite controls (their own scope: the file is near Lua's 200 locals)
local paintSpots, paintAuto, chips, groupSpots
do
	-- a group's open spots: one chip each (5 minus the group, at least 1). Click a chip to set its
	-- role, class and level; right-click resets it to any. Saved in OpenGroupDB.spots.
	local PARTY = 5
	local function openCount() return math.max(1, PARTY - math.max(1, GetNumGroupMembers())) end
	local function copySpots(list)
		local out = {}
		for _, sp in ipairs(list or {}) do out[#out + 1] = P.spot(sp.role, sp.class, sp.min, sp.max) end
		return out
	end
	-- the spots on show: the live listing's while listed as a group, else the draft
	local function spotList()
		if L.mine and GetNumGroupMembers() > 1 and type(L.mine.spots) == "table" and #L.mine.spots > 0 then return L.mine.spots end
		if type(draft.spots) ~= "table" then
			local saved = db() and db().spots
			draft.spots = type(saved) == "table" and #saved > 0 and copySpots(saved) or P.spotsFromNeed(draft.need, openCount())
		end
		-- as many as there are open spots: the last ones go when the group grows, damage is added when it shrinks
		local n = openCount()
		while #draft.spots > n do table.remove(draft.spots) end
		while #draft.spots < n do draft.spots[#draft.spots + 1] = P.spot(P.DAMAGE) end
		return draft.spots
	end
	local function spotsChanged(list)
		if db() then db().spots = copySpots(list) end
		if list ~= draft.spots then draft.spots = copySpots(list) end
		draft.need = P.needOfSpots(list)
		if L.mine and GetNumGroupMembers() > 1 then L.setSpots(list) end
		paintSpots()
	end

	chips = {}
	for i = 1, P.MAX_SPOTS do
		local c = CreateFrame("Button", nil, list.header)
		c:SetSize(42, 42)
		c:SetPoint("TOPLEFT", roleTitle, "BOTTOMLEFT", 16 + (i - 1) * 62, -6)
		c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		W.roleArt(c, 42)
		c.hl = c:CreateTexture(nil, "HIGHLIGHT")
		c.hl:SetAllPoints(c.icon)
		c.hl:SetColorTexture(1, 0.9, 0.6, 0.12)
		c.hl:SetBlendMode("ADD")
		c.any = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		c.any:SetPoint("CENTER", 0, 0)
		c.any:SetText("Any")
		c.class = c:CreateTexture(nil, "OVERLAY")
		c.class:SetSize(20, 20)
		c.class:SetPoint("BOTTOMRIGHT", 4, -4)
		c.level = c:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		c.level:SetPoint("BOTTOM", c, "BOTTOM", 0, -2)
		c.index = i
		c:Hide()
		chips[i] = c
	end

	-- the editor: a small card under the chip that was clicked. A live summary as its title, then a
	-- label column (Role, Class, Level) with the controls on the same lines; one button size and
	-- one selected look throughout. Escape or a click elsewhere closes it.
	local ed = CreateFrame("Frame", "OpenGroupSpotEditor", list.header, BackdropTemplateMixin and "BackdropTemplate" or nil)
	ed:SetSize(330, 172)
	ed:SetFrameStrata("DIALOG")
	ed:SetClampedToScreen(true)
	ed:EnableMouse(true)
	ed:Hide()
	if W.hasAtlas(W.TILE_CARD) then
		ed.bg = ed:CreateTexture(nil, "BACKGROUND")
		ed.bg:SetAllPoints()
		ed.bg:SetAtlas(W.TILE_CARD)
	else
		ed.bg = ed:CreateTexture(nil, "BACKGROUND")
		ed.bg:SetPoint("TOPLEFT", 4, -4) ed.bg:SetPoint("BOTTOMRIGHT", -4, 4)
		W.gradient(ed.bg, 0.16, 0.12, 0.07, 0.98, 0.07, 0.055, 0.04, 0.98)
		if ed.SetBackdrop then
			ed:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
			ed:SetBackdropBorderColor(0.8, 0.65, 0.4, 1)
		end
	end
	tinsert(UISpecialFrames, "OpenGroupSpotEditor")   -- Escape closes it
	ed.title = ed:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	ed.title:SetPoint("TOPLEFT", 16, -14)
	ed.title:SetPoint("RIGHT", -16, 0)
	ed.title:SetJustifyH("LEFT")
	ed.title:SetWordWrap(false)
	local function editing() return ed.list and ed.list[ed.index] end

	local LABEL_X, CTRL_X, SIZE, STEP = 16, 70, 28, 32
	local function rowLabel(text, y)
		local t = ed:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		t:SetPoint("LEFT", ed, "TOPLEFT", LABEL_X, y)
		t:SetText(text)
		return t
	end
	-- one round button style for roles and classes: same size, a gold ring when picked
	local function pick(x, y, tip)
		local b = CreateFrame("Button", nil, ed)
		b:SetSize(SIZE, SIZE)
		b:SetPoint("LEFT", ed, "TOPLEFT", x, y)
		b.ring = b:CreateTexture(nil, "OVERLAY")
		b.ring:SetPoint("TOPLEFT", -7, 7) b.ring:SetPoint("BOTTOMRIGHT", 7, -7)
		b.ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
		b.ring:SetBlendMode("ADD")
		b.ring:SetVertexColor(1, 0.82, 0.2)
		b.ring:Hide()
		b.hl = b:CreateTexture(nil, "HIGHLIGHT")
		b.hl:SetAllPoints()
		b.hl:SetColorTexture(1, 0.9, 0.6, 0.15)
		b.hl:SetBlendMode("ADD")
		b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:SetText(tip) GameTooltip:Show() end)
		b:SetScript("OnLeave", GameTooltip_Hide)
		function b:SetPicked(on)
			self.ring:SetShown(on)
			self:SetAlpha(on and 1 or 0.6)
		end
		return b
	end
	local function anyLabel(b)
		local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		t:SetPoint("CENTER")
		t:SetText("Any")
	end

	-- Role: Any, Tank, Healer, Damage
	local ROW_ROLE, ROW_CLASS, ROW_LEVEL = -52, -90, -128
	rowLabel("Role", ROW_ROLE)
	ed.roles = {}
	for k, r in ipairs({ 0, P.TANK, P.HEALER, P.DAMAGE }) do
		local b = pick(CTRL_X + (k - 1) * STEP, ROW_ROLE, W.ROLE_NAME[r])
		W.roleArt(b, SIZE * 0.85)
		b:SetRole(r, true)
		if r == 0 then anyLabel(b) end
		b.role = r
		b:SetScript("OnClick", function()
			local sp = editing()
			if sp then sp.role = r W.sound("IG_MAINMENU_OPTION_CHECKBOX_ON") spotsChanged(ed.list) end
		end)
		ed.roles[k] = b
	end

	-- Class: Any, then the classes this faction can play, in the game's order
	rowLabel("Class", ROW_CLASS)
	ed.classes = {}
	local CLASS_LIST = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
	local function buildClassButtons()
		if #ed.classes > 0 then return end
		local fac = UnitFactionGroup("player")
		local list2 = { false }
		for _, cls in ipairs(CLASS_LIST) do
			if not ((cls == "PALADIN" and fac == "Horde") or (cls == "SHAMAN" and fac == "Alliance")) then list2[#list2 + 1] = cls end
		end
		for k, cls in ipairs(list2) do
			cls = cls or nil
			local b = pick(CTRL_X + (k - 1) * STEP, ROW_CLASS, W.className(cls))
			b.icon = b:CreateTexture(nil, "ARTWORK")
			b.icon:SetAllPoints()
			if cls then W.setClassIcon(b.icon, cls)
			else
				b.icon:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
				b.icon:SetVertexColor(0.25, 0.2, 0.12)
				anyLabel(b)
			end
			b.cls = cls
			b:SetScript("OnClick", function()
				local sp = editing()
				if sp then sp.class = cls W.sound("IG_MAINMENU_OPTION_CHECKBOX_ON") spotsChanged(ed.list) end
			end)
			ed.classes[k] = b
		end
		ed:SetWidth(math.max(330, CTRL_X + #list2 * STEP + 12))
	end

	-- Level: two boxes with a dash, "any" inside them when blank
	rowLabel("Level", ROW_LEVEL)
	local function levelBox(x)
		local e = CreateFrame("EditBox", nil, ed, "InputBoxTemplate")
		e:SetSize(36, 20)
		e:SetPoint("LEFT", ed, "TOPLEFT", x, ROW_LEVEL)
		e:SetAutoFocus(false) e:SetNumeric(true) e:SetMaxLetters(2)
		e:SetScript("OnEscapePressed", e.ClearFocus) e:SetScript("OnEnterPressed", e.ClearFocus)
		e.ph = e:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		e.ph:SetPoint("CENTER")
		e.ph:SetText("any")
		e:HookScript("OnTextChanged", function(self) self.ph:SetShown(self:GetText() == "") end)
		return e
	end
	ed.min = levelBox(CTRL_X + 6)
	ed.dash = ed:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	ed.dash:SetPoint("LEFT", ed.min, "RIGHT", 6, 0)
	ed.dash:SetText("-")
	ed.max = levelBox(CTRL_X + 6 + 36 + 22)
	local function levelChanged()
		local sp = editing()
		if not sp or ed.painting then return end
		sp.min, sp.max = P.int(ed.min:GetText(), 1, 200), P.int(ed.max:GetText(), 1, 200)
		spotsChanged(ed.list)
	end
	ed.min:HookScript("OnTextChanged", levelChanged)
	ed.max:HookScript("OnTextChanged", levelChanged)

	ed.done = CreateFrame("Button", nil, ed, "UIPanelButtonTemplate")
	ed.done:SetSize(72, 22)
	ed.done:SetPoint("BOTTOMRIGHT", -14, 14)
	ed.done:SetText("Done")
	ed.done:SetScript("OnClick", function() ed:Hide() end)
	-- look for someone to fill this spot with /who
	ed.find = CreateFrame("Button", nil, ed, "UIPanelButtonTemplate")
	ed.find:SetSize(110, 22)
	ed.find:SetPoint("RIGHT", ed.done, "LEFT", -6, 0)
	ed.find:SetText("Find players")
	ed.find:SetScript("OnClick", function()
		local sp = editing()
		ed:Hide()
		if OpenGroup_UI and OpenGroup_UI.find then OpenGroup_UI.find.open(sp) end
	end)

	function ed:Paint()
		local sp = editing()
		if not sp then self:Hide() return end
		self.painting = true
		local lv = W.levelRange(sp.min, sp.max)
		self.title:SetText(("Spot %d:  %s%s, %s, %s|r"):format(self.index, WHITE, W.ROLE_NAME[sp.role or 0],
			sp.class and W.className(sp.class) or "any class", lv ~= "" and ("level " .. lv) or "any level"))
		for _, b in ipairs(self.roles) do b:SetPicked((sp.role or 0) == b.role) end
		for _, b in ipairs(self.classes) do b:SetPicked(sp.class == b.cls) end
		if not self.min:HasFocus() then self.min:SetText(sp.min and tostring(sp.min) or "") end
		if not self.max:HasFocus() then self.max:SetText(sp.max and tostring(sp.max) or "") end
		self.painting = false
	end

	-- a click anywhere else closes it
	pcall(ed.RegisterEvent, ed, "GLOBAL_MOUSE_DOWN")
	ed:SetScript("OnEvent", function(self)
		if self:IsShown() and not self:IsMouseOver() and not (self.chip and self.chip:IsMouseOver()) then self:Hide() end
	end)
	ed:SetScript("OnHide", function(self) self.min:ClearFocus() self.max:ClearFocus() end)

	local function openEditor(chip)
		if ed:IsShown() and ed.chip == chip then ed:Hide() return end
		buildClassButtons()
		ed.chip, ed.index, ed.list = chip, chip.index, spotList()
		ed:ClearAllPoints()
		ed:SetPoint("TOPLEFT", chip, "BOTTOMLEFT", -6, -18)
		ed:Show()
		ed:Paint()
	end

	for _, c in ipairs(chips) do
		c:SetScript("OnClick", function(self, button)
			local lst = spotList()
			local sp = lst[self.index]
			if not sp then return end
			if button == "RightButton" then
				lst[self.index] = P.spot(0)
				W.sound("IG_MAINMENU_OPTION_CHECKBOX_OFF")
				spotsChanged(lst)
				return
			end
			W.sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
			openEditor(self)
		end)
		c:SetScript("OnEnter", function(self)
			local sp = spotList()[self.index]
			if not sp then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(("Open spot %d"):format(self.index))
			GameTooltip:AddLine(W.spotText(sp), 1, 1, 1)
			GameTooltip:AddLine("Click to change it. Right-click to make it any.", 0, 1, 0, true)
			GameTooltip:Show()
		end)
		c:SetScript("OnLeave", GameTooltip_Hide)
	end

	-- shown: true while listing a group (not solo, summons or queues)
	paintSpots = function(shown)
		if shown == nil then shown = chips.shown end
		chips.shown = shown
		local lst = shown and spotList() or {}
		for i, c in ipairs(chips) do
			local sp = lst[i]
			if sp then
				c:SetRole(sp.role, true)
				c.any:SetShown((sp.role or 0) == 0)
				c.class:SetShown(sp.class ~= nil)
				if sp.class then W.setClassIcon(c.class, sp.class) end
				c.level:SetText(W.levelRange(sp.min, sp.max))
				c:Show()
			else
				c:Hide()
			end
		end
		if not shown then ed:Hide() elseif ed:IsShown() then ed.list = lst ed:Paint() end
		if shown then draft.need = P.needOfSpots(lst) end
	end

	-- "Auto invite": invite people who fit an open spot while listed; the gear opens its options
	local autoCheck = CreateFrame("CheckButton", nil, list.footer, "UICheckButtonTemplate")
	autoCheck:SetSize(22, 22)
	autoCheck:SetPoint("TOPLEFT", list.footer, "TOPLEFT", 4, 0)
	local autoLabel = list.footer:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	autoLabel:SetPoint("LEFT", autoCheck, "RIGHT", 2, 1)
	autoLabel:SetText("Auto invite")
	local autoGear = CreateFrame("Button", nil, list.footer)
	autoGear:SetSize(16, 16)
	autoGear:SetPoint("LEFT", autoLabel, "RIGHT", 6, 0)
	autoGear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
	autoGear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	autoGear:SetScript("OnClick", function(self) if OpenGroup_AutoInvite then OpenGroup_AutoInvite.options(self) end end)
	autoGear:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Auto invite options")
		GameTooltip:AddLine("Who to invite from, and whether to invite extras.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	autoGear:SetScript("OnLeave", GameTooltip_Hide)
	autoCheck:SetScript("OnClick", function(self)
		local AI = OpenGroup_AutoInvite
		if not AI then return end
		if self:GetChecked() then AI.start() else AI.stop() end
	end)
	autoCheck:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Auto invite")
		GameTooltip:AddLine("While your group is listed, OpenGroup invites people who fit one of your open spots, one every 2 seconds, until the group is full. Then it delists.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	autoCheck:SetScript("OnLeave", GameTooltip_Hide)
	paintAuto = function(shown)
		autoCheck:SetShown(shown) autoLabel:SetShown(shown) autoGear:SetShown(shown)
		local AI = OpenGroup_AutoInvite
		autoCheck:SetChecked(AI and AI.on or false)
		if not shown and AI and AI.frame then AI.frame:Hide() end
	end
	groupSpots = function() return GetNumGroupMembers() > 1 and copySpots(spotList()) or nil end
end

-- "Tell my party": when a group lists, its members hear about it in party chat (on by default)
local tellParty = CreateFrame("CheckButton", nil, list.footer, "UICheckButtonTemplate")
tellParty:SetSize(22, 22)
tellParty:SetPoint("TOPRIGHT", list.footer, "TOP", 150, 0)
local tellLabel = list.footer:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
tellLabel:SetPoint("LEFT", tellParty, "RIGHT", 2, 1)
tellLabel:SetText("Tell my party")
tellParty:SetScript("OnClick", function(self) db().tellParty = self:GetChecked() and true or false end)
tellParty:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText("Tell my party")
	GameTooltip:AddLine("When you list a group, OpenGroup says so in party chat: what it's listed for and which roles it's looking for.", 1, 1, 1, true)
	GameTooltip:Show()
end)
tellParty:SetScript("OnLeave", GameTooltip_Hide)

-- "Also list in Group Finder": the List click lists you in the game's own Group Finder too (dungeon
-- and other activities the game knows), so players without OpenGroup see it (on by default)
local lfgPost = CreateFrame("CheckButton", nil, list.footer, "UICheckButtonTemplate")
lfgPost:SetSize(22, 22)
lfgPost:SetPoint("TOP", list.footer, "TOP", -36, 0)
local lfgPostLabel = list.footer:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
lfgPostLabel:SetPoint("LEFT", lfgPost, "RIGHT", 2, 1)
lfgPostLabel:SetText("Also list in Group Finder")
lfgPost:SetScript("OnClick", function(self) db().gameList = self:GetChecked() and true or false end)
lfgPost:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText("Also list in the game's Group Finder")
	GameTooltip:AddLine("When you list for a dungeon or another activity the game knows, OpenGroup lists you in the game's own Group Finder too, so players without the addon on your server see it. Leave takes it down again. Solo or as the group's leader only; quests, summons and battleground queues stay OpenGroup-only.", 1, 1, 1, true)
	GameTooltip:AddLine("To post a line in LookingForGroup chat, click Post in LFG on the listed bar.", .7, .7, .7, true)
	GameTooltip:Show()
end)
lfgPost:SetScript("OnLeave", GameTooltip_Hide)

local function paintRoles()
	local c = draft.cat and A.category(draft.cat)
	local bgqMode = step2 and step2:IsShown() and catKind(c) == "battle" and draft.bgMode ~= "group"
	local summonMode = (step2 and step2:IsShown() and c and c.summon) or bgqMode
	for _, b in pairs(roleButtons) do b:SetAlpha(summonMode and 0.25 or 1) b:EnableMouse(not summonMode) b.check:EnableMouse(not summonMode) end
	if bgqMode then
		roleTitle:SetText(draft.bgMode == "offer" and "Queueing people" or "Asking for a queue")
		roleHint:SetText(draft.bgMode == "offer"
			and "Stand at a battlemaster. Invite whoever asks and click Join as Group; their queue pops wherever they are."
			or "Someone at a battlemaster invites you and queues the group, so you can stay out in the world.")
		tellParty:Hide() tellLabel:Hide()
		lfgPost:SetChecked(db().gameList ~= false)
		for _, b in pairs(roleButtons) do b:Show() end
		paintSpots(false) paintAuto(false)
		roleHint:ClearAllPoints() roleHint:SetPoint("TOPLEFT", roleButtons[P.DAMAGE], "TOPRIGHT", 22, -2)  roleHint:SetWidth(300) roleHint:SetWordWrap(true)
		return
	end
	if summonMode then
		for _, b in pairs(roleButtons) do b:Show() end
		paintSpots(false) paintAuto(false)
		roleHint:ClearAllPoints() roleHint:SetPoint("TOPLEFT", roleButtons[P.DAMAGE], "TOPRIGHT", 22, -2)  roleHint:SetWidth(300) roleHint:SetWordWrap(true)
		roleTitle:SetText("Warlock summons")
		roleHint:SetText("Roles don't apply to summons. Set where you're summoning to and your price below.")
		return
	end
	local solo = GetNumGroupMembers() <= 1
	tellParty:SetShown(not solo) tellLabel:SetShown(not solo)
	tellParty:SetChecked(db().tellParty ~= false)
	lfgPost:SetChecked(db().gameList ~= false)
	roleTitle:SetText(solo and "Your roles" or "Looking for")
	if step2 and step2.noteLabel then
		step2.noteLabel:SetText(solo and "About you" or "Note")
		step2.noteHint:SetText(solo and "e.g. casual noob, 500 dps pumper, first time in here" or "e.g. Lava run, have key, quick clear")
	end
	roleHint:SetText(solo and "Pick every role you'll play. Leaders on any server see you under Players."
		or "Click a spot to set its role, class and level. Right-click makes it any.")
	for _, b in pairs(roleButtons) do b:SetShown(solo) end
	paintSpots(not solo) paintAuto(not solo)
	roleHint:ClearAllPoints()
	roleHint:SetPoint("TOPLEFT", roleTitle, "BOTTOMLEFT", 4, -54)
	roleHint:SetPoint("RIGHT", list.header, "RIGHT", -8, 0)
	roleHint:SetWordWrap(false)
	if solo then for r, b in pairs(roleButtons) do b:SetOn(has(draft.need, r)) end end
end

-- step 1: category banners, with a typed search above them
local step1 = CreateFrame("Frame", nil, list.content)
step1:SetAllPoints()
step1:SetScript("OnSizeChanged", function() if not win.sizing and step1:IsVisible() and list.layoutBanners then list.layoutBanners() end end)
local quick = CreateFrame("EditBox", nil, step1, "SearchBoxTemplate")
quick:SetSize(300, 22)
quick:SetPoint("TOPLEFT", 17, -14)
quick:SetPoint("RIGHT", step1, "RIGHT", -12, 0)   -- edges in line with the tiles
quick:SetAutoFocus(false)
if quick.Instructions then quick.Instructions:SetText("Type a dungeon (BRD, Strat, UBRS...)") end

local function openCategory(catID) end   -- replaced below

local function quickItems(text)
	local items = {}
	if (text or "") == "" then return items end
	for _, id in ipairs(A.search(text, nil, 8)) do
		local c = A.category(A.info[id].cat)
		items[#items + 1] = { text = W.levelText(id) .. "  " .. GREY .. (c and c.name or "") .. "|r", value = id }
	end
	return items
end
W.autocomplete(quick, quickItems, function(id)
	quick:SetText("")
	quick:ClearFocus()
	draft.acts = { id }
	openCategory(A.info[id].cat)
end, 340)

local banners = {}
-- step 1 is a 2 x 2 grid of category tiles (2 x 3 with Warlock Summons), then quick picks in the
-- space under it: your recent listings and dungeons that suit your level
local function layoutBanners()
	local cats = {}
	for _, c in ipairs(A.load()) do if not c.summon or isWarlock() then cats[#cats + 1] = c end end
	local wAll, hAll = step1:GetWidth(), step1:GetHeight()
	if not wAll or wAll < 100 then wAll = 440 end
	if not hAll or hAll < 100 then hAll = 420 end
	-- the tiles share the height between the search box and the quick picks: equal 10 px gutters,
	-- edges in line with the search box, never taller than 150
	local gap, cols, margin, top = 10, 2, 12, 46
	local rows = math.ceil(#cats / cols)
	local picksH = list.layoutPicks and list.layoutPicks(nil, wAll) or 0
	local tw = math.floor((wAll - 2 * margin - gap) / cols)
	local th = math.floor((hAll - top - 10 - picksH - (rows - 1) * gap) / math.max(1, rows))
	th = math.max(70, math.min(150, th))
	local NOUN = { dungeon = "dungeons", battle = "battlegrounds", raid = "raids" }
	for i, c in ipairs(cats) do
		local b = banners[i]
		if not b then b = W.tile(step1) banners[i] = b end
		local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
		-- an odd one out at the end spans the full width
		local wide = i == #cats and #cats % cols == 1
		b:SetSize(wide and (wAll - 2 * margin) or tw, th)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", margin + col * (tw + gap), -top - row * (th + gap))
		local n, kind = #c.acts, catKind(c)
		local sub = n > 0 and (n .. " " .. (NOUN[kind] or (n == 1 and "activity" or "activities"))) or ""
		if c.summon then sub = "Sell summons on every server" end
		if kind == "quest" then sub = (n > 0 and (n .. " zones, ") or "") .. "or any quest in your log" end
		b:SetCategory(c.name, sub, c.summon and SUMMON_ICON or nil)
		b:SetScript("OnClick", function() W.sound("IG_MAINMENU_OPTION_CHECKBOX_ON") openCategory(c.id) end)
		b:Show()
	end
	for i = #cats + 1, #banners do banners[i]:Hide() end
	if list.layoutPicks then list.layoutPicks(-top - rows * (th + gap) - 2, wAll) end
end
list.layoutBanners = layoutBanners
list.tiles = banners

-- Quick picks: the last 3 listings (one click lists again, after a yes) and up to 6 dungeons for
-- your level (one click opens that dungeon's form). A section with nothing in it is hidden.
;(function()
	local pool = { titles = {}, buttons = {} }
	list.picks = pool
	local function title(i)
		local t = pool.titles[i]
		if not t then
			t = step1:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			t:SetJustifyH("LEFT")
			pool.titles[i] = t
		end
		return t
	end
	local function button(i)
		local b = pool.buttons[i]
		if not b then
			b = CreateFrame("Button", nil, step1)
			b:SetHeight(24)
			b.bg = b:CreateTexture(nil, "BACKGROUND")
			b.bg:SetAllPoints()
			W.gradient(b.bg, 0.16, 0.12, 0.07, 0.95, 0.09, 0.07, 0.05, 0.95)
			W.edge(b, 0.45, 0.36, 0.2, 1)
			b.hl = b:CreateTexture(nil, "HIGHLIGHT")
			b.hl:SetAllPoints()
			b.hl:SetColorTexture(1, 0.85, 0.5, 0.12)
			b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			b.text:SetPoint("LEFT", 8, 0)
			b.text:SetPoint("RIGHT", -8, 0)
			b.text:SetJustifyH("LEFT")
			b.text:SetWordWrap(false)
			pool.buttons[i] = b
		end
		return b
	end
	-- "Tank, Healer, 3 Damage" from a listing's spots or roles
	local function whoFor(e)
		local counts, order = {}, {}
		for _, sp in ipairs(e.spots or {}) do
			local key = sp.class and W.className(sp.class) or W.ROLE_NAME[sp.role or 0]
			if not counts[key] then order[#order + 1] = key end
			counts[key] = (counts[key] or 0) + 1
		end
		if #order == 0 then
			local names = {}
			for _, r in ipairs(ROLES) do if has(e.need or 0, r) then names[#names + 1] = W.ROLE_NAME[r] end end
			return table.concat(names, ", ")
		end
		local out = {}
		for _, k in ipairs(order) do out[#out + 1] = (counts[k] > 1 and (counts[k] .. " ") or "") .. k end
		return table.concat(out, ", ")
	end
	if StaticPopupDialogs then
		StaticPopupDialogs.OPENGROUP_RELIST = {
			text = "List again for %s?", button1 = YES or "Yes", button2 = NO or "No",
			OnAccept = function(_, e) list.relist(e) end,
			timeout = 0, whileDead = 1, hideOnEscape = 1,
		}
	end
	function list.relist(e)
		local grouped = GetNumGroupMembers() > 1
		L.post(e.title or "", e.note or "", e.need or 0, e.cat or 0, e.acts or {}, 0, e.quest or 0, grouped and e.spots or nil)
	end
	-- y nil: just measure, returning the height the picks need
	function list.layoutPicks(y, wAll)
		local measure = y == nil
		local startY = y or 0
		y = startY
		local ti, bi = 0, 0
		local function section(text)
			ti = ti + 1
			if measure then y = y - 18 return end
			local t = title(ti)
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", 16, y)
			t:SetText(text)
			t:Show()
			y = y - 18
		end
		-- your recent listings
		local recent = type(db().recent) == "table" and db().recent or {}
		if #recent > 0 then
			section("Your recent listings")
			for i = 1, math.min(3, #recent) do
				local e = recent[i]
				bi = bi + 1
				if not measure then
				local b = button(bi)
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", 14, y)
				b:SetPoint("RIGHT", step1, "RIGHT", -14, 0)
				b.text:SetText(GOLD .. L.titleOf(e) .. "|r" .. GREY .. "   " .. whoFor(e) .. "|r")
				b:SetScript("OnClick", function()
					if StaticPopup_Show and StaticPopupDialogs and StaticPopupDialogs.OPENGROUP_RELIST then
						local dlg = StaticPopup_Show("OPENGROUP_RELIST", L.titleOf(e))
						if dlg then dlg.data = e end
					else
						list.relist(e)
					end
				end)
				b:Show()
				end
				y = y - 28
			end
			y = y - 6
		end
		-- dungeons for your level, nearest first
		local lvl = UnitLevel("player") or 0
		local picks = {}
		for _, c in ipairs(A.load()) do
			if catKind(c) == "dungeon" then
				for _, id in ipairs(c.acts) do
					local i = A.get(id)
					if i and (i.min or 0) > 0 and A.fits(id, lvl) then
						local mid = ((i.min or 0) + (i.max or i.min)) / 2
						picks[#picks + 1] = { id = id, cat = c.id, d = math.abs(mid - lvl) }
					end
				end
			end
		end
		table.sort(picks, function(x, z) if x.d ~= z.d then return x.d < z.d end return x.id < z.id end)
		if #picks > 0 and measure then
			section("Good for your level")
			y = y - math.ceil(math.min(6, #picks) / 3) * 28
		elseif #picks > 0 then
			section("Good for your level")
			local per, gap = 3, 6
			local w = math.floor(((wAll or 440) - 28 - (per - 1) * gap) / per)
			for i = 1, math.min(6, #picks) do
				local pk = picks[i]
				bi = bi + 1
				local b = button(bi)
				local col, row = (i - 1) % per, math.floor((i - 1) / per)
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", 14 + col * (w + gap), y - row * 28)
				b:SetWidth(w)
				-- the full name if it fits, else the short one; the level range is never cut
				b.text:SetText(W.levelText(pk.id, lvl))
				local info = A.get(pk.id)
				if info and b.text.GetStringWidth and (b.text:GetStringWidth() or 0) > w - 16 and info.short and info.short ~= info.name then
					local r = A.range(pk.id)
					b.text:SetText(A.levelColor(pk.id, lvl) .. info.short .. (r ~= "" and ("  " .. r) or "") .. "|r")
				end
				b:SetScript("OnClick", function()
					W.sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
					draft.acts = { pk.id }
					openCategory(pk.cat)
				end)
				b:Show()
			end
		end
		if measure then return startY - y end
		for i = ti + 1, #pool.titles do pool.titles[i]:Hide() end
		for i = bi + 1, #pool.buttons do pool.buttons[i]:Hide() end
		return startY - y
	end
end)()

-- step 2: the chosen category: search, activity checklist (or a title for Custom), note
step2 = CreateFrame("Frame", nil, list.content)
step2:SetAllPoints()
step2:Hide()
local back2 = CreateFrame("Button", nil, step2)
back2:SetSize(26, 26)
back2:SetPoint("TOPLEFT", 10, -10)
back2:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
back2:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
back2:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
local catTitle = step2:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
catTitle:SetPoint("LEFT", back2, "RIGHT", 6, 0)
local pickedText = step2:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
pickedText:SetPoint("TOPRIGHT", -16, -16)

local filterBox = CreateFrame("EditBox", nil, step2, "SearchBoxTemplate")
filterBox:SetSize(250, 22)
filterBox:SetPoint("TOPRIGHT", step2, "TOPRIGHT", -24, -44)
filterBox:SetPoint("TOPLEFT", back2, "BOTTOMLEFT", 8, -8)
filterBox:SetAutoFocus(false)
if filterBox.Instructions then filterBox.Instructions:SetText("Type to find...") end
local showAll = CreateFrame("CheckButton", nil, step2, "UICheckButtonTemplate")
showAll:SetSize(22, 22)
showAll:SetPoint("LEFT", filterBox, "RIGHT", 10, 0)
local showAllLabel = step2:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
showAllLabel:SetPoint("LEFT", showAll, "RIGHT", 2, 1)
showAllLabel:SetText("All levels")

local actBox = CreateFrame("Frame", nil, step2, "WowScrollBoxList")
actBox:SetPoint("TOPLEFT", filterBox, "BOTTOMLEFT", -10, -4)
actBox:SetPoint("BOTTOMRIGHT", -24, 74)
local actBar = CreateFrame("EventFrame", nil, step2, "MinimalScrollBar")
actBar:SetPoint("TOPLEFT", actBox, "TOPRIGHT", 6, 0)
actBar:SetPoint("BOTTOMLEFT", actBox, "BOTTOMRIGHT", 6, 0)

local function isPicked(id) for _, v in ipairs(draft.acts) do if v == id then return true end end return false end
local function togglePick(id)
	for i, v in ipairs(draft.acts) do if v == id then table.remove(draft.acts, i) return end end
	if #draft.acts < P.MAX_ACTS then draft.acts[#draft.acts + 1] = id end
end

local refreshActs
local actView = CreateScrollBoxListLinearView()
actView:SetElementExtent(21)
actView:SetElementInitializer("Button", function(row, id)
	if not row.built then
		row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
		row.check:SetSize(20, 20)
		row.check:SetPoint("LEFT", 2, 0)
		row.check:EnableMouse(false)
		row.range = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		row.range:SetPoint("RIGHT", -6, 0)
		row.range:SetJustifyH("RIGHT")
		row.text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		row.text:SetPoint("LEFT", row.check, "RIGHT", 2, 0)
		row.text:SetPoint("RIGHT", row.range, "LEFT", -6, 0)
		row.text:SetJustifyH("LEFT")
		row.text:SetWordWrap(false)
		row.hl = row:CreateTexture(nil, "HIGHLIGHT")
		row.hl:SetAllPoints()
		row.hl:SetColorTexture(1, 0.82, 0, 0.1)
		row.mark = W.selectMark(row)
		row:SetScript("OnClick", function(self) togglePick(self.id) W.sound("IG_MAINMENU_OPTION_CHECKBOX_ON") refreshActs() end)
		row.built = true
	end
	row.id = id
	row.check:SetChecked(isPicked(id))
	row.mark:SetShown(isPicked(id))
	local hex = A.levelColor(id, UnitLevel("player"))
	row.text:SetText(hex .. (A.name(id) or "?") .. "|r")
	row.range:SetText(hex .. A.range(id) .. "|r")
end)
ScrollUtil.InitScrollBoxListWithScrollBar(actBox, actBar, actView)

-- Custom (or no activities): a free-text title instead of the list
local titleLabel = step2:CreateFontString(nil, "ARTWORK", "GameFontNormal")
titleLabel:SetPoint("TOPLEFT", back2, "BOTTOMLEFT", 8, -14)
titleLabel:SetText("What are you doing?")
local titleBox = CreateFrame("EditBox", nil, step2, "InputBoxTemplate")
titleBox:SetSize(400, 24)
titleBox:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 6, -4)
titleBox:SetAutoFocus(false)
titleBox:SetMaxLetters(P.TITLE_LEN)
titleBox:SetScript("OnEscapePressed", titleBox.ClearFocus)
titleBox:SetScript("OnEnterPressed", titleBox.ClearFocus)
titleBox:HookScript("OnTextChanged", function(self) draft.title = self:GetText() end)

local noteLabel = step2:CreateFontString(nil, "ARTWORK", "GameFontNormal")
noteLabel:SetPoint("BOTTOMLEFT", 16, 46)
noteLabel:SetText("Note")
local noteBox = CreateFrame("EditBox", nil, step2, "InputBoxTemplate")
noteBox:SetPoint("BOTTOMLEFT", 22, 18)
noteBox:SetPoint("RIGHT", -18, 0)
noteBox:SetHeight(24)
noteBox:SetAutoFocus(false)
noteBox:SetMaxLetters(P.NOTE_LEN)
noteBox:SetScript("OnEscapePressed", noteBox.ClearFocus)
noteBox:SetScript("OnEnterPressed", noteBox.ClearFocus)
noteBox:HookScript("OnTextChanged", function(self) draft.note = self:GetText() end)
local noteHint = noteBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
noteHint:SetPoint("LEFT", 2, 0)
noteHint:SetText("e.g. Lava run, have key, quick clear")
step2.noteLabel, step2.noteHint = noteLabel, noteHint
noteBox:HookScript("OnTextChanged", function(self) noteHint:SetShown(self:GetText() == "") end)

-- Quests & Zones: a Quests / Zones switch; Quests lists the player's quest log
local modeQuests = CreateFrame("Button", nil, step2, "UIPanelButtonTemplate")
modeQuests:SetSize(80, 22)
modeQuests:SetText("Quests")
local modeZones = CreateFrame("Button", nil, step2, "UIPanelButtonTemplate")
modeZones:SetSize(80, 22)
modeZones:SetText("Zones")
modeZones:SetPoint("TOPRIGHT", -16, -12)
modeQuests:SetPoint("RIGHT", modeZones, "LEFT", -4, 0)

-- Battlegrounds: list a group as usual, ask for a queue, or offer to queue people
local bgModes = {}
for i, spec in ipairs({ { "offer", "I can queue" }, { "want", "Queue me" }, { "group", "Group" } }) do
	local b = CreateFrame("Button", nil, step2, "UIPanelButtonTemplate")
	b:SetSize(92, 22)
	b:SetText(spec[2])
	if i == 1 then b:SetPoint("TOPRIGHT", -16, -12) else b:SetPoint("RIGHT", bgModes[i - 1], "LEFT", -4, 0) end
	b.mode = spec[1]
	b:SetScript("OnClick", function(self) draft.bgMode = self.mode W.sound("IG_MAINMENU_OPTION_CHECKBOX_ON") refreshActs() if list.refresh then list.refresh() end end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(spec[2])
		GameTooltip:AddLine(self.mode == "offer" and "You're at a battlemaster: list the battlegrounds you'll queue people for. They ask, you invite and click Join as Group."
			or self.mode == "want" and "Ask someone at a battlemaster to invite you and queue you, so you don't have to travel there."
			or "List a group for a battleground, with roles, like any other activity.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	bgModes[i] = b
end

local questBox = CreateFrame("Frame", nil, step2, "WowScrollBoxList")
questBox:SetPoint("TOPLEFT", filterBox, "BOTTOMLEFT", -10, -4)
questBox:SetPoint("BOTTOMRIGHT", -24, 74)
local questBar = CreateFrame("EventFrame", nil, step2, "MinimalScrollBar")
questBar:SetPoint("TOPLEFT", questBox, "TOPRIGHT", 6, 0)
questBar:SetPoint("BOTTOMLEFT", questBox, "BOTTOMRIGHT", 6, 0)
-- "Pick one" for quests, left of the Quests / Zones switch (where the dungeons say "Tick one or more")
local questHint = step2:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
questHint:SetPoint("RIGHT", modeQuests, "LEFT", -10, 0)
local questEmpty = step2:CreateFontString(nil, "ARTWORK", "GameFontDisable")
questEmpty:SetPoint("CENTER", questBox, "CENTER")
questEmpty:SetText("Your quest log is empty.")

local questView = CreateScrollBoxListLinearView()
questView:SetElementExtent(21)
questView:SetElementInitializer("Button", function(row, q)
	if not row.built then
		row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
		row.check:SetSize(20, 20)
		row.check:SetPoint("LEFT", 2, 0)
		row.check:EnableMouse(false)
		row.range = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		row.range:SetPoint("RIGHT", -6, 0)
		row.range:SetJustifyH("RIGHT")
		row.text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		row.text:SetPoint("LEFT", row.check, "RIGHT", 2, 0)
		row.text:SetPoint("RIGHT", row.range, "LEFT", -6, 0)
		row.text:SetJustifyH("LEFT")
		row.text:SetWordWrap(false)
		row.hl = row:CreateTexture(nil, "HIGHLIGHT")
		row.hl:SetAllPoints()
		row.hl:SetColorTexture(1, 0.82, 0, 0.1)
		row.mark = W.selectMark(row)
		row:SetScript("OnClick", function(self)
			draft.quest = self.q
			W.sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
			refreshActs()
		end)
		row.built = true
	end
	row.q = q
	local on = draft.quest and draft.quest.id == q.id
	row.check:SetChecked(on)
	row.mark:SetShown(on)
	local color = GetQuestDifficultyColor and GetQuestDifficultyColor(q.level or 0)
	local hex = color and ("|cff%02x%02x%02x"):format(color.r * 255, color.g * 255, color.b * 255) or WHITE
	row.text:SetText(hex .. (q.title or "?") .. "|r")
	row.range:SetText((q.level or 0) > 0 and (hex .. "(" .. q.level .. ")|r") or "")
end)
ScrollUtil.InitScrollBoxListWithScrollBar(questBox, questBar, questView)
modeQuests:SetScript("OnClick", function() draft.mode = "quests" refreshActs() end)
modeZones:SetScript("OnClick", function() draft.mode = "zones" refreshActs() end)

-- Warlock Summons: where to, and for how much
local summonPanel = CreateFrame("Frame", nil, step2)
summonPanel:SetPoint("TOPLEFT", back2, "BOTTOMLEFT", 0, -10)
summonPanel:SetPoint("RIGHT", -16, 0)
summonPanel:SetHeight(260)
local sIcon = summonPanel:CreateTexture(nil, "ARTWORK")
sIcon:SetSize(54, 54)
sIcon:SetPoint("TOPRIGHT", 0, -4)
sIcon:SetTexture(SUMMON_ICON)
local destLabel = summonPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
destLabel:SetPoint("TOPLEFT", 8, -6)
destLabel:SetText("Summoning to")
local destBox = CreateFrame("EditBox", nil, summonPanel, "InputBoxTemplate")
destBox:SetSize(260, 24)
destBox:SetPoint("TOPLEFT", destLabel, "BOTTOMLEFT", 6, -4)
destBox:SetAutoFocus(false)
destBox:SetMaxLetters(P.TITLE_LEN)
destBox:HookScript("OnTextChanged", function(self) draft.dest = self:GetText() end)
W.autocomplete(destBox, function(text)
	local items = {}
	for _, spot in ipairs(A.spots(text)) do items[#items + 1] = { text = spot, value = spot } end
	return items
end, function(v) destBox:SetText(v) destBox:ClearFocus() end, 268)
local hereBtn = CreateFrame("Button", nil, summonPanel, "UIPanelButtonTemplate")
hereBtn:SetSize(110, 22)
hereBtn:SetPoint("LEFT", destBox, "RIGHT", 8, 0)
hereBtn:SetText("Where I am")
hereBtn:SetScript("OnClick", function()
	local sub, zone = GetSubZoneText and GetSubZoneText() or "", GetZoneText and GetZoneText() or ""
	destBox:SetText(zone ~= "" and zone or sub)
	W.bounce(hereBtn, 1.06)
end)

local priceLabel = summonPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
priceLabel:SetPoint("TOPLEFT", destBox, "BOTTOMLEFT", -6, -14)
priceLabel:SetText("Price")
local function moneyBox(anchor, icon, x)
	local e = CreateFrame("EditBox", nil, summonPanel, "InputBoxTemplate")
	e:SetSize(60, 24)
	e:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, -4)
	e:SetAutoFocus(false)
	e:SetNumeric(true)
	e:SetMaxLetters(4)
	e:SetJustifyH("RIGHT")
	e:SetScript("OnEscapePressed", e.ClearFocus)
	e:SetScript("OnEnterPressed", e.ClearFocus)
	local t = summonPanel:CreateTexture(nil, "ARTWORK")
	t:SetSize(14, 14)
	t:SetPoint("LEFT", e, "RIGHT", 4, 0)
	t:SetTexture(icon)
	return e, t
end
local goldBox, goldIcon = moneyBox(priceLabel, "Interface\\MoneyFrame\\UI-GoldIcon", 6)
local silverBox = moneyBox(priceLabel, "Interface\\MoneyFrame\\UI-SilverIcon", 96)
silverBox:SetMaxLetters(2)
goldBox:HookScript("OnTextChanged", function(self) draft.gold = tonumber(self:GetText()) or 0 end)
silverBox:HookScript("OnTextChanged", function(self) draft.silver = math.min(99, tonumber(self:GetText()) or 0) end)
local presets = { { "Free", 0 }, { "50s", 50 }, { "1g", 100 }, { "2g", 200 }, { "5g", 500 } }
local prevPreset
for _, pr in ipairs(presets) do
	local b = CreateFrame("Button", nil, summonPanel, "UIPanelButtonTemplate")
	b:SetSize(48, 20)
	if prevPreset then b:SetPoint("LEFT", prevPreset, "RIGHT", 4, 0) else b:SetPoint("LEFT", silverBox, "RIGHT", 30, 0) end
	b:SetText(pr[1])
	b:SetScript("OnClick", function()
		goldBox:SetText(tostring(math.floor(pr[2] / 100))) silverBox:SetText(tostring(pr[2] % 100))
		W.bounce(b, 1.1)
	end)
	prevPreset = b
end
local sHelp = summonPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sHelp:SetPoint("TOPLEFT", goldBox, "BOTTOMLEFT", -6, -16)
sHelp:SetWidth(440)
sHelp:SetJustifyH("LEFT")
sHelp:SetSpacing(3)
sHelp:SetText(GREY .. "Players on every server see \"Summon to <place>\" with your price and can request one. They'll whisper you; invite them, and remember the Ritual of Summoning needs two helpers to click. Put \"have clickers\" in the note if you do.|r")

refreshActs = function()
	local c = draft.cat and A.category(draft.cat)
	local kind = catKind(c)
	local summon = kind == "summon"
	local questMode = kind == "quest" and draft.mode == "quests"
	local custom = not summon and not questMode and (not c or #c.acts == 0)
	local listMode = not summon and not questMode and not custom
	summonPanel:SetShown(summon)
	modeQuests:SetShown(kind == "quest") modeZones:SetShown(kind == "quest")
	for _, b in ipairs(bgModes) do b:SetShown(kind == "battle") b:SetEnabled(draft.bgMode ~= b.mode) end
	if kind == "battle" or kind == "quest" then pickedText:SetAlpha(0) else pickedText:SetAlpha(1) end
	modeQuests:SetEnabled(not questMode) modeZones:SetEnabled(questMode)
	questBox:SetShown(questMode) questBar:SetShown(questMode) questHint:SetShown(questMode)
	filterBox:SetShown(listMode or questMode) showAll:SetShown(false) showAllLabel:SetShown(false)
	if filterBox.Instructions then
		filterBox.Instructions:SetText(questMode and "Type to find, or shift-click a quest in your log" or "Type to find...")
	end
	actBox:SetShown(listMode) actBar:SetShown(listMode)
	titleLabel:SetShown(custom) titleBox:SetShown(custom)
	questEmpty:Hide()
	if questMode then
		local log = Q.log()
		local find = (filterBox:GetText() or ""):lower()
		local shown = {}
		for _, q in ipairs(log) do
			if find == "" or (q.title or ""):lower():find(find, 1, true) then shown[#shown + 1] = q end
		end
		questBox:SetDataProvider(CreateDataProvider(shown), ScrollBoxConstants.RetainScrollPosition)
		questEmpty:SetText(#log == 0 and "Your quest log is empty." or "No quest matches.")
		questEmpty:SetShown(#shown == 0)
		questHint:SetText(draft.quest and (GREEN .. "Quest picked|r") or (GREY .. "Pick one|r"))
		pickedText:SetShown(false)
		return
	end
	pickedText:SetShown(true)
	if summon then pickedText:SetText("") return end
	if custom then pickedText:SetText("") return end
	local text = filterBox:GetText() or ""
	local ids
	if text ~= "" then ids = A.search(text, c.id, 200) else ids = c.acts end
	local lvl, out = UnitLevel("player"), {}
	for _, id in ipairs(ids) do
		out[#out + 1] = id   -- every level, coloured; the list opens at the ones that fit you
	end
	actBox:SetDataProvider(CreateDataProvider(out), ScrollBoxConstants.RetainScrollPosition)
	if step2.scrollToFit and text == "" then
		step2.scrollToFit = nil
		for i, id in ipairs(out) do
			if A.fits(id, lvl) or isPicked(id) then
				if actBox.ScrollToElementDataIndex then pcall(actBox.ScrollToElementDataIndex, actBox, i, ScrollBoxConstants.AlignBegin) end
				break
			end
		end
	end
	local n = #draft.acts
	pickedText:SetText(n == 0 and (GREY .. "Tick one or more|r") or (GREEN .. n .. " selected|r"))
end
filterBox:HookScript("OnTextChanged", function() refreshActs() end)
filterBox:SetScript("OnEnterPressed", function(self)
	-- Enter ticks the best match (in Quests, picks the first quest that matches)
	local c = draft.cat and A.category(draft.cat)
	if catKind(c) == "quest" and draft.mode == "quests" then
		local find = (self:GetText() or ""):lower()
		for _, q in ipairs(Q.log()) do
			if find ~= "" and (q.title or ""):lower():find(find, 1, true) then draft.quest = q break end
		end
		self:SetText("")
		self:ClearFocus()
		refreshActs()
		return
	end
	local best = c and A.search(self:GetText(), c.id, 1)[1]
	if best and not isPicked(best) then togglePick(best) end
	self:SetText("")
	self:ClearFocus()
	refreshActs()
end)
showAll:SetScript("OnClick", function() refreshActs() end)

openCategory = function(catID)
	if draft.cat ~= catID then
		-- keep picks that belong to the new category (the quick search already put one in)
		local keep = {}
		for _, id in ipairs(draft.acts) do if A.info[id] and A.info[id].cat == catID then keep[#keep + 1] = id end end
		draft.acts = keep
	end
	draft.cat = catID
	local c = A.category(catID)
	catTitle:SetText(c and c.name or "Custom")
	if catKind(c) == "summon" then
		destBox:SetText(draft.dest or "")
		goldBox:SetText(tostring(draft.gold or 0)) silverBox:SetText(tostring(draft.silver or 0))
	end
	W.fadeIn(step2, 0.2)
	step2.scrollToFit = true
	step1:Hide() step2:Show()
	noteBox:SetText(draft.note or "")
	titleBox:SetText(draft.title or "")
	refreshActs()
	if list.refresh then list.refresh() end
end
back2:SetScript("OnClick", function() step2:Hide() step1:Show() W.fadeIn(step1, 0.2) if list.refresh then list.refresh() end end)

-- footer: Back | status | Delist | List Group
local backBtn = CreateFrame("Button", nil, list.footer, "UIPanelButtonTemplate")
backBtn:SetSize(110, 24)
backBtn:SetPoint("BOTTOMLEFT")
backBtn:SetText("Back")
backBtn:SetScript("OnClick", function() back2:Click() end)
local listBtn = CreateFrame("Button", nil, list.footer, "UIPanelButtonTemplate")
listBtn:SetSize(140, 24)
listBtn:SetPoint("BOTTOMRIGHT")
local delistBtn = CreateFrame("Button", nil, list.footer, "UIPanelButtonTemplate")
delistBtn:SetSize(90, 24)
delistBtn:SetPoint("RIGHT", listBtn, "LEFT", -6, 0)
delistBtn:SetText("Delist")
delistBtn:SetScript("OnClick", function() if OpenGroup_Nearby then OpenGroup_Nearby.gameUnlist() end L.delist() end)
local listStatus = list.footer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
listStatus:SetPoint("LEFT", backBtn, "RIGHT", 10, 0)
listStatus:SetPoint("RIGHT", delistBtn, "LEFT", -10, 0)
listStatus:SetJustifyH("LEFT")
listStatus:SetWordWrap(false)

-- the List click: our listing (hidden whispers, no click needed) and, for activities the game knows,
-- the game's own Group Finder listing: the click's one restricted call, so nothing else here
-- (no /who, no chat channel post)
listBtn:SetScript("OnClick", function()
	noteBox:ClearFocus() titleBox:ClearFocus() destBox:ClearFocus()
	local cc = draft.cat and A.category(draft.cat)
	local kind = catKind(cc)
	if kind == "summon" then
		local dest = P.clean(draft.dest or "", P.TITLE_LEN)
		if dest == "" then destBox:SetFocus() UIErrorsFrame:AddMessage("Where are you summoning to?", 1, .1, .1) return end
		local price = (draft.gold or 0) * 10000 + (draft.silver or 0) * 100
		if L.post(dest, draft.note, 0, P.SUMMON_CAT, {}, price) then
			db().summon = { dest = dest, gold = draft.gold, silver = draft.silver }
		end
		return
	end
	if kind == "battle" and draft.bgMode ~= "group" then
		local cAll = draft.cat and A.category(draft.cat)
		if cAll and #cAll.acts > 0 and #draft.acts == 0 then UIErrorsFrame:AddMessage("Tick at least one battleground.", 1, .1, .1) return end
		local title = (cAll and #cAll.acts > 0) and "" or (draft.title ~= "" and draft.title or "Battleground")
		L.post(title, draft.note, 0, draft.bgMode == "offer" and P.BGQ_OFFER or P.BGQ_WANT, draft.acts)
		return
	end
	if kind == "quest" and draft.mode == "quests" then
		if not draft.quest then UIErrorsFrame:AddMessage("Pick a quest, or shift-click one in your quest log.", 1, .1, .1) return end
		local gs = groupSpots()
		if gs then draft.need = P.needOfSpots(gs) end
		if draft.need == 0 then UIErrorsFrame:AddMessage("Pick at least one role.", 1, .1, .1) return end
		L.post(draft.quest.title, draft.note, draft.need, cc and not cc.fallback and cc.id or 0, {}, 0, draft.quest.id, gs)
		return
	end
	local gs = groupSpots()
	if gs then draft.need = P.needOfSpots(gs) end
	if draft.need == 0 then
		UIErrorsFrame:AddMessage(GetNumGroupMembers() <= 1 and "Pick at least one role you can play." or "Pick at least one role you need.", 1, .1, .1)
		return
	end
	local c = draft.cat and A.category(draft.cat)
	local title = draft.title or ""
	if c and #c.acts > 0 then title = "" end
	if (not c or #c.acts == 0) and title == "" then titleBox:SetFocus() UIErrorsFrame:AddMessage("Say what you're doing.", 1, .1, .1) return end
	if c and #c.acts > 0 and #draft.acts == 0 then UIErrorsFrame:AddMessage("Tick at least one activity.", 1, .1, .1) return end
	local wireCat = (c and not c.fallback) and c.id or 0
	if L.post(title, draft.note, draft.need, wireCat, draft.acts, nil, nil, gs) then
		db().draft = { cat = draft.cat, acts = { unpack(draft.acts) }, need = draft.need, note = draft.note, title = draft.title }
		if c and not c.fallback and #draft.acts > 0 and OpenGroup_Nearby then
			OpenGroup_Nearby.gameList(draft.acts, draft.need, GetNumGroupMembers() <= 1)
		end
	end
end)

function list.refresh()
	paintRoles()
	local inStep2 = step2:IsShown()
	backBtn:SetEnabled(inStep2)
	listBtn:SetEnabled(inStep2 or L.mine ~= nil)
	listBtn:SetText(L.mine and "Update Listing" or "List Group")
	delistBtn:SetShown(L.mine ~= nil)
	listStatus:ClearAllPoints()
	listStatus:SetPoint("LEFT", backBtn, "RIGHT", 10, 0)
	listStatus:SetPoint("RIGHT", L.mine and delistBtn or listBtn, "LEFT", -10, 0)
	local peers = L.count(L.peers)
	local g = not L.mine and L.groupListing
	if g and not (UnitIsGroupLeader and UnitIsGroupLeader("player")) then
		-- our leader is listing the group: read only here
		listBtn:SetEnabled(false)
		listStatus:SetText(GREEN .. g.leader .. " is listing this group|r" .. GREY .. "  for " .. L.titleOf(g.l) .. "|r")
	elseif L.mine then
		local inGame = OpenGroup_Nearby and OpenGroup_Nearby.game.listed
		listStatus:SetText(GREEN .. "Listed|r" .. GREY .. "  on every server you can reach" .. (inGame and ", and in the game's Group Finder" or "") .. "|r")
	elseif peers == 0 then
		listStatus:SetText(GREY .. "No OpenGroup players known yet: see Network.|r")
	else
		listStatus:SetText(GREY .. "Seen by " .. peers .. (peers == 1 and " OpenGroup player" or " OpenGroup players") .. "|r")
	end
end
-- the game's real activity list replaced the built-in one: drop picks of the stand-in ids
A.onReload = function()
	filterActs = {}
	local keep = {}
	for _, id in ipairs(draft.acts) do if A.info[id] then keep[#keep + 1] = id end end
	draft.acts = keep
	if win:IsShown() then
		if list.content:IsShown() then layoutBanners() end
		L.onChange()
	end
end

list.onShow = function()
	local saved = db().draft
	if type(saved) == "table" and not draft.loaded then
		draft.cat, draft.need, draft.note, draft.title = saved.cat, P.int(saved.need, 0, 7) or 0, saved.note or "", saved.title or ""
		draft.acts = {}
		for _, id in ipairs(type(saved.acts) == "table" and saved.acts or {}) do if A.info[id] then draft.acts[#draft.acts + 1] = id end end
	end
	local sm = db().summon
	if type(sm) == "table" and not draft.summonLoaded then
		draft.dest, draft.gold, draft.silver = sm.dest or "", P.int(sm.gold, 0, 9999) or 0, P.int(sm.silver, 0, 99) or 0
	end
	draft.summonLoaded = true
	draft.loaded = true
	layoutBanners()
	list.refresh()
end

-- --------------------------------------------------------------------------------------------
-- NETWORK

local net = page("network")
local netTitle = net.header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
netTitle:SetPoint("TOPLEFT", 4, -10)
netTitle:SetText("Network")
local netSub = net.header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
netSub:SetPoint("TOPLEFT", netTitle, "BOTTOMLEFT", 0, -6)
netSub:SetWidth(400)
netSub:SetJustifyH("LEFT")
netSub:SetText("Listings travel between OpenGroup players in hidden whispers, so they reach every server. Nothing shows in anyone's chat.")

-- top card: your server and how big the network is
local card = CreateFrame("Frame", nil, net.content)
card:SetPoint("TOPLEFT", 10, -10) card:SetPoint("TOPRIGHT", -10, -10)
card:SetHeight(74)
card.bg = card:CreateTexture(nil, "BACKGROUND")
card.bg:SetAllPoints()
W.gradient(card.bg, 0.16, 0.1, 0.04, 0.9, 0.07, 0.05, 0.03, 0.9)
W.edge(card, 0.62, 0.48, 0.22, 1)
local cardIcon = card:CreateTexture(nil, "ARTWORK")
cardIcon:SetSize(50, 50)
cardIcon:SetPoint("LEFT", 12, 0)
cardIcon:SetTexture("Interface\\Icons\\INV_Misc_Gem_Amethyst_02")
cardIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local shardBig = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
shardBig:SetPoint("TOPLEFT", cardIcon, "TOPRIGHT", 14, -2)
local peersText = card:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
peersText:SetPoint("TOPLEFT", shardBig, "BOTTOMLEFT", 0, -6)

local function sectionBar(anchor, text, y)
	local f = CreateFrame("Frame", nil, net.content)
	f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y or -14)
	f:SetPoint("RIGHT", net.content, "RIGHT", -10, 0)
	f:SetHeight(28)
	W.bar(f)
	f.text = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	f.text:SetPoint("LEFT", 10, 0)
	f.text:SetText(text)
	return f
end

-- finding players: mostly automatic now; the button runs one more /who search
local findBar = sectionBar(card, "Finding players")
local findHelp = net.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
findHelp:SetPoint("TOPLEFT", findBar, "BOTTOMLEFT", 6, -8)
findHelp:SetPoint("RIGHT", net.content, "RIGHT", -16, 0)
findHelp:SetJustifyH("LEFT")
findHelp:SetSpacing(3)
findHelp:SetText("OpenGroup grows by itself: it quietly says hello to your friends, guild, group and anyone you whisper, " ..
	"and every OpenGroup player you meet shares who they know. Clicking around OpenGroup also runs a /who search now and then (it sees every server).")
local scanBtn = CreateFrame("Button", nil, net.content, "UIPanelButtonTemplate")
scanBtn:SetSize(200, 26)
scanBtn:SetPoint("TOPLEFT", findHelp, "BOTTOMLEFT", -2, -10)
scanBtn:SetText("Search now")
scanBtn:SetScript("OnClick", function() L.scan.click() end)
local scanSpin = W.spinner(net.content, 20)
scanSpin:SetPoint("LEFT", scanBtn, "RIGHT", 8, 0)
-- passing your server's LookingForGroup posts on to OpenGroup players on other servers (on by default)
do
	local cb = CreateFrame("CheckButton", nil, net.content, "UICheckButtonTemplate")
	cb:SetSize(22, 22)
	-- its own row under Search now; the next section starts below it
	cb:SetPoint("TOPLEFT", scanBtn, "BOTTOMLEFT", 0, -8)
	local lbl = net.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	lbl:SetPoint("LEFT", cb, "RIGHT", 4, 1)
	lbl:SetText("Share LFG chat from my server")
	net.shareCheck = cb
	cb:SetScript("OnShow", function(self) self:SetChecked(db().shareChat ~= false) end)
	cb:SetScript("OnClick", function(self) db().shareChat = self:GetChecked() and true or false end)
	cb:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Share LFG chat from my server")
		GameTooltip:AddLine("When you're the OpenGroup player passing on your server's groups, recent LookingForGroup posts go to OpenGroup players on other servers too (the poster's name, the post and its age). Same realm and faction only.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	cb:SetScript("OnLeave", GameTooltip_Hide)
end
local scanText = net.content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
scanText:SetPoint("LEFT", scanBtn, "RIGHT", 34, 0)
scanText:SetPoint("RIGHT", net.content, "RIGHT", -16, 0)
scanText:SetJustifyH("LEFT")
scanText:SetWordWrap(false)

-- who you know, by shard, newest first
local peersBar = sectionBar(net.shareCheck, "OpenGroup players", -12)
peersBar:SetPoint("LEFT", net.content, "LEFT", 10, 0)
local shardChips = net.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
shardChips:SetPoint("TOPLEFT", peersBar, "BOTTOMLEFT", 6, -8)
shardChips:SetPoint("RIGHT", net.content, "RIGHT", -16, 0)
-- hover the shard counts: how much of each shard's Group Finder matches yours (shared or not)
do
	local hover = CreateFrame("Frame", nil, net.content)
	hover:SetPoint("TOPLEFT", shardChips, "TOPLEFT", 0, 2)
	hover:SetPoint("BOTTOMRIGHT", shardChips, "BOTTOMRIGHT", 0, -2)
	hover:EnableMouse(true)
	hover:SetScript("OnEnter", function(self)
		local Nb = OpenGroup_Nearby
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(L.CHAN .. " numbers and servers")
		GameTooltip:AddLine("The number the game puts after Trade, LookingForGroup and General (Trade - City 47) isn't a server. Several numbers can share one hidden server, and with it one Group Finder, LookingForGroup channel and Trade chat. OpenGroup shows it as " .. L.CHAN .. " 47.", 1, 1, 1, true)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Your server: " .. (Nb and Nb.serverName() or "?"), .25, 1, .25, true)
		local ov = Nb and Nb.overlapText and Nb.overlapText()
		if ov then
			GameTooltip:AddLine("How much of each number's Group Finder you already see in yours:", 1, 1, 1, true)
			for part in ov:gmatch("[^,]+") do GameTooltip:AddLine("  " .. part:gsub("^%s+", ""), .9, .9, .9) end
			GameTooltip:AddLine("Close to 100% means the same server as you; close to 0% another server.", .6, .6, .6, true)
		else
			GameTooltip:AddLine("Nothing passed on from another number yet, so OpenGroup can't tell which share your server.", .8, .8, .8, true)
		end
		GameTooltip:Show()
	end)
	hover:SetScript("OnLeave", GameTooltip_Hide)
end
shardChips:SetJustifyH("LEFT")
local peerRows = {}
for i = 1, 9 do
	local r = CreateFrame("Frame", nil, net.content)
	r:SetHeight(20)
	r:SetPoint("TOPLEFT", i == 1 and shardChips or peerRows[i - 1], "BOTTOMLEFT", 0, i == 1 and -8 or -1)
	r:SetPoint("RIGHT", net.content, "RIGHT", -16, 0)
	r.dot = r:CreateTexture(nil, "ARTWORK")
	r.dot:SetSize(8, 8)
	r.dot:SetPoint("LEFT", 2, 0)
	r.name = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	r.name:SetPoint("LEFT", r.dot, "RIGHT", 8, 0)
	r.info = r:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	r.info:SetPoint("RIGHT", 0, 0)
	peerRows[i] = r
end

local stats = net.content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
stats:SetPoint("BOTTOMLEFT", 14, 10)
stats:SetPoint("BOTTOMRIGHT", -14, 10)
stats:SetJustifyH("LEFT")

-- footer: the cross-shard test
local pingBtn = CreateFrame("Button", nil, net.footer, "UIPanelButtonTemplate")
pingBtn:SetSize(200, 24)
pingBtn:SetPoint("RIGHT")
pingBtn:SetText("Test connection to target")
pingBtn:SetScript("OnClick", function()
	local name = L.unitName("target")
	if not name or not UnitIsPlayer("target") then UIErrorsFrame:AddMessage("Target a player who runs OpenGroup first.", 1, .1, .1) return end
	L.ping(name)
end)
local versionText = net.footer:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
versionText:SetPoint("LEFT", 6, 0)

function net.refresh()
	local myShard = L.shard()
	local big, small = OpenGroup_Nearby.serverHeadline()
	shardBig:SetText(GOLD .. big .. "|r")
	net.headNote = small
	local peers, shards, online = L.count(L.peers), {}, 0
	local live = L.live()
	for name, p in pairs(L.peers) do
		if p.shard and p.shard > 0 then shards[p.shard] = (shards[p.shard] or 0) + 1 end
		if live[name] and time() - (p.seen or 0) < 900 then online = online + 1 end
	end
	local ns = L.count(shards)
	peersText:SetText(("%d %s known on %d %s   %s%d heard from lately|r"):format(peers, peers == 1 and "player" or "players",
		ns, ns == 1 and (L.CHAN .. " number") or (L.CHAN .. " numbers"), GREEN, online) .. (net.headNote and ("   " .. GREY .. net.headNote .. "|r") or ""))
	local s = L.scan
	scanText:SetText(s.status or "")
	scanBtn:SetEnabled(not s.inFlight)
	if s.inFlight and not scanSpin:IsShown() then scanSpin:Start() elseif not s.inFlight and scanSpin:IsShown() then scanSpin:Stop() end
	local keys = {}
	for k in pairs(shards) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return shards[a] > shards[b] end)
	local parts = {}
	for i, k in ipairs(keys) do
		if i > 10 then parts[#parts + 1] = GREY .. "+" .. (#keys - 10) .. " more|r" break end
		parts[#parts + 1] = ("%s" .. L.CHAN .. " %d|r %s%d|r"):format(OpenGroup_Nearby.sameServer(k) and GREEN or GOLD, k, GREY, shards[k])
	end
	shardChips:SetText(#parts > 0 and table.concat(parts, "    ") or (GREY .. "Nobody yet. Players appear here as OpenGroup finds them.|r"))
	local recent = L.recent(#peerRows)
	for i, r in ipairs(peerRows) do
		local name = recent[i]
		if name then
			local p = L.peers[name]
			local fresh = live[name] and time() - (p.seen or 0) < 900
			r.dot:SetColorTexture(fresh and 0.25 or 0.4, fresh and 1 or 0.4, fresh and 0.25 or 0.4, 1)
			r.name:SetText(L.short(name) .. (p.level and p.level > 0 and (GREY .. "  " .. p.level .. "|r") or ""))
			-- shard 0 means we haven't heard it yet (they passed on a listing, but no hello so far)
			local shardText = (p.shard or 0) > 0 and (L.CHAN .. " " .. p.shard) or (L.CHAN .. " unknown")
			r.info:SetText(("%s%s|r   %s"):format(((p.shard or 0) > 0 and OpenGroup_Nearby.sameServer(p.shard)) and GREEN or (p.shard or 0) > 0 and GOLD or GREY, shardText,
				live[name] and (ago(time() - (p.seen or 0)) .. " ago") or "offline"))
			-- a short window: rows that would run into the stats line stay hidden
			local bottom, floor = r:GetBottom(), stats:GetTop()
			r:SetShown(not (type(bottom) == "number" and type(floor) == "number" and bottom < floor + 4))
		else r:Hide() end
	end
	local st = L.stats
	stats:SetText(("Sent %d   received %d   hellos %d   shared with you %d%s%s"):format(st.sent, st.got, st.probes or 0, st.learned or 0,
		st.refused > 0 and ("   |cffff6060refused " .. st.refused .. "|r") or "",
		L.queued() > 0 and ("   " .. L.queued() .. " waiting") or ""))
	versionText:SetText("OpenGroup " .. L.VERSION .. (L.newest and ("   |cffff8040" .. L.newest .. " is out|r") or ""))
end

-- --------------------------------------------------------------------------------------------
-- the "Listed" light on the title bar, and the toast when a listing goes out

local listedLight = CreateFrame("Frame", nil, win)
listedLight:SetSize(90, 18)
listedLight:SetPoint("TOPRIGHT", -34, -3)
listedLight:SetFrameLevel(win:GetFrameLevel() + 10)
local dot = listedLight:CreateTexture(nil, "OVERLAY")
dot:SetSize(16, 16)
dot:SetPoint("LEFT")
dot:SetAtlas("groupfinder-icon-greencheckmark")
local dotText = listedLight:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
dotText:SetPoint("LEFT", dot, "RIGHT", 3, 0)
dotText:SetText(GREEN .. "Listed|r")
W.pulse(dot, 0.3, 0.8):Play()
listedLight:Hide()

-- the queue eye: while listed, the game's Looking For Group eye turns over the portrait
do
	local holder = CreateFrame("Frame", nil, win)
	holder:SetSize(60, 60)
	local portrait = win.GetPortrait and win:GetPortrait() or win.portrait
	if portrait then holder:SetPoint("CENTER", portrait, "CENTER") else holder:SetPoint("TOPLEFT", -5, 7) end
	holder:SetFrameLevel(win:GetFrameLevel() + 20)
	local eye = holder:CreateTexture(nil, "OVERLAY")
	eye:SetAllPoints()
	eye:SetTexture("Interface\\LFGFrame\\LFG-Eye")
	eye:SetTexCoord(0, 0.125, 0, 0.25)
	holder:Hide()
	local animate = AnimateTexCoords
	holder:SetScript("OnUpdate", function(_, el)
		if animate then pcall(animate, eye, 512, 256, 64, 64, 29, el, 0.08) end
	end)
	local fadeIn = holder:CreateAnimationGroup()
	local a = fadeIn:CreateAnimation("Alpha") a:SetFromAlpha(0) a:SetToAlpha(1) a:SetDuration(0.4)
	local sc = fadeIn:CreateAnimation("Scale")
	if sc.SetScaleFrom then sc:SetScaleFrom(0.6, 0.6) sc:SetScaleTo(1, 1) else sc:SetScale(1, 1) end
	sc:SetDuration(0.4) sc:SetSmoothing("OUT")
	win.eyeStart = function() holder:Show() fadeIn:Stop() fadeIn:Play() end
	win.eyeStop = function() holder:Hide() end
	holder:EnableMouse(true)
	holder:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Listed")
		if L.mine then GameTooltip:AddLine(L.titleOf(L.mine), 1, 1, 1) end
		GameTooltip:AddLine("OpenGroup players on every server can see you.", .8, .8, .8, true)
		GameTooltip:Show()
	end)
	holder:SetScript("OnLeave", GameTooltip_Hide)
	holder:SetScript("OnMouseUp", function() showPage("list") end)
end
listedLight:SetScript("OnMouseUp", function() showPage("list") end)
listedLight:EnableMouse(true)

local toast = CreateFrame("Frame", nil, win)
toast:SetSize(360, 96)
toast:SetPoint("CENTER", body, "CENTER", 0, 40)
toast:SetFrameLevel(win:GetFrameLevel() + 40)
toast.bg = toast:CreateTexture(nil, "BACKGROUND")
toast.bg:SetAllPoints()
toast.bg:SetColorTexture(0, 0, 0, 0.82)
toast.edge = toast:CreateTexture(nil, "BORDER")
toast.edge:SetPoint("TOPLEFT", -1, 1) toast.edge:SetPoint("BOTTOMRIGHT", 1, -1)
toast.edge:SetColorTexture(1, 0.82, 0, 0.6)
toast.edge:SetDrawLayer("BACKGROUND", -1)
toast.glow = toast:CreateTexture(nil, "ARTWORK")
toast.glow:SetPoint("TOPLEFT", -40, 30) toast.glow:SetPoint("BOTTOMRIGHT", 40, -30)
toast.glow:SetTexture("Interface\\Cooldown\\star4")
toast.glow:SetBlendMode("ADD")
toast.glow:SetVertexColor(1, 0.8, 0.3, 0.5)
toast.icon = toast:CreateTexture(nil, "OVERLAY")
toast.icon:SetSize(52, 52)
toast.icon:SetPoint("LEFT", 18, 0)
toast.icon:SetAtlas("groupfinder-icon-greencheckmark")
toast.title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
toast.title:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 14, -4)
toast.sub = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
toast.sub:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -6)
toast.sub:SetWidth(260)
toast.sub:SetJustifyH("LEFT")
toast:Hide()
do
	local g = toast:CreateAnimationGroup()
	local s1 = g:CreateAnimation("Scale")
	if s1.SetScaleFrom then s1:SetScaleFrom(0.7, 0.7) s1:SetScaleTo(1, 1) else s1:SetScale(1, 1) end
	s1:SetDuration(0.22) s1:SetSmoothing("OUT") s1:SetOrder(1)
	local a1 = g:CreateAnimation("Alpha") a1:SetFromAlpha(0) a1:SetToAlpha(1) a1:SetDuration(0.18) a1:SetOrder(1)
	local hold = g:CreateAnimation("Alpha") hold:SetFromAlpha(1) hold:SetToAlpha(1) hold:SetDuration(1.6) hold:SetOrder(2)
	local a2 = g:CreateAnimation("Alpha") a2:SetFromAlpha(1) a2:SetToAlpha(0) a2:SetDuration(0.45) a2:SetOrder(3)
	g:SetScript("OnFinished", function() toast:Hide() end)
	toast.anim = g
	local gg = toast.glow:CreateAnimationGroup()
	local r = gg:CreateAnimation("Rotation") r:SetDegrees(90) r:SetDuration(2.4)
	local ga = gg:CreateAnimation("Alpha") ga:SetFromAlpha(0.9) ga:SetToAlpha(0) ga:SetDuration(2.2) ga:SetSmoothing("IN")
	toast.glowAnim = gg
end
local function showToast(title, sub, icon)
	toast.title:SetText(title)
	toast.sub:SetText(sub)
	if icon then toast.icon:SetTexture(icon) toast.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	else toast.icon:SetAtlas("groupfinder-icon-greencheckmark") toast.icon:SetTexCoord(0, 1, 0, 1) end
	toast:Show()
	toast.anim:Stop() toast.anim:Play()
	toast.glowAnim:Stop() toast.glowAnim:Play()
end

-- --------------------------------------------------------------------------------------------
-- the queued banner: while listed, every tab shows what you're queued for at the top, with the
-- turning eye, a soft glow on its edge and a light that sweeps across it now and then

local ROLE_NAMES = { [1] = "Tank", [2] = "Healer", [4] = "Damage" }
local function roleNames(need)
	local out = {}
	for _, r in ipairs({ 1, 2, 4 }) do if need % (r * 2) >= r then out[#out + 1] = ROLE_NAMES[r] end end
	return #out > 0 and table.concat(out, ", ") or "any role"
end
local function clock(sec)
	sec = math.max(0, math.floor(sec))
	if sec >= 3600 then return ("%d:%02d:%02d"):format(sec / 3600, (sec % 3600) / 60, sec % 60) end
	return ("%d:%02d"):format(sec / 60, sec % 60)
end

local qbar = CreateFrame("Button", nil, body)
qbar:SetPoint("TOPLEFT", 6, -6)
qbar:SetPoint("TOPRIGHT", -6, -6)
qbar:SetHeight(60)
qbar:SetFrameLevel(body:GetFrameLevel() + 15)
qbar.bg = qbar:CreateTexture(nil, "BACKGROUND")
qbar.bg:SetAllPoints()
W.gradient(qbar.bg, 0.2, 0.14, 0.05, 0.98, 0.09, 0.065, 0.035, 0.98)
qbar.wash = qbar:CreateTexture(nil, "BACKGROUND", nil, 1)
qbar.wash:SetPoint("TOPLEFT") qbar.wash:SetPoint("BOTTOMLEFT")
qbar.wash:SetWidth(180)
W.gradient(qbar.wash, 0.3, 1, 0.3, 0.16, 0.3, 1, 0.3, 0)
-- the game's own dialog border (the classic bevelled edge), warming slowly between bronze and gold
qbar.border = CreateFrame("Frame", nil, qbar, BackdropTemplateMixin and "BackdropTemplate" or nil)
qbar.border:SetPoint("TOPLEFT", -5, 5) qbar.border:SetPoint("BOTTOMRIGHT", 5, -5)
qbar.border:SetFrameLevel(qbar:GetFrameLevel() + 3)
if qbar.border.SetBackdrop then
	qbar.border:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16 })
	qbar.border:SetBackdropBorderColor(0.8, 0.65, 0.4, 1)
else
	W.edge(qbar, 0.62, 0.48, 0.22, 1)
end
qbar.sheen = W.sheen(qbar, 70, 3.5)

qbar.eyeGlow = qbar:CreateTexture(nil, "ARTWORK")
qbar.eyeGlow:SetTexture("Interface\\Cooldown\\star4")
qbar.eyeGlow:SetBlendMode("ADD")
qbar.eyeGlow:SetVertexColor(0.4, 1, 0.4, 1)
qbar.eyeGlow:SetSize(70, 70)
qbar.eyeGlow:SetPoint("CENTER", qbar, "LEFT", 35, 0)
W.pulse(qbar.eyeGlow, 0.25, 2.2):Play()   -- a slow breath, no spin
qbar.eye = qbar:CreateTexture(nil, "OVERLAY")
qbar.eye:SetSize(46, 46)
qbar.eye:SetPoint("LEFT", 12, 0)
qbar.eye:SetTexture("Interface\\LFGFrame\\LFG-Eye")
qbar.eye:SetTexCoord(0, 0.125, 0, 0.25)

qbar.top = qbar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
qbar.top:SetPoint("TOPLEFT", qbar.eye, "TOPRIGHT", 12, -2)
qbar.title = qbar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
qbar.title:SetPoint("TOPLEFT", qbar.top, "BOTTOMLEFT", 0, -4)
qbar.title:SetJustifyH("LEFT")
qbar.title:SetWordWrap(false)

qbar.leave = CreateFrame("Button", nil, qbar, "UIPanelButtonTemplate")
qbar.leave:SetSize(72, 22)
qbar.leave:SetPoint("RIGHT", -10, 0)
qbar.leave:SetText("Leave")
qbar.leave:SetScript("OnClick", function() if OpenGroup_Nearby then OpenGroup_Nearby.gameUnlist() end L.delist() end)
-- auto invite: turns it on and off (groups only); the label says whether it's running
qbar.auto = CreateFrame("Button", nil, qbar, "UIPanelButtonTemplate")
qbar.auto:SetSize(92, 22)
qbar.auto:SetPoint("RIGHT", qbar.leave, "LEFT", -6, 0)
qbar.auto:SetText("Auto Invite")
qbar.auto:SetScript("OnClick", function() if OpenGroup_AutoInvite then OpenGroup_AutoInvite.toggle() end end)
-- find players for the first open spot (groups only)
qbar.find = CreateFrame("Button", nil, qbar, "UIPanelButtonTemplate")
qbar.find:SetSize(92, 22)
qbar.find:SetPoint("RIGHT", qbar.auto, "LEFT", -6, 0)
-- one line in LookingForGroup chat, its own click (the game wants one for chat channels)
qbar.lfg = CreateFrame("Button", nil, qbar, "UIPanelButtonTemplate")
qbar.lfg:SetSize(92, 22)
qbar.lfg:SetText("Post in LFG")
qbar.lfg:SetScript("OnClick", function() if L.postLFGNow then L.postLFGNow() end end)
qbar.lfg:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText("Post in LFG chat")
	GameTooltip:AddLine("Posts one line about your listing in your LookingForGroup channel, so players without OpenGroup see it. Each click posts once.", 1, 1, 1, true)
	GameTooltip:Show()
end)
qbar.lfg:SetScript("OnLeave", GameTooltip_Hide)
qbar.find:SetText("Find players")
qbar.find:SetScript("OnClick", function()
	local spots = L.mine and type(L.mine.spots) == "table" and L.mine.spots or {}
	if OpenGroup_UI and OpenGroup_UI.find then OpenGroup_UI.find.open(spots[1] or P.spot(0)) end
end)
qbar.roles = {}
for i = 3, 1, -1 do
	local t = qbar:CreateTexture(nil, "OVERLAY")
	t:SetSize(26, 26)
	if i == 3 then t:SetPoint("RIGHT", qbar.lfg, "LEFT", -10, 0) else t:SetPoint("RIGHT", qbar.roles[i + 1], "LEFT", -2, 0) end
	qbar.roles[i] = t
end
qbar.title:SetPoint("RIGHT", qbar.roles[1], "LEFT", -10, 0)
qbar:Hide()

do
	local g = qbar:CreateAnimationGroup()
	local t1 = g:CreateAnimation("Translation") t1:SetOffset(0, 14) t1:SetDuration(0) t1:SetOrder(1)
	local t2 = g:CreateAnimation("Translation") t2:SetOffset(0, -14) t2:SetDuration(0.35) t2:SetOrder(2) t2:SetSmoothing("OUT")
	local a = g:CreateAnimation("Alpha") a:SetFromAlpha(0) a:SetToAlpha(1) a:SetDuration(0.35) a:SetOrder(2)
	qbar.enter = g
end

local function paintQueueBar()
	local m = L.mine
	-- a party member: our leader's listing, shown read only
	local member = not m and L.groupListing
	if member then m = member.l m.at = member.at end
	if not m then return end
	local summon = m.cat == P.SUMMON_CAT
	local solo = GetNumGroupMembers() <= 1
	local bgq = isBGQ(m.cat)
	local what = summon and "Selling summons" or m.cat == P.BGQ_OFFER and "Queueing people for" or m.cat == P.BGQ_WANT and "Waiting for a queue"
		or solo and ("Queued as " .. roleNames(m.need or 0)) or ("Looking for " .. roleNames(m.need or 0))
	local n = browse.matchCount or 0
	local noun = m.cat == P.BGQ_OFFER and (n == 1 and " player wants one" or " players want one")
		or m.cat == P.BGQ_WANT and (n == 1 and " player can queue you" or " players can queue you")
		or iAmLeader() and (n == 1 and " player for you" or " players for you") or (n == 1 and " group for you" or " groups for you")
	local found = summon and "" or ("   " .. (n > 0 and GOLD or GREY) .. n .. noun .. "|r")
	qbar.top:SetText(GREEN .. what .. "|r" .. GREY .. "   " .. clock(time() - m.at) .. "|r" .. found)
	qbar.title:SetText((bgq and bgNames(m) or L.titleOf(m)) .. (summon and ("  " .. GOLD .. coins(m.price) .. "|r") or ""))
	local slots = {}
	if summon then slots[1] = "summon" elseif bgq then slots[1] = "bgq" else for _, r in ipairs(ROLES) do if has(m.need, r) then slots[#slots + 1] = r end end end
	for i = 1, 3 do
		local t = qbar.roles[3 - #slots + i]
		local r = slots[i]
		if t and (r == "summon" or r == "bgq") then t:SetTexture(r == "summon" and SUMMON_ICON or BGQ_ICON) t:SetTexCoord(0.07, 0.93, 0.07, 0.93) t:Show()
		elseif t and r then t:SetAtlas(W.ROLE_ATLAS[r]) t:SetTexCoord(0, 1, 0, 1) t:Show() end
	end
	for i = 1, 3 - #slots do qbar.roles[i]:Hide() end
	local AI = OpenGroup_AutoInvite
	if member then qbar.top:SetText(GREEN .. "Your group is listed|r" .. GREY .. "   by " .. member.leader .. "   " .. clock(time() - (member.at or time())) .. "|r") end
	qbar.leave:SetShown(not member)
	qbar.auto:SetShown(not summon and not bgq and not solo and not member)
	qbar.find:SetShown(not summon and not bgq and not solo and not member)
	qbar.lfg:ClearAllPoints()
	qbar.lfg:SetPoint("RIGHT", qbar.find:IsShown() and qbar.find or qbar.auto:IsShown() and qbar.auto or qbar.leave, "LEFT", -6, 0)
	qbar.lfg:SetShown(not member)
	qbar.auto:SetText(AI and AI.on and (GREEN .. "Auto: On|r") or "Auto Invite")
end

local qTick = 0
qbar:SetScript("OnUpdate", function(_, el)
	if AnimateTexCoords then pcall(AnimateTexCoords, qbar.eye, 512, 256, 64, 64, 29, el, 0.08) end
	if qbar.border.SetBackdropBorderColor then
		local w = (math.sin(GetTime() * 2.6) + 1) / 2
		qbar.border:SetBackdropBorderColor(0.72 + 0.28 * w, 0.56 + 0.26 * w, 0.32 + 0.12 * w, 1)
	end
	qTick = qTick + el
	if qTick > 1 then qTick = 0 paintQueueBar() end
end)
qbar:SetScript("OnClick", function() showPage((browse.matchCount or 0) > 0 and "browse" or "list") end)
qbar:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	GameTooltip:SetText("You're listed")
	GameTooltip:AddLine("OpenGroup players on every server can see you. Your listing is re-sent every 90 seconds while you're online.", 1, 1, 1, true)
	GameTooltip:AddLine((browse.matchCount or 0) > 0 and "Click to see who fits (top of Browse)." or "Click to change it.", 0, 1, 0)
	GameTooltip:Show()
end)
qbar:SetScript("OnLeave", GameTooltip_Hide)

local function updateQueueBar(animate)
	local on = L.mine ~= nil or L.groupListing ~= nil
	QBAR_H = on and 70 or 0
	placeContent()
	qbar:SetShown(on)
	if on then
		paintQueueBar()
		if animate then qbar.enter:Stop() qbar.enter:Play() end
		qbar.sheen:Play()
	else
		qbar.sheen:Stop()
	end
end

-- someone new fits what we're listed for: a line in chat and a chime (once per player per listing)
local told = {}
L.onNewListing = function(l)
	if not matchesMine(l) then return end
	local key = l.leader .. ":" .. (L.mine.seq or 0)
	if told[key] then return end
	told[key] = true
	local roles = {}
	for _, r in ipairs(ROLES) do if has(l.need, r) then roles[#roles + 1] = W.ROLE_NAME[r] end end
	local who = W.classColor(l.class) .. L.short(l.leader) .. "|r"
	if isBGQ(l.cat) then
		L.print(("%s %s %s, " .. L.CHAN .. " %d."):format(who, l.cat == P.BGQ_OFFER and "can queue you for" or "wants a queue for", bgNames(l), l.shard))
	elseif iAmLeader() then
		L.print(("%s (%s, %d) wants %s, " .. L.CHAN .. " %d.%s"):format(who, #roles > 0 and table.concat(roles, "/") or "any role", l.level,
			L.titleOf(l), l.shard, l.note ~= "" and (" \"" .. l.note .. "\"") or ""))
	else
		L.print(("%s's group wants %s for %s, " .. L.CHAN .. " %d."):format(who, #roles > 0 and table.concat(roles, "/") or "players", L.titleOf(l), l.shard))
	end
	W.sound("UI_GROUP_FINDER_RECEIVE_APPLICATION", 47615)
	if OpenGroup_Minimap and OpenGroup_Minimap.flash then OpenGroup_Minimap.flash() end
end

-- one line in party (or raid) chat when a group first lists, unless switched off or chat is locked
-- what we're listed for, the way people write it in chat: "UBRS / LBRS", "SM Library", up to three
local CHAT_ABBR = {
	["Ragefire Chasm"] = "RFC", ["Wailing Caverns"] = "WC", ["Shadowfang Keep"] = "SFK", ["Blackfathom Deeps"] = "BFD",
	["The Stockade"] = "Stockades", ["Razorfen Kraul"] = "RFK", ["Scarlet Monastery"] = "SM", ["Razorfen Downs"] = "RFD",
	["Zul'Farrak"] = "ZF", ["Sunken Temple"] = "ST", ["Blackrock Depths"] = "BRD", ["Lower Blackrock Spire"] = "LBRS",
	["Upper Blackrock Spire"] = "UBRS", ["Dire Maul"] = "DM", ["Scholomance"] = "Scholo", ["Stratholme"] = "Strat",
	["The Deadmines"] = "Deadmines",
}
local function chatName(id)
	local i = A.get(id)
	if not i then return nil end
	local name = i.name
	if (GetLocale and GetLocale() or "enUS"):find("^en") then
		for full, abbr in pairs(CHAT_ABBR) do
			if name == full then return abbr end
			-- wings: "Scarlet Monastery - Library" -> "SM Library"
			if name:sub(1, #full) == full then return abbr .. " " .. name:sub(#full + 1):gsub("^[%s%-:,]+", "") end
		end
	end
	return (i.short ~= "" and i.short) or name
end
local function chatTitle(m)
	local acts = m.acts or {}
	if (m.quest or 0) > 0 or #acts == 0 then return L.titleOf(m) end
	local names = {}
	for k, id in ipairs(acts) do
		if k > 3 then break end
		names[#names + 1] = chatName(id) or A.name(id) or "?"
	end
	return table.concat(names, " / ") .. (#acts > 3 and (" +" .. (#acts - 3) .. " more") or "")
end
local function chatRoles(need)
	local out = {}
	for _, r in ipairs({ { P.TANK, "Tank" }, { P.HEALER, "Healer" }, { P.DAMAGE, "DPS" } }) do
		if has(need or 0, r[1]) then out[#out + 1] = r[2] end
	end
	return #out > 0 and table.concat(out, ", ") or nil
end

local function announceToGroup()
	if GetNumGroupMembers() <= 1 or db().tellParty == false or not L.mine or isBGQ(L.mine.cat) then return end
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
		local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
		if ok and locked then return end
	end
	local m = L.mine
	local what = m.cat == P.SUMMON_CAT and ("summons to " .. (m.title or "?")) or chatTitle(m)
	local need = m.cat ~= P.SUMMON_CAT and chatRoles(m.need) or nil
	local text = ("[OpenGroup] Listed for %s%s. Anyone with OpenGroup on any server can find us."):format(
		what, need and (", need " .. need) or "")
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	local ok = send and pcall(send, text, (IsInRaid and IsInRaid()) and "RAID" or "PARTY")
	if not ok then L.print("couldn't post in party chat (the game blocked it); your listing is out anyway.") end
end
L.announceToGroup = announceToGroup

-- the line for LookingForGroup chat, in the shape people already read there
local function lfgLine(m)
	local tag = " (OpenGroup)"
	if m.cat == P.SUMMON_CAT then
		return ("WTS summons to %s, %s. Whisper me!%s"):format(m.title or "?", coins(m.price or 0), tag)
	elseif m.cat == P.BGQ_OFFER then
		return ("Queueing people for %s, whisper me for an invite!%s"):format(bgNames(m), tag)
	elseif m.cat == P.BGQ_WANT then
		return ("LF someone at a battlemaster to queue me for %s, whisper me!%s"):format(bgNames(m), tag)
	end
	local roles = chatRoles(m.need)
	if GetNumGroupMembers() <= 1 then
		return ("LFG %s%s, whisper me!%s"):format(chatTitle(m), roles and (" as " .. roles) or "", tag)
	end
	return ("LFM %s%s, whisper me!%s"):format(chatTitle(m), roles and (", need " .. roles) or "", tag)
end
-- from the Post in LFG click only
local function postToLFG()
	if not L.mine or not OpenGroup_Nearby then return end
	local ok, why = OpenGroup_Nearby.post(lfgLine(L.mine))
	if ok then L.print("posted in LookingForGroup.") elseif why then L.print(why) end
end
L.postLFGNow = postToLFG

local lastTitle
local function rememberListing(m)
	if not m or m.cat == P.SUMMON_CAT or isBGQ(m.cat) then return end
	local e = { title = m.title, note = m.note, need = m.need, cat = m.cat, acts = { unpack(m.acts or {}) }, quest = m.quest, spots = {} }
	for _, sp in ipairs(m.spots or {}) do e.spots[#e.spots + 1] = P.spot(sp.role, sp.class, sp.min, sp.max) end
	local key = L.titleOf(e)
	local keep = { e }
	for _, old in ipairs(type(db().recent) == "table" and db().recent or {}) do
		if #keep < 3 and L.titleOf(old) ~= key then keep[#keep + 1] = old end
	end
	db().recent = keep
end
L.onListed = function(first)
	if first then pcall(rememberListing, L.mine) end
	local bgq = L.mine and isBGQ(L.mine.cat)
	local peers, shards = L.count(L.peers), {}
	for _, p in pairs(L.peers) do if p.shard and p.shard > 0 then shards[p.shard] = true end end
	local summon = L.mine and L.mine.cat == P.SUMMON_CAT
	local title = first and (summon and "Summons listed!" or "Group listed!") or "Listing updated"
	local sub = peers == 0 and "Nobody to tell yet: find OpenGroup players in Network."
		or ("Sent to %d %s on %d %s."):format(math.min(25, peers), peers == 1 and "player" or "players", L.count(shards), L.count(shards) == 1 and (L.CHAN .. " number") or (L.CHAN .. " numbers"))
	local quest = L.mine and (L.mine.quest or 0) > 0
	if first then
		announceToGroup()
		OpenGroup_Alert.show({
			head = "OpenGroup",
			small = summon and "Summons listed" or bgq and (L.mine.cat == P.BGQ_OFFER and "Offering battleground queues" or "Asked for a battleground queue")
				or (GetNumGroupMembers() <= 1 and "Queued as " or "Looking for ") .. roleNames(L.mine and L.mine.need or 0),
			name = bgq and bgNames(L.mine) or L.titleOf(L.mine),
			roles = not summon and not bgq and L.mine and L.mine.need or nil,
			class = summon and "WARLOCK" or nil,
			icon = summon and SUMMON_ICON or bgq and BGQ_ICON or quest and "Interface\\Icons\\INV_Misc_Note_01" or L.ICON,
			onClick = function() win:Show() showPage("list") end,
		})
	else
		OpenGroup_Alert.show({
			head = "OpenGroup", small = "Listing updated", name = bgq and bgNames(L.mine) or L.titleOf(L.mine),
			roles = not summon and not bgq and L.mine and L.mine.need or nil, class = summon and "WARLOCK" or nil,
			icon = summon and SUMMON_ICON or bgq and BGQ_ICON or L.ICON,
			quiet = true, sound = "IG_MAINMENU_OPTION_CHECKBOX_ON", tint = { 0.5, 0.38, 0.12 }, hold = 2.5,
		})
	end
	if win.eyeStart then win.eyeStart() end
	listedLight:Show()
	W.fadeIn(listedLight, 0.4)
	updateQueueBar(first)
	lastTitle = bgq and bgNames(L.mine) or L.titleOf(L.mine)
	if OpenGroup_Minimap then OpenGroup_Minimap.update() end
end
-- our party leader listed or unlisted the group: the listed bar, light and minimap follow it
L.onGroupListing = function()
	local on = L.mine ~= nil or L.groupListing ~= nil
	listedLight:SetShown(on)
	updateQueueBar(L.groupListing ~= nil)
	if OpenGroup_Minimap then OpenGroup_Minimap.update() end
end
L.onDelisted = function()
	listedLight:Hide()
	if win.eyeStop then win.eyeStop() end
	updateQueueBar(false)
	if OpenGroup_Minimap then OpenGroup_Minimap.update() end
	W.sound("IG_CHARACTER_INFO_CLOSE")
	OpenGroup_Alert.show({
		head = "OpenGroup", small = "Delisted on every server", name = lastTitle or "You're off the list",
		icon = L.ICON, grey = true,
		quiet = true, sound = "IG_CHARACTER_INFO_CLOSE", tint = { 0.42, 0.12, 0.1 }, hold = 2.5,
	})
end

-- shift-clicked quests: Browse filters to the quest; any other tab lists it
local function listForQuest(q)
	local qc
	for _, c in ipairs(A.load()) do if catKind(c) == "quest" then qc = c end end
	draft.quest, draft.mode = q, "quests"
	showPage("list")
	openCategory(qc and qc.id or nil)
	W.sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
end
Q.onPick = function(q)
	if (db().tab or "browse") == "browse" then
		browse.setQuest(q)
		W.sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
		return
	end
	listForQuest(q)
end
qcard.list:SetScript("OnClick", function() if questFilter then listForQuest(questFilter) end end)
qcard.close:SetScript("OnClick", function() questFilter = nil L.onChange() end)

-- --------------------------------------------------------------------------------------------
-- tabs, refresh, slash

-- --------------------------------------------------------------------------------------------
-- WHISPERS: conversations since login. People on the left (OpenGroup's first), the conversation on
-- the right with a reply box, and Invite / Ask to Join / Whisper buttons.

local whispers = page("whispers")
-- its own function: the file is at Lua's limit of 200 locals
;(function()
	local W_ = whispers
	local sel                         -- the name being read
	local title = W_.header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 4, -10)
	title:SetText("Whispers")
	local sub = W_.header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	sub:SetWidth(330)
	sub:SetJustifyH("LEFT")
	sub:SetText("Everyone you've whispered with since you logged in. People you know through OpenGroup come first.")
	local ogOnly = CreateFrame("CheckButton", nil, W_.header, "UICheckButtonTemplate")
	ogOnly:SetSize(22, 22)
	ogOnly:SetPoint("BOTTOMRIGHT", -112, 6)
	local ogLabel = W_.header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	ogLabel:SetPoint("LEFT", ogOnly, "RIGHT", 2, 1)
	ogLabel:SetText("OpenGroup only")
	ogOnly:SetScript("OnClick", function(self) db().whispersOG = self:GetChecked() and true or false W_.refresh() end)

	-- left: the people
	local listBox = CreateFrame("Frame", nil, W_.content, "WowScrollBoxList")
	listBox:SetPoint("TOPLEFT", 6, -6)
	listBox:SetPoint("BOTTOMLEFT", 6, 6)
	listBox:SetWidth(178)
	local listBar = CreateFrame("EventFrame", nil, W_.content, "MinimalScrollBar")
	listBar:SetPoint("TOPLEFT", listBox, "TOPRIGHT", 4, 0)
	listBar:SetPoint("BOTTOMLEFT", listBox, "BOTTOMRIGHT", 4, 0)
	local divider = W_.content:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(0.55, 0.45, 0.3, 0.5)
	divider:SetWidth(1)
	divider:SetPoint("TOPLEFT", listBox, "TOPRIGHT", 16, 0)
	divider:SetPoint("BOTTOMLEFT", listBox, "BOTTOMRIGHT", 16, 0)

	-- right: who, the buttons, the conversation and the reply box
	local right = CreateFrame("Frame", nil, W_.content)
	right:SetPoint("TOPLEFT", divider, "TOPRIGHT", 8, 0)
	right:SetPoint("BOTTOMRIGHT", -8, 6)
	local who = right:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	who:SetPoint("TOPLEFT", 0, -2)
	who:SetJustifyH("LEFT")
	local whoClass = right:CreateTexture(nil, "ARTWORK")
	whoClass:SetSize(18, 18)
	whoClass:SetPoint("LEFT", who, "RIGHT", 6, 0)
	local whoLine = right:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	whoLine:SetPoint("TOPLEFT", who, "BOTTOMLEFT", 0, -4)
	whoLine:SetPoint("RIGHT", 0, 0)
	whoLine:SetJustifyH("LEFT")
	whoLine:SetWordWrap(false)
	local function button(text, w)
		local b = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
		b:SetSize(w, 22)
		b:SetText(text)
		return b
	end
	local inviteBtn = button("Invite", 70)
	inviteBtn:SetPoint("TOPRIGHT", 0, 0)
	local askBtn = button("Ask to Join", 96)
	askBtn:SetPoint("RIGHT", inviteBtn, "LEFT", -4, 0)
	local chatBtn = button("Whisper", 72)
	chatBtn:SetPoint("RIGHT", askBtn, "LEFT", -4, 0)
	who:SetPoint("RIGHT", chatBtn, "LEFT", -30, 0)

	local msgs = CreateFrame("ScrollingMessageFrame", nil, right)
	msgs:SetPoint("TOPLEFT", 0, -46)
	msgs:SetPoint("BOTTOMRIGHT", 0, 34)
	msgs:SetFontObject(ChatFontNormal or GameFontHighlight)
	msgs:SetJustifyH("LEFT")
	msgs:SetFading(false)
	msgs:SetMaxLines(200)
	msgs:SetInsertMode(SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM or "BOTTOM")
	msgs:EnableMouseWheel(true)
	msgs:SetScript("OnMouseWheel", function(self, d) if d > 0 then self:ScrollUp() else self:ScrollDown() end end)
	local msgsBg = right:CreateTexture(nil, "BACKGROUND")
	msgsBg:SetPoint("TOPLEFT", msgs, "TOPLEFT", -4, 4)
	msgsBg:SetPoint("BOTTOMRIGHT", msgs, "BOTTOMRIGHT", 4, -4)
	msgsBg:SetColorTexture(0, 0, 0, 0.25)

	local reply = CreateFrame("EditBox", nil, right, "InputBoxTemplate")
	reply:SetPoint("BOTTOMLEFT", 6, 4)
	reply:SetPoint("BOTTOMRIGHT", 0, 4)
	reply:SetHeight(24)
	reply:SetAutoFocus(false)
	reply:SetMaxLetters(255)
	local replyHint = reply:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	replyHint:SetPoint("LEFT", 2, 0)
	replyHint:SetText("Type a reply and press Enter")
	reply:HookScript("OnTextChanged", function(self) replyHint:SetShown(self:GetText() == "") end)
	reply:SetScript("OnEscapePressed", reply.ClearFocus)
	-- Enter in the box is the player's own key press, so the whisper goes out as theirs
	reply:SetScript("OnEnterPressed", function(self)
		local text = self:GetText()
		if sel and text ~= "" then
			local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
			if send then send(text, "WHISPER", nil, sel) end
			self:SetText("")
		end
	end)

	local empty = right:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	empty:SetPoint("CENTER", msgs, "CENTER")
	empty:SetWidth(260)
	empty:SetSpacing(4)

	local count = W_.footer:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	count:SetPoint("CENTER")

	local function listingOf(name) return (L.listings and L.listings[name]) or (L.nearby and L.nearby[name]) end
	local function hhmm(t) return date and date("%H:%M", t) or "" end

	-- one person per row: class colour, the listing line or the last message, unread count
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(38)
	view:SetElementInitializer("Button", function(row, c)
		if not row.built then
			row.bg = row:CreateTexture(nil, "BACKGROUND")
			row.bg:SetPoint("TOPLEFT", 1, -1) row.bg:SetPoint("BOTTOMRIGHT", -1, 1)
			row.bg:SetColorTexture(0.11, 0.08, 0.05, 0.9)
			row.sel = row:CreateTexture(nil, "BORDER")
			row.sel:SetAllPoints(row.bg)
			row.sel:SetColorTexture(1, 0.82, 0, 0.14)
			row.hl = row:CreateTexture(nil, "HIGHLIGHT")
			row.hl:SetAllPoints(row.bg)
			row.hl:SetColorTexture(1, 0.9, 0.6, 0.07)
			row.cls = row:CreateTexture(nil, "ARTWORK")
			row.cls:SetSize(14, 14)
			row.cls:SetPoint("TOPLEFT", 6, -5)
			row.og = row:CreateTexture(nil, "ARTWORK")
			row.og:SetSize(12, 12)
			row.og:SetTexture(L.ICON)
			row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			row.name:SetPoint("TOPLEFT", 24, -5)
			row.name:SetPoint("RIGHT", -50, 0)
			row.name:SetJustifyH("LEFT")
			row.name:SetWordWrap(false)
			row.line = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
			row.line:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
			row.line:SetPoint("RIGHT", -6, 0)
			row.line:SetJustifyH("LEFT")
			row.line:SetWordWrap(false)
			row.unread = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			row.unread:SetPoint("TOPRIGHT", -6, -6)
			row.og:SetPoint("RIGHT", row.unread, "LEFT", -4, 0)
			row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			row:SetScript("OnClick", function(self, button)
				if button == "RightButton" then browse.personMenu(self, self.c.name, listingOf(self.c.name)) return end
				W_.open(self.c.name) W.sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
			end)
			row.built = true
		end
		row.c = c
		local l = listingOf(c.name)
		local pi = L.personInfo(c.name)
		row.og:SetShown(c.linked == true)
		if pi.class and W.setClassIcon(row.cls, pi.class) then row.cls:Show() else row.cls:Hide() end
		row.name:SetText(W.classColor(pi.class) .. c.name .. "|r")
		local last = c.msgs[#c.msgs]
		local preview = l and (GOLD .. L.titleOf(l) .. "|r") or (last and (last.hidden and "(hidden by the game)" or ((last.out and "You: " or "") .. (last.text or "")))) or ""
		local who = L.personLine(c.name)
		row.line:SetText((who ~= "" and (GREY .. who .. "|r" .. (preview ~= "" and "  " or "")) or "") .. preview)
		row.unread:SetText((c.unread or 0) > 0 and ("|cffffd100" .. c.unread .. "|r") or (GREY .. hhmm(c.last) .. "|r"))
		row.sel:SetShown(sel == c.name)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(listBox, listBar, view)

	local function paintConversation()
		local c = sel and L.whispers[sel]
		msgs:Clear()
		local l = sel and listingOf(sel)
		inviteBtn:SetEnabled(sel ~= nil)
		chatBtn:SetEnabled(sel ~= nil)
		askBtn:SetEnabled(l ~= nil and (l.size or 1) > 1 and not l.src)
		reply:SetShown(sel ~= nil)
		if not sel then
			who:SetText("") whoLine:SetText("") whoClass:Hide()
			empty:SetText(next(L.whispers) and "Pick someone on the left." or "No whispers yet this session.\n\nWhispers you send and get show up here, and so do people you message from Browse.")
			empty:Show()
			return
		end
		empty:Hide()
		local pi = L.personInfo(sel)
		who:SetText(W.classColor(pi.class) .. sel .. "|r")
		if pi.class and W.setClassIcon(whoClass, pi.class) then whoClass:Show() else whoClass:Hide() end
		local bits = {}
		local pl = L.personLine(sel)
		if pl ~= "" then bits[#bits + 1] = pl end
		local peer = L.peers and L.peers[sel]
		local shard = l and not l.src and l.shard or (peer and (peer.shard or 0) > 0 and peer.shard) or nil
		if l and l.src == "finder" then bits[#bits + 1] = "Group Finder" elseif l and l.src == "chat" then bits[#bits + 1] = "LFG chat"
		elseif shard then bits[#bits + 1] = "shard " .. shard end
		if not l and L.whisperLinked(sel) then bits[#bits + 1] = "through OpenGroup" end
		whoLine:SetText((l and (GOLD .. L.titleOf(l) .. "|r  ") or "") .. GREY .. table.concat(bits, ", ") .. "|r")
		local function hex(kind, fallback)
			local t = ChatTypeInfo and ChatTypeInfo[kind]
			if t and t.r then return ("|cff%02x%02x%02x"):format(t.r * 255, t.g * 255, t.b * 255) end
			return fallback
		end
		local inC, outC = hex("WHISPER", "|cffff80ff"), hex("WHISPER_INFORM", "|cffff80ff")
		for _, m in ipairs(c and c.msgs or {}) do
			local whoText = m.out and (outC .. "You|r") or (W.classColor(pi.class) .. sel .. "|r")
			local body = m.hidden and (GREY .. "(the game hid this message)|r") or ((m.out and outC or inC) .. m.text .. "|r")
			msgs:AddMessage(("%s[%s]|r %s%s:|r %s"):format(GREY, hhmm(m.at), whoText, m.out and outC or inC, body))
		end
		msgs:ScrollToBottom()
	end

	function W_.refresh()
		ogOnly:SetChecked(db().whispersOG == true)
		local list = L.whisperList(db().whispersOG == true)
		listBox:SetDataProvider(CreateDataProvider(list), ScrollBoxConstants.RetainScrollPosition)
		paintConversation()
		local n = 0 for _ in pairs(L.whispers) do n = n + 1 end
		count:SetText(n == 0 and "" or (n .. (n == 1 and " conversation" or " conversations") ..
			((L.whisperHidden or 0) > 0 and (", " .. L.whisperHidden .. " hidden by the game") or "")))
	end
	function W_.open(name)
		if not name then return end
		name = L.short(name)
		sel = name
		local c = L.whispers[name]
		if c then c.unread = 0 end
		L.whisperViewing = name
		W_.refresh()
		if W_.badge then W_.badge() end
	end
	W_.onShow = function() if sel then L.whisperViewing = sel local c = L.whispers[sel] if c then c.unread = 0 end end W_.refresh() if W_.badge then W_.badge() end end
	W_.content:HookScript("OnHide", function() L.whisperViewing = nil end)

	inviteBtn:SetScript("OnClick", function()
		if not sel then return end
		local inv = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
		if inv then inv(sel) end
	end)
	chatBtn:SetScript("OnClick", function() if sel then openWhisper(sel) end end)
	askBtn:SetScript("OnClick", function()
		if not sel then return end
		selected = sel
		browse.primary()
	end)
	L.onWhisper = function()
		if W_.content:IsShown() then W_.refresh() end
		if W_.badge then W_.badge() end
	end
end)()

-- --------------------------------------------------------------------------------------------

browse.openTell = openWhisper

-- --------------------------------------------------------------------------------------------
-- FIND PLAYERS: a /who search built from an open spot (classes, levels, zone), the results in a
-- list, and one-click whispers: each press opens the chat box with /w and your message, and you
-- press Enter (one whisper per press, as the game allows). /who reaches every server, so this is
-- the way to people the Group Finder and Trade never show you.

local finder = page("find")
;(function()
	local F = finder
	F.classes = {}          -- class tokens to search, taking turns one per Search click
	F.turn = 0
	F.results = {}
	F.asked = {}            -- [name] = time we whispered them (this session)
	F.pending = nil         -- the name whose whisper box we last opened
	F.total = 0

	-- header: class, levels, zone, name; the /who text it will run; Search
	local classDD = W.dropdown(F.header, 150, "Any class", function(root)
		root:CreateRadio("Any class", function() return #F.classes == 0 end, function() F.classes = {} F.paint() end)
		local fac = UnitFactionGroup("player")
		for _, cls in ipairs(L.roleClasses(0, fac)) do
			root:CreateCheckbox(W.classColor(cls) .. W.className(cls) .. "|r", function() for _, c in ipairs(F.classes) do if c == cls then return true end end return false end,
				function()
					for i, c in ipairs(F.classes) do if c == cls then table.remove(F.classes, i) F.paint() return end end
					F.classes[#F.classes + 1] = cls
					F.paint()
				end)
		end
	end)
	classDD:SetPoint("TOPLEFT", 0, -4)
	local function box(w, hint)
		local e = CreateFrame("EditBox", nil, F.header, "InputBoxTemplate")
		e:SetSize(w, 20)
		e:SetAutoFocus(false)
		e:SetScript("OnEscapePressed", e.ClearFocus)
		e:SetScript("OnEnterPressed", e.ClearFocus)
		e.ph = e:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		e.ph:SetPoint("LEFT", 2, 0)
		e.ph:SetText(hint)
		e:HookScript("OnTextChanged", function(self) self.ph:SetShown(self:GetText() == "") F.paint() end)
		return e
	end
	local lvlLabel = F.header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	lvlLabel:SetPoint("LEFT", classDD, "RIGHT", 12, 0)
	lvlLabel:SetText("Level")
	F.min = box(30, "")
	F.min:SetPoint("LEFT", lvlLabel, "RIGHT", 8, 0)
	F.min:SetNumeric(true) F.min:SetMaxLetters(2)
	local dash = F.header:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	dash:SetPoint("LEFT", F.min, "RIGHT", 4, 0)
	dash:SetText("-")
	F.max = box(30, "")
	F.max:SetPoint("LEFT", dash, "RIGHT", 8, 0)
	F.max:SetNumeric(true) F.max:SetMaxLetters(2)
	F.zone = box(130, "any zone")
	F.zone:SetPoint("TOPLEFT", classDD, "BOTTOMLEFT", 6, -8)
	local here = CreateFrame("Button", nil, F.header, "UIPanelButtonTemplate")
	here:SetSize(70, 20)
	here:SetPoint("LEFT", F.zone, "RIGHT", 6, 0)
	here:SetText("My zone")
	here:SetScript("OnClick", function() F.zone:SetText(GetZoneText and GetZoneText() or "") end)
	F.name = box(110, "name (optional)")
	F.name:SetPoint("LEFT", here, "RIGHT", 10, 0)
	local search = CreateFrame("Button", nil, F.header, "UIPanelButtonTemplate")
	search:SetSize(96, 24)
	search:SetPoint("TOPRIGHT", -4, -4)
	search:SetText("Search")
	F.preview = F.header:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	F.preview:SetPoint("TOPLEFT", F.zone, "BOTTOMLEFT", -6, -8)
	F.preview:SetPoint("RIGHT", F.header, "RIGHT", -8, 0)
	F.preview:SetJustifyH("LEFT")
	F.preview:SetWordWrap(false)

	-- the query for the next Search click: one class at a time when several are ticked
	function F.query()
		local cls = #F.classes > 0 and F.classes[(F.turn % #F.classes) + 1] or nil
		return L.whoQuery({ class = cls and W.className(cls) or nil, min = F.min:GetText(), max = F.max:GetText(), zone = F.zone:GetText(), name = F.name:GetText() })
	end

	-- results
	local cols = F.content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	cols:SetPoint("TOPLEFT", 16, -8)
	cols:SetText("Name                                   Lvl    Class              Zone                       Guild")
	cols:Hide()
	F.notice = F.content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	F.notice:SetPoint("TOPLEFT", 14, -8)
	F.notice:SetPoint("RIGHT", F.content, "RIGHT", -200, 0)
	F.notice:SetJustifyH("LEFT")
	local narrowZone = CreateFrame("Button", nil, F.content, "UIPanelButtonTemplate")
	narrowZone:SetSize(90, 20)
	narrowZone:SetPoint("TOPRIGHT", -112, -4)
	narrowZone:SetText("My zone")
	narrowZone:SetScript("OnClick", function() F.zone:SetText(GetZoneText and GetZoneText() or "") end)
	local narrowLvl = CreateFrame("Button", nil, F.content, "UIPanelButtonTemplate")
	narrowLvl:SetSize(96, 20)
	narrowLvl:SetPoint("TOPRIGHT", -12, -4)
	narrowLvl:SetText("Split levels")
	narrowLvl:SetScript("OnClick", function()
		local lo, hi = P.int(F.min:GetText(), 1, 200), P.int(F.max:GetText(), 1, 200)
		if lo and hi and hi > lo then F.max:SetText(tostring(math.floor((lo + hi) / 2))) end
	end)
	local list = CreateFrame("Frame", nil, F.content, "WowScrollBoxList")
	list:SetPoint("TOPLEFT", 6, -30)
	list:SetPoint("BOTTOMRIGHT", -24, 6)
	local bar = CreateFrame("EventFrame", nil, F.content, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
	bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 6, 0)
	F.empty = F.content:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	F.empty:SetPoint("CENTER", 0, 20)
	F.empty:SetWidth(360)
	F.empty:SetSpacing(4)
	F.empty:SetText("Pick a class and levels, then click Search. /who looks across every server, so this finds people the Group Finder and chat channels don't show you.")

	-- footer: the message and Whisper next
	F.msg = CreateFrame("EditBox", nil, F.footer, "InputBoxTemplate")
	F.msg:SetPoint("LEFT", 8, 0)
	F.msg:SetPoint("RIGHT", F.footer, "RIGHT", -150, 0)
	F.msg:SetHeight(22)
	F.msg:SetAutoFocus(false)
	F.msg:SetMaxLetters(200)
	F.msg:SetScript("OnEscapePressed", F.msg.ClearFocus)
	F.msg:SetScript("OnEnterPressed", F.msg.ClearFocus)
	F.msg:HookScript("OnTextChanged", function(self, user) if user then db().findMsg = self:GetText() end end)
	local nextBtn = CreateFrame("Button", nil, F.footer, "UIPanelButtonTemplate")
	nextBtn:SetSize(130, 24)
	nextBtn:SetPoint("RIGHT", 0, 0)
	nextBtn:SetText("Whisper next")

	-- who's worth whispering: not you, not ignored, not asked yet, not an OpenGroup player
	-- (they already get your listing)
	function F.skip(info)
		local name = L.short(info.fullName)
		return L.isMe(name) or L.ignored(name) or F.asked[name] ~= nil or (L.peers[name] ~= nil)
	end
	function F.nextTarget()
		for _, info in ipairs(F.results) do if not F.skip(info) then return info end end
		return nil
	end
	-- open the chat box on them with the message; the player presses Enter
	function F.whisper(info)
		local name = L.short(info.fullName)
		F.pending = name
		if browse.openTell then browse.openTell(name, F.msg:GetText()) end
		F.paint()
	end
	L.onWhisperSent = function(name)
		if F.pending and L.short(name) == F.pending then F.pending = nil end
		for _, info in ipairs(F.results) do
			if L.short(info.fullName) == L.short(name) then F.asked[L.short(name)] = time() end
		end
		if F.content:IsShown() then F.paint() end
	end

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(22)
	view:SetElementInitializer("Button", function(row, info)
		if not row.built then
			row.hl = row:CreateTexture(nil, "HIGHLIGHT")
			row.hl:SetAllPoints()
			row.hl:SetColorTexture(1, 0.9, 0.6, 0.08)
			local function fs(x, w, font)
				local f = row:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
				f:SetPoint("LEFT", x, 0)
				f:SetWidth(w)
				f:SetJustifyH("LEFT")
				f:SetWordWrap(false)
				return f
			end
			row.name = fs(8, 150, "GameFontNormal")
			row.lvl = fs(162, 26)
			row.class = fs(192, 66)
			row.zone = fs(262, 110)
			row.guild = fs(376, 90)
			row.badge = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			row.badge:SetPoint("RIGHT", -72, 0)
			row.btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
			row.btn:SetSize(64, 18)
			row.btn:SetPoint("RIGHT", -4, 0)
			row.btn:SetText("Whisper")
			row.btn:SetScript("OnClick", function(self) F.whisper(self:GetParent().info) end)
			row:RegisterForClicks("RightButtonUp")
			row:SetScript("OnClick", function(self) if browse.personMenu then browse.personMenu(self, L.short(self.info.fullName), nil) end end)
			row.built = true
		end
		row.info = info
		local name = L.short(info.fullName)
		row.name:SetText(W.classColor(info.filename) .. name .. "|r")
		row.lvl:SetText(tostring(info.level or ""))
		row.class:SetText(info.classStr or "")
		row.zone:SetText(info.area or "")
		row.guild:SetText(info.fullGuildName and info.fullGuildName ~= "" and ("<" .. info.fullGuildName .. ">") or "")
		local badge = ""
		if L.peers[name] then badge = GREEN .. "OpenGroup|r"
		elseif F.asked[name] then badge = GREY .. "asked " .. date("%H:%M", F.asked[name]) .. "|r"
		elseif F.pending == name then badge = GOLD .. "press Enter|r" end
		row.badge:SetText(badge)
		row:SetAlpha(F.skip(info) and 0.55 or 1)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(list, bar, view)

	function F.paint()
		classDD:SetLabel(#F.classes == 0 and "Any class" or #F.classes == 1 and W.className(F.classes[1]) or (#F.classes .. " classes"))
		local q = F.query()
		F.preview:SetText("/who " .. (q ~= "" and q or "(everyone)") .. (#F.classes > 1 and (GREY .. "   (one class per Search)|r") or ""))
		local shown = {}
		for _, info in ipairs(F.results) do if not L.ignored(L.short(info.fullName)) then shown[#shown + 1] = info end end
		list:SetDataProvider(CreateDataProvider(shown), ScrollBoxConstants.RetainScrollPosition)
		local full = F.total >= 50
		F.notice:SetText(F.searching and (GREY .. "Searching...|r")
			or full and (GOLD .. "50 shown (the most /who gives). Narrow the search:|r")
			or (#shown > 0 and (GREY .. #shown .. " found|r") or ""))
		narrowZone:SetShown(full and not F.searching) narrowLvl:SetShown(full and not F.searching)
		F.empty:SetShown(#shown == 0 and not F.searching)
		local nxt = F.nextTarget()
		nextBtn:SetEnabled(nxt ~= nil)
		nextBtn:SetText(nxt and "Whisper next" or "Nobody left")
	end

	function F.searchClick()
		if InCombatLockdown and InCombatLockdown() then UIErrorsFrame:AddMessage("Not in combat.", 1, .1, .1) return end
		local q = F.query()
		F.searching = true
		-- one click-only call: this click's /who (no Group Finder search alongside)
		local ok = L.scan.find(q, function(list2, n)
			F.searching = false
			F.results = list2 or {}
			F.total = n or 0
			-- quietly ask who runs OpenGroup (within the usual hello limits)
			for _, info in ipairs(F.results) do L.probe(L.short(info.fullName), "find") end
			F.paint()
		end)
		if not ok then F.searching = false UIErrorsFrame:AddMessage("A search is already running.", 1, .82, 0) end
		if #F.classes > 1 then F.turn = F.turn + 1 end
		F.paint()
	end
	search:SetScript("OnClick", F.searchClick)
	nextBtn:SetScript("OnClick", function() local info = F.nextTarget() if info then F.whisper(info) end end)

	-- open on a spot: its classes (or the classes that can fill its role), its levels (or the
	-- activity's range, else yours give or take 3), and a message from your listing
	function F.open(spot)
		local lvl = UnitLevel("player") or 1
		local fac = UnitFactionGroup("player")
		if spot then
			F.classes = spot.class and { spot.class } or ((spot.role or 0) ~= 0 and L.roleClasses(spot.role, fac) or {})
		end
		local lo, hi = spot and spot.min, spot and spot.max
		if not (lo or hi) then
			local acts = (L.mine and L.mine.acts) or (type(db().draft) == "table" and db().draft.acts) or {}
			local i = acts[1] and A.get(acts[1])
			if i and (i.min or 0) > 0 then lo, hi = i.min, i.max end
		end
		lo, hi = lo or math.max(1, lvl - 3), hi or math.min(60, lvl + 3)
		F.min:SetText(tostring(lo)) F.max:SetText(tostring(hi))
		local what = L.mine and L.titleOf(L.mine) or nil
		local who = spot and (spot.class and W.className(spot.class) or ((spot.role or 0) ~= 0 and W.ROLE_NAME[spot.role]:lower())) or nil
		local msg = db().findMsg
		if not msg or msg == "" or spot then
			msg = ("Hi, we're looking for a %s%s. Want to join?"):format(who or "player", what and (" for " .. what) or "")
		end
		F.msg:SetText(msg)
		if not win:IsShown() then win:Show() end
		showPage("find")
		F.paint()
	end
	F.onShow = function()
		if F.msg:GetText() == "" then F.msg:SetText(db().findMsg or "Hi, want to join our group?") end
		if F.min:GetText() == "" then
			local lvl = UnitLevel("player") or 1
			F.min:SetText(tostring(math.max(1, lvl - 3))) F.max:SetText(tostring(math.min(60, lvl + 3)))
		end
		F.paint()
	end
end)()

local sideTabs = {}
sideTabs[1] = sideTab("browse", "Interface\\Icons\\INV_Misc_GroupLooking", "Browse groups")
sideTabs[2] = sideTab("list", "Interface\\Icons\\INV_Misc_GroupNeedMore", "List a group", sideTabs[1])
sideTabs[3] = sideTab("network", "Interface\\Icons\\INV_Misc_Gem_Amethyst_02", "Servers and players", sideTabs[2])
sideTabs[4] = sideTab("whispers", "Interface\\Icons\\INV_Letter_15", "Whispers", sideTabs[3])
sideTabs[5] = sideTab("find", "Interface\\Icons\\INV_Misc_Spyglass_03", "Find players (/who)", sideTabs[4])
do
	-- unread whispers: a gold count on the tab
	local badge = sideTabs[4]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	badge:SetPoint("BOTTOMRIGHT", -4, 4)
	whispers.badge = function() local n = L.whisperUnread() badge:SetText(n > 0 and ("|cffffd100" .. n .. "|r") or "") end
	whispers.badge()
end
browse.openWhisper = function(name)
	if not name then return end
	L.whisperLinks[L.short(name)] = true
	if not win:IsShown() then win:Show() end
	showPage("whispers")
	whispers.open(name)
end

local function refresh()
	if not win:IsShown() then return end
	local cur = db().tab or "browse"
	if pages[cur] and pages[cur].refresh then pages[cur].refresh() end
	if cur ~= "browse" then browse.refresh() end
end
L.onChange = refresh
browse.content:HookScript("OnShow", browse.refresh)

win:SetScript("OnShow", function()
	restoreSize()
	local pos = db().pos
	if type(pos) == "table" and tonumber(pos[1]) and tonumber(pos[2]) and pos[1] == pos[1] and pos[2] == pos[2]
		and math.abs(pos[1]) < 4000 and math.abs(pos[2]) < 4000 then
		win:ClearAllPoints()
		win:SetPoint("CENTER", UIParent, "CENTER", pos[1], pos[2])
	end
	A.load()
	showPage(pages[db().tab or ""] and db().tab or "browse")
	refresh()
end)
C_Timer.NewTicker(2, refresh)

OpenGroup_UI = { list = list, browse = browse, personItems = function(n, l) return browse.personItems(n, l) end, win = win, lastTab = sideTabs[5], find = finder, whisper = function(name) browse.openWhisper(name) end, showPage = showPage, qbar = qbar, toggle = function(tab)
	if win:IsShown() and (not tab or db().tab == tab) then win:Hide() return end
	if tab then db().tab = tab end
	win:Show()
	if tab then showPage(tab) end
end }

SLASH_OPENGROUP1 = "/og"
SLASH_OPENGROUP2 = "/opengroup"
SlashCmdList.OPENGROUP = function(msg)
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "post" or cmd == "list" then
		L.post(rest, "", 0)
	elseif cmd == "delist" then
		L.delist()
	elseif cmd == "ping" and rest ~= "" then
		L.ping(rest)
	elseif cmd == "auto" then
		if OpenGroup_AutoInvite then OpenGroup_AutoInvite.toggle() end
	elseif cmd == "compact" then
		db().compact = not db().compact
		L.print(db().compact and "compact rows on." or "compact rows off.")
		L.onChange()
	elseif cmd == "minimap" then
		if OpenGroup_Minimap then OpenGroup_Minimap.toggle() end
	elseif cmd == "art" then
		-- what a game window is drawn with, saved for matching its look: the Group Finder by
		-- default, or a window by name (/og art ProfessionsFrame)
		local root, rname
		local names = rest ~= "" and { rest } or { "LFGParentFrame", "PVEFrame", "GroupFinderFrame" }
		for _, n in ipairs(names) do
			local f = _G[n]
			if type(f) == "table" and f.IsShown and f:IsShown() then root, rname = f, n break end
		end
		if not root then
			L.print(rest ~= "" and ("no open window called " .. rest .. ". Open it first, then type /og art " .. rest .. " again.")
				or "open the game's Group Finder window first (its List page, the one with the role buttons), then type /og art again.")
			return
		end
		local ok, res = pcall(W.dumpArt, root, rname)
		if not ok then L.print("couldn't read the window: " .. tostring(res)) return end
		if rest ~= "" then
			db().artDumps = type(db().artDumps) == "table" and db().artDumps or {}
			db().artDumps[rname] = res
		else
			db().art = res
		end
		local n = 0 for _, it in ipairs(res.items) do if it.kind == "tex" then n = n + 1 end end
		L.print(("saved %d textures from %s. Type /reload to write them to disk."):format(n, rname))
	elseif cmd == "shard" then
		for _, line in ipairs(L.shardReport()) do L.print(line) end
	elseif cmd == "status" then
		local s = L.stats
		L.print(("%s, %d players known, %d groups, sent %d, refused %d (%s), received %d, bad %d%s"):format(
			OpenGroup_Nearby and OpenGroup_Nearby.serverName() or (L.CHAN .. " " .. L.shard()), L.count(L.peers), L.count(L.listings), s.sent, s.refused, tostring(L.lastRefusal or "-"),
			s.got, s.bad, L.lastError and (", last error: " .. tostring(L.lastError)) or ""))
		local found = {}
		for _, n in ipairs({ "LFGParentFrame", "PVEFrame", "GroupFinderFrame", "LFGListingFrame" }) do if _G[n] then found[#found + 1] = n end end
		L.print("Group Finder tab on: " .. tostring(OpenGroup_GroupFinderTab and OpenGroup_GroupFinderTab.attach() and "yes" or "not yet") ..
			" (frames seen: " .. (#found > 0 and table.concat(found, ", ") or "none") .. ")")
		local Nb = OpenGroup_Nearby
		if Nb then
			L.print(("your server: %d from the Group Finder, %d from chat (%d chat posts read, %d searches, %d posted to LookingForGroup, channel %s)"):format(
				Nb.count("finder"), Nb.count("chat"), Nb.stats.chat, Nb.stats.searches, Nb.stats.posted, tostring(Nb.lfgChannel() or "not joined")))
			if Nb.blocked then L.print(("blocked by the game this session: %s (%d times)"):format(Nb.blocked, Nb.blockedCount or 1) .. (Nb.noSearch and " (Group Finder searches paused)" or "")) end
			local by = {}
			for shard, n in pairs(Nb.stats.remoteBy or {}) do by[#by + 1] = ("shard %d: %d"):format(shard, n) end
			table.sort(by)
			local tot, seen = Nb.stats.overlapTotal or 0, Nb.stats.overlapSeen or 0
			local ov = Nb.overlapText and Nb.overlapText()
			if ov then L.print("Group Finder matches yours: " .. ov) end
			L.print(("other servers' Group Finder: %d groups from here to share, %d sent so far; received %s%s"):format(
				Nb.stats.harvested or 0, Nb.stats.reported or 0, #by > 0 and table.concat(by, ", ") or "none yet",
				tot > 0 and ("; %d%% of received were already in your own results (%d of %d)"):format(math.floor(100 * seen / tot + 0.5), seen, tot) or ""))
			local cb2 = {}
			for shard, n in pairs(Nb.stats.chatBy or {}) do cb2[#cb2 + 1] = ("shard %d: %d"):format(shard, n) end
			table.sort(cb2)
			L.print(("other servers' LFG chat: sharing %s, %d posts sent so far; received %s"):format(
				Nb.shareChat() and "on" or "off", Nb.stats.chatShared or 0, #cb2 > 0 and table.concat(cb2, ", ") or "none yet"))
			if Nb.blockedFrom then
				L.print(("the search was %.2fs before the block, called from:"):format(Nb.blockedAfter or -1))
				for line in tostring(Nb.blockedFrom):gmatch("[^\n]+") do L.print("  " .. (line:gsub("Interface[/\\]AddOns[/\\]", ""))) end
			end
		end
		if IsInGroup and IsInGroup() then
			local gs = L.groupStats or {}
			L.print(("party: leader %s%s; party messages sent %d%s, received %d, ignored %d%s; %s"):format(
				tostring(L.groupLeader and L.groupLeader() or "?"), (UnitIsGroupLeader and UnitIsGroupLeader("player")) and " (you)" or "",
				gs.sent or 0, gs.lastSent and (" (last " .. gs.lastSent .. ")") or "", gs.got or 0, gs.ignored or 0,
				gs.lastIgnored and (" (last " .. gs.lastIgnored .. ")") or "",
				L.mine and ("you're listed for " .. L.titleOf(L.mine)) or L.groupListing and ("your group is listed by " .. L.groupListing.leader) or "not listed"))
		end
		local art = {}
		for _, c in ipairs(A.load()) do art[#art + 1] = c.name .. "=" .. tostring((W.bannerAtlas(c.name))) end
		L.print("activities: " .. (A.fallback and "built-in list (the game's not ready yet)" or "the game's list") .. "; banner art: " .. table.concat(art, ", "))
		local tiles = {}
		for _, k in ipairs({ "dungeon", "quest", "battle", "custom" }) do
			local f = W.tileArt(k)
			tiles[#tiles + 1] = k .. "=" .. (f and f:match("([^\\]+)$") or "banner")
		end
		L.print("tile pictures: " .. table.concat(tiles, ", "))
	else
		win:SetShown(not win:IsShown())
		if win:IsShown() then L.scan.auto(false) end
	end
end
