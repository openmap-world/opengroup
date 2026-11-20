-- Alerts in the style of the game's guild-achievement popup: banner, shield, glow and a shine that
-- sweeps across, then a slow fade. Built from the game's own art (atlases) with our own code; a
-- plain gold-bordered box stands in on a client without those atlases. Alerts queue.
local W = OpenGroup_Widgets
local Alert = {}
OpenGroup_Alert = Alert

local HOLD = 4.0

local function has(a) return W.hasAtlas(a) end
local ART_OK

local frame
local paintEmblem
local queue = {}

-- The listing sound. Try known sounds in order and stop at the first the game will actually
-- play (PlaySound returns willPlay; a missing kit just returns false, which used to end the search).
local function tryKit(id)
	if not id then return false end
	local ok, willPlay = pcall(PlaySound, id, "Master")
	return ok and willPlay ~= false
end
local function fanfare()
	local S = SOUNDKIT or {}
	-- the battleground "you're in the queue" sound first (PVPEnterQueue), then the achievement one
	for _, id in ipairs({ S.PVP_ENTER_QUEUE, 8458, 12891, S.LFG_REWARDS, 8960, S.READY_CHECK, S.IG_QUEST_LIST_COMPLETE }) do
		if tryKit(id) then return end
	end
	if PlaySoundFile then pcall(PlaySoundFile, 569143, "Master") end   -- AchievementSound1
end

local function anim(region, steps, onDone)
	local g = region:CreateAnimationGroup()
	for _, s in ipairs(steps) do
		local a = g:CreateAnimation(s[1])
		a:SetOrder(s.order or 1)
		a:SetDuration(s.dur or 0.2)
		if s.delay then a:SetStartDelay(s.delay) end
		if s[1] == "Alpha" then a:SetFromAlpha(s.from) a:SetToAlpha(s.to)
		elseif s[1] == "Translation" then a:SetOffset(s.x or 0, s.y or 0)
		elseif s[1] == "Scale" then
			if a.SetScaleFrom then a:SetScaleFrom(s.from, s.from) a:SetScaleTo(s.to, s.to) else a:SetScale(s.to, s.to) end
		end
		if s.smooth then a:SetSmoothing(s.smooth) end
	end
	if onDone then g:SetScript("OnFinished", onDone) end
	return g
end

local function build()
	ART_OK = has("ui-achievement-guild-background") and has("ui-achievement-guild-glow") and has("ui-achievement-guild-shine")
	local f = CreateFrame("Button", "OpenGroupAlertFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetPoint("CENTER", 0, 170)
	f:Hide()
	f:SetClipsChildren(not ART_OK)
	if ART_OK then
		f:SetSize(300, 101)
		local bg = f:CreateTexture(nil, "BACKGROUND")
		bg:SetAtlas("ui-achievement-guild-background", true)
		bg:SetPoint("CENTER")
		if has("ui-achievement-guild-flag-short") then
			local flag = f:CreateTexture(nil, "BACKGROUND", nil, 1)
			flag:SetAtlas("ui-achievement-guild-flag-short", true)
			flag:SetPoint("TOPRIGHT", -13, -32)
			flag:SetVertexColor(0.18, 0.42, 0.12)   -- green: "you're listed"
			f.flag = flag
		end
		if has("ui-achievement-guild-flag-short-outline") then
			local o = f:CreateTexture(nil, "BORDER")
			o:SetAtlas("ui-achievement-guild-flag-short-outline", true)
			o:SetPoint("TOPRIGHT", -13, -34)
		end
		local iconHolder = CreateFrame("Frame", nil, f)
		iconHolder:SetSize(78, 75)
		iconHolder:SetPoint("TOPLEFT", 0, -25)
		f.icon = iconHolder:CreateTexture(nil, "ARTWORK")
		f.icon:SetSize(52, 52)
		f.icon:SetPoint("CENTER", 0, 3)
		if has("ui-achievement-guild-iconframe") then
			local fr = iconHolder:CreateTexture(nil, "OVERLAY")
			fr:SetAtlas("ui-achievement-guild-iconframe", true)
			fr:SetPoint("CENTER")
		end
		-- right-hand emblem: the roles you're queued as (where the achievement shield would be)
		local emblem = CreateFrame("Frame", nil, f)
		emblem:SetSize(70, 70)
		emblem:SetPoint("TOPRIGHT", -10, -24)
		f.emblem = emblem
		f.roleIcons = {}
		for k = 1, 3 do
			local t = emblem:CreateTexture(nil, "ARTWORK", nil, k)
			t:Hide()
			f.roleIcons[k] = t
		end
		f.emblemGlow = emblem:CreateTexture(nil, "BACKGROUND")
		f.emblemGlow:SetTexture("Interface\\Cooldown\\star4")
		f.emblemGlow:SetBlendMode("ADD")
		f.emblemGlow:SetSize(96, 96)
		f.emblemGlow:SetPoint("CENTER")
		f.emblemGlow:SetVertexColor(0.5, 1, 0.4)
		f.emblemGlow:SetAlpha(0.35)
		f.emblemPop = anim(emblem, { { "Scale", from = 0.3, to = 1.15, dur = 0.18, delay = 0.15, order = 1 },
			{ "Scale", from = 1.15, to = 1, dur = 0.12, order = 2 } })
		f.head = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		f.head:SetPoint("TOPLEFT", 50, -13) f.head:SetPoint("TOPRIGHT", -50, -13)
		f.small = f:CreateFontString(nil, "OVERLAY", "GameFontBlackTiny")
		f.small:SetSize(200, 12)
		f.small:SetPoint("TOP", 0, -38)
		f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		f.name:SetSize(155, 36)
		f.name:SetPoint("TOP", 7, -50)
		f.name:SetMaxLines(2)
		f.glow = f:CreateTexture(nil, "OVERLAY")
		f.glow:SetAtlas("ui-achievement-guild-glow", true)
		f.glow:SetBlendMode("ADD")
		f.glow:SetPoint("CENTER")
		f.shine = f:CreateTexture(nil, "OVERLAY")
		f.shine:SetAtlas("ui-achievement-guild-shine", true)
		f.shine:SetBlendMode("ADD")
		f.shine:SetPoint("BOTTOMLEFT", 0, 16)
		f.glowAnim = anim(f.glow, { { "Alpha", from = 0, to = 1, dur = 0.2, order = 1 }, { "Alpha", from = 1, to = 0, dur = 0.5, order = 2 } }, function() f.glow:Hide() end)
		f.shineAnim = anim(f.shine, { { "Alpha", from = 0, to = 1, dur = 0.2, order = 1 },
			{ "Translation", x = 240, dur = 0.85, order = 2 }, { "Alpha", from = 1, to = 0, dur = 0.5, delay = 0.35, order = 2 } },
			function() f.shine:Hide() end)
		f.intro = anim(f, { { "Alpha", from = 0, to = 1, dur = 0.2 } })
	else
		f:SetSize(440, 112)
		if f.SetBackdrop then
			f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
				edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
			f:SetBackdropColor(0.05, 0.04, 0.03, 0.96)
		end
		local wash = f:CreateTexture(nil, "BORDER")
		wash:SetPoint("TOPLEFT", 6, -6) wash:SetPoint("BOTTOMRIGHT", -6, 6)
		wash:SetColorTexture(1, 0.78, 0.25, 0.10)
		f.icon = f:CreateTexture(nil, "ARTWORK")
		f.icon:SetSize(56, 56)
		f.icon:SetPoint("LEFT", 22, 0)
		f.head = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		f.head:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 14, 0)
		f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		f.name:SetPoint("TOPLEFT", f.head, "BOTTOMLEFT", 0, -6)
		f.name:SetWidth(300) f.name:SetJustifyH("LEFT")
		f.small = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		f.small:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -6)
		local emblem = CreateFrame("Frame", nil, f)
		emblem:SetSize(70, 70)
		emblem:SetPoint("RIGHT", -20, 0)
		f.emblem = emblem
		f.roleIcons = {}
		for k = 1, 3 do f.roleIcons[k] = emblem:CreateTexture(nil, "ARTWORK", nil, k) f.roleIcons[k]:Hide() end
		local sweep = f:CreateTexture(nil, "OVERLAY")
		sweep:SetTexture("Interface\\Cooldown\\star4")
		sweep:SetSize(110, 170)
		sweep:SetBlendMode("ADD")
		sweep:SetPoint("LEFT", -110, 0)
		f.shine = sweep
		f.shineAnim = anim(sweep, { { "Alpha", from = 0, to = 0.9, dur = 0.15, delay = 0.25 },
			{ "Translation", x = 560, dur = 0.9, delay = 0.25 }, { "Alpha", from = 0.9, to = 0, dur = 0.3, delay = 0.85 } },
			function() sweep:Hide() end)
		f.intro = anim(f, { { "Alpha", from = 0, to = 1, dur = 0.25 }, { "Scale", from = 0.6, to = 1, dur = 0.25 } })
	end
	f.outro = anim(f, { { "Alpha", from = 1, to = 0, dur = ART_OK and 1.5 or 0.6 } }, function()
		f:Hide()
		Alert.next()
	end)
	f:SetScript("OnEnter", function(self) self.hover = true end)
	f:SetScript("OnLeave", function(self) self.hover = false end)
	f:SetScript("OnUpdate", function(self, el)
		if self.outro:IsPlaying() or self.hover then return end
		self.left = (self.left or HOLD) - el
		if self.left <= 0 then self.outro:Play() end
	end)
	f:SetScript("OnClick", function(self)
		if self.item and self.item.onClick then self.item.onClick() end
		self.outro:Stop() self:Hide() Alert.next()
	end)
	return f
end

local ROLE_ATLAS = { [1] = "groupfinder-icon-role-large-tank", [2] = "groupfinder-icon-role-large-heal", [4] = "groupfinder-icon-role-large-dps" }
-- one role: big and centred; two: side by side; three: a little triangle
local ROLE_TC = { [1] = { 0, 19/64, 22/64, 41/64 }, [2] = { 20/64, 39/64, 1/64, 20/64 }, [4] = { 20/64, 39/64, 22/64, 41/64 } }
local LAYOUT = { { { 0, 0, 58 } }, { { -15, 0, 42 }, { 15, 0, 42 } }, { { 0, 13, 36 }, { -16, -13, 36 }, { 16, -13, 36 } } }
paintEmblem = function(f, item)
	for _, t in ipairs(f.roleIcons) do t:Hide() end
	local list = {}
	if item.class then
		list[1] = { atlas = W.classAtlas and W.classAtlas(item.class) }
	elseif item.roles then
		for _, r in ipairs({ 1, 2, 4 }) do if item.roles % (r * 2) >= r then list[#list + 1] = { atlas = ROLE_ATLAS[r], tc = ROLE_TC[r] } end end
	end
	local spots = LAYOUT[#list]
	for k, e in ipairs(list) do
		local t, sp = f.roleIcons[k], spots[k]
		if e.atlas and W.hasAtlas(e.atlas) then t:SetAtlas(e.atlas) t:SetTexCoord(0, 1, 0, 1)
		elseif e.tc then t:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES") t:SetTexCoord(unpack(e.tc))
		else t:SetTexture("Interface\\Icons\\Spell_Shadow_Twilight") t:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
		t:SetSize(sp[3], sp[3])
		t:ClearAllPoints()
		t:SetPoint("CENTER", sp[1], sp[2])
		t:Show()
	end
	f.emblem:SetShown(#list > 0)
	if f.emblemPop then f.emblemPop:Stop() f.emblemPop:Play() end
	if f.emblemGlow then f.emblemGlow:SetShown(#list > 0) end
end

function Alert.next()
	local item = table.remove(queue, 1)
	if not item then return end
	frame = frame or build()
	frame.item = item
	frame.head:SetText(item.head or "OpenGroup")
	frame.small:SetText(item.small or "")
	frame.name:SetText(item.name or "")
	paintEmblem(frame, item)
	if item.atlas then frame.icon:SetAtlas(item.atlas) frame.icon:SetTexCoord(0, 1, 0, 1)
	else frame.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_GroupNeedMore") frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
	if frame.icon.SetDesaturated then frame.icon:SetDesaturated(item.grey == true) end
	if frame.flag then local t = item.tint or { 0.18, 0.42, 0.12 } frame.flag:SetVertexColor(t[1], t[2], t[3]) end
	frame.left = item.hold or HOLD
	frame:SetAlpha(1)
	frame:Show()
	frame.outro:Stop()
	frame.intro:Stop() frame.intro:Play()
	if frame.glow then frame.glow:Show() frame.glowAnim:Stop() frame.glowAnim:Play() end
	frame.shine:Show() frame.shineAnim:Stop() frame.shineAnim:Play()
	-- the fanfare is for a new listing; updates and delisting get a quiet click
	if item.quiet then
		if SOUNDKIT and item.sound and SOUNDKIT[item.sound] then pcall(PlaySound, SOUNDKIT[item.sound]) end
	else fanfare() end
end

-- item = { head, small, name, roles (need bits) | class, icon | atlas, onClick,
--          quiet (no fanfare), sound (SOUNDKIT key when quiet), tint {r,g,b} for the flag, grey icon, hold seconds }
function Alert.show(item)
	if #queue >= 8 then return end
	queue[#queue + 1] = item
	if not (frame and frame:IsShown()) then Alert.next() end
end
