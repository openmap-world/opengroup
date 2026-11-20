-- Auto invite: while your group is listed, OpenGroup invites people who fit one of its open spots
-- (set in Looking for on the List tab: each spot's role, class and level), until the group is full.
--
-- Who it considers: OpenGroup players queued (listed solo) for the same thing, players queued in
-- the game's Group Finder for it on your shard, people who pressed Ask to Join on your listing,
-- and (off by default) people posting LFG in chat. A person takes the most specific spot they fit
-- (a spot that names a class before an "any class" one). One invite every 2 seconds. With "invite
-- extras" (on by default) up to two invites go out per open spot, and whoever accepts first gets
-- in; the game turns away anyone accepting once the party is full. An invite nobody answers in 60
-- seconds frees its spot again. It only runs for a group (2 or more), never for a solo listing.
local L = OpenGroup
local P = OpenGroup_Proto
local W = OpenGroup_Widgets
local AI = {}
OpenGroup_AutoInvite = AI

local ROLE_NAME = { [P.TANK] = "Tank", [P.HEALER] = "Healer", [P.DAMAGE] = "Damage" }
local PARTY = 5
local GAP, PENDING_FOR, DECLINED_FOR, ASK_KEEP = 2, 60, 1800, 600

AI.on = false          -- never saved: auto invite starts off every session
AI.pending = {}        -- [name] = { role, spot, class, level, at }
AI.joined = {}         -- [name] = role
AI.declined = {}       -- [name] = time
AI.asks = {}           -- [name] = { class, level, need, at }
AI.log = {}

local function now() return time() end

function AI.cfg()
	OpenGroupDB = OpenGroupDB or {}
	local c = type(OpenGroupDB.auto) == "table" and OpenGroupDB.auto or {}
	OpenGroupDB.auto = c
	-- the role counts, classes and level range of the 0.6 test builds now live in the spots
	c.roles, c.minL, c.maxL = nil, nil, nil
	c.src = type(c.src) == "table" and c.src or {}
	for k, v in pairs({ og = true, finder = true, ask = true, chat = false }) do if c.src[k] == nil then c.src[k] = v end end
	if c.extra == nil then c.extra = true end
	return c
end

local function note(text)
	table.insert(AI.log, 1, text)
	while #AI.log > 4 do table.remove(AI.log) end
	L.print(text)
	if AI.paint then AI.paint() end
end

local function members() local n = GetNumGroupMembers() return n > 0 and n or 1 end
AI.members = members
local function inGroup(name)
	local short = L.short(name)
	local ok, a = pcall(UnitInParty, short)
	local ok2, b = pcall(UnitInRaid, short)
	return (ok and a) or (ok2 and b ~= nil and b ~= false) or false
end

-- the listing's open spots (a listing from before spots: built from its roles)
function AI.spots()
	local m = L.mine
	if not m then return {} end
	if type(m.spots) ~= "table" or #m.spots == 0 then m.spots = P.spotsFromNeed(m.need, math.max(1, PARTY - members())) end
	return m.spots
end

-- spots with as many invites out as they may have (one each, two with extras)
local function busy()
	local per, skip = {}, {}
	for _, p in pairs(AI.pending) do if p.spot then per[p.spot] = (per[p.spot] or 0) + 1 end end
	local limit = AI.cfg().extra and 2 or 1
	for i, sp in ipairs(AI.spots()) do if (per[sp] or 0) >= limit then skip[i] = true end end
	return skip
end

local function sameThing(m, l)
	if (m.quest or 0) > 0 then return l.quest == m.quest end
	for _, a in ipairs(m.acts or {}) do for _, b in ipairs(l.acts or {}) do if a == b then return true end end end
	if #(m.acts or {}) == 0 and (m.title or "") ~= "" then return (l.title or ""):lower() == m.title:lower() end
	return false
end

-- who could join, best first: people who asked, OpenGroup players, the Group Finder, then chat
function AI.candidates()
	local c, m, out = AI.cfg(), L.mine, {}
	if not m then return out end
	local function add(name, class, level, need, src)
		if type(name) == "string" and name ~= "" and not L.isMe(name) then
			out[#out + 1] = { name = name, class = class, level = level or 0, need = need or 0, src = src }
		end
	end
	if c.src.ask then
		for name, a in pairs(AI.asks) do if now() - a.at < ASK_KEEP then add(name, a.class, a.level, a.need, "ask") end end
	end
	local function solo(l) return (l.size or 1) <= 1 and not P.isBGQ(l.cat) and l.cat ~= P.SUMMON_CAT and sameThing(m, l) end
	if c.src.og then for _, l in pairs(L.listings) do if solo(l) then add(l.leader, l.class, l.level, l.need, "og") end end end
	for _, l in pairs(L.nearby or {}) do
		if solo(l) and ((l.src == "finder" and c.src.finder) or (l.src == "chat" and c.src.chat)) then add(l.leader, l.class, l.level, l.need, l.src) end
	end
	local rank = { ask = 1, og = 2, finder = 3, chat = 4 }
	local lvl = UnitLevel("player") or 0
	table.sort(out, function(a, b)
		if rank[a.src] ~= rank[b.src] then return rank[a.src] < rank[b.src] end
		return math.abs((a.level > 0 and a.level or lvl) - lvl) < math.abs((b.level > 0 and b.level or lvl) - lvl)
	end)
	return out
end

-- the role this person would come as, and the spot they'd take; nil if no open spot fits
function AI.pick(cand)
	local list = AI.spots()
	local i, role = P.bestSpot(list, cand.class, cand.level, cand.need, busy())
	if i then return role, list[i] end
	return nil
end

local function eligible(cand)
	local d = AI.declined[cand.name]
	return not AI.pending[cand.name] and not AI.joined[cand.name] and not (d and now() - d < DECLINED_FOR) and not inGroup(cand.name)
end

function AI.full()
	return members() >= PARTY or #AI.spots() == 0
end

function AI.finish()
	AI.on = false
	AI.pending = {}
	note("auto invite: your group is full.")
	if OpenGroup_Alert then
		OpenGroup_Alert.show({ head = "OpenGroup", small = "Auto invite", name = "Group filled", icon = L.ICON })
	end
	if L.mine then L.delist() end
	if L.onChange then L.onChange() end
end

-- someone joined: the spot they came for is filled (else the best one they fit, else the last)
local function fill(list, p)
	for i, sp in ipairs(list) do if sp == p.spot then table.remove(list, i) return end end
	local i = P.bestSpot(list, p.class, p.level, p.role)
	table.remove(list, i or #list)
end

-- invites that were answered, or weren't: who joined, who left, whose spot opens again
function AI.sweep()
	local t = now()
	local list = L.mine and AI.spots()
	local changed = false
	for name, p in pairs(AI.pending) do
		if inGroup(name) then
			AI.joined[name], AI.pending[name] = p.role, nil
			if list and #list > 0 then fill(list, p) changed = true end
			note(("auto invite: %s joined as %s."):format(L.short(name), ROLE_NAME[p.role] or "?"))
		elseif t - p.at > PENDING_FOR then
			AI.pending[name], AI.declined[name] = nil, t
			note(("auto invite: no answer from %s, moving on."):format(L.short(name)))
		end
	end
	for name in pairs(AI.joined) do if not inGroup(name) then AI.joined[name] = nil end end
	-- the group grew some other way: fewer spots left (the last ones go)
	if list then
		local open = math.max(0, PARTY - members())
		while #list > open do table.remove(list) changed = true end
		if changed and members() > 1 then L.setSpots(list) end
	end
end

function AI.invite(cand, role, spot)
	local inv = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
	local ok = inv and pcall(inv, cand.name)
	AI.lastInvite = GetTime()
	if not ok then AI.declined[cand.name] = now() return false end
	AI.pending[cand.name] = { role = role, spot = spot, class = cand.class, level = cand.level, at = now() }
	AI.asks[cand.name] = nil
	if cand.src == "og" or cand.src == "ask" then L.send(cand.name, P.invited(L.titleOf(L.mine))) end
	local cls = cand.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cand.class]) or cand.class:sub(1, 1) .. cand.class:sub(2):lower())
	note(("auto invite: invited %s%s as %s."):format(L.short(cand.name),
		cls and ((" (%s%s)"):format(cls, cand.level > 0 and (" " .. cand.level) or "")) or "", ROLE_NAME[role] or "?"))
	return true
end

function AI.tick()
	if not AI.on then return end
	local m = L.mine
	if not m or P.isBGQ(m.cat) or m.cat == P.SUMMON_CAT then return end
	-- a group only: a solo listing is a player looking for a group
	if members() <= 1 then return end
	if IsInGroup and IsInGroup() and UnitIsGroupLeader and not UnitIsGroupLeader("player") then return end
	AI.sweep()
	if not AI.on then return end
	if AI.full() then AI.finish() return end
	if GetTime() - (AI.lastInvite or -GAP) < GAP then return end
	local pending = 0
	for _ in pairs(AI.pending) do pending = pending + 1 end
	local open = #AI.spots()
	if pending >= (AI.cfg().extra and open * 2 or open) then return end
	for _, cand in ipairs(AI.candidates()) do
		if eligible(cand) then
			local r, spot = AI.pick(cand)
			if r and AI.invite(cand, r, spot) then return end
		end
	end
end

-- someone pressed Ask to Join on our listing
function AI.onJoinRequest(sender, d)
	AI.asks[sender] = { class = d.class ~= "" and d.class or nil, level = d.level, need = d.need, at = now() }
	if AI.on then AI.tick() end
end
L.onJoinRequest = AI.onJoinRequest

function AI.start()
	AI.on = true
	AI.joined, AI.pending = {}, {}
	if not L.mine then note("auto invite on: it starts when you list your group.")
	elseif members() <= 1 then note("auto invite on: it starts once you're in a group.")
	else note("auto invite on.") end
	AI.tick()
	if L.onChange then L.onChange() end
end
function AI.stop()
	AI.on = false
	AI.pending = {}
	note("auto invite off.")
	if L.onChange then L.onChange() end
end
function AI.toggle()
	if AI.on then AI.stop() else AI.start() end
end

-- decline / already-grouped system lines free the slot at once
local function pattern(fmt)
	if type(fmt) ~= "string" then return nil end
	local escaped = fmt:gsub("([%(%)%.%-%+%*%?%[%]%^%$])", "%%%1")
	return "^" .. escaped:gsub("%%s", "(.+)") .. "$"
end
local f = CreateFrame("Frame")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("CHAT_MSG_SYSTEM")
f:SetScript("OnEvent", function(_, ev, msg)
	if ev == "GROUP_ROSTER_UPDATE" then pcall(AI.sweep) if AI.paint then AI.paint() end return end
	if type(msg) ~= "string" or not next(AI.pending) then return end
	for _, fmt in ipairs({ ERR_DECLINE_GROUP_S, ERR_ALREADY_IN_GROUP_S }) do
		local pat = pattern(fmt)
		local who = pat and msg:match(pat)
		if who then
			for name in pairs(AI.pending) do
				if L.short(name) == L.short(who) then
					AI.pending[name], AI.declined[name] = nil, now()
					note(("auto invite: %s said no."):format(L.short(name)))
				end
			end
		end
	end
end)
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(1, function() pcall(AI.tick) end) end

-- --------------------------------------------------------------------------------------------
-- options: a small popup under the gear beside the Auto invite box (who to invite from, extras)

local p = CreateFrame("Frame", "OpenGroupAutoInvite", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
p:SetSize(250, 146)
p:SetFrameStrata("DIALOG")
p:SetClampedToScreen(true)
p:EnableMouse(true)
p:Hide()
p.bg = p:CreateTexture(nil, "BACKGROUND")
p.bg:SetPoint("TOPLEFT", 4, -4) p.bg:SetPoint("BOTTOMRIGHT", -4, 4)
W.gradient(p.bg, 0.16, 0.12, 0.07, 0.98, 0.07, 0.055, 0.04, 0.98)
if p.SetBackdrop then
	p:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
	p:SetBackdropBorderColor(0.8, 0.65, 0.4, 1)
end
local title = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
title:SetPoint("TOPLEFT", 12, -10)
title:SetText("Invite from")

local srcChecks = {}
for i, s in ipairs({ { "og", "OpenGroup players queued for it" }, { "finder", "The game's Group Finder (your shard)" },
	{ "ask", "People who ask to join" }, { "chat", "LFG posts in chat (no level shown)" } }) do
	local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
	cb:SetSize(20, 20)
	cb:SetPoint("TOPLEFT", 10, -26 - (i - 1) * 20)
	local t = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	t:SetPoint("LEFT", cb, "RIGHT", 2, 1) t:SetText(s[2])
	cb:SetScript("OnClick", function(self) AI.cfg().src[s[1]] = self:GetChecked() and true or false end)
	srcChecks[s[1]] = cb
end

local extraCheck = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
extraCheck:SetSize(20, 20)
extraCheck:SetPoint("TOPLEFT", 10, -112)
local extraLabel = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
extraLabel:SetPoint("LEFT", extraCheck, "RIGHT", 2, 1)
extraLabel:SetText("Invite extras: first to accept gets in")
extraCheck:SetScript("OnClick", function(self) AI.cfg().extra = self:GetChecked() and true or false end)
extraCheck:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText("Invite extras")
	GameTooltip:AddLine("Sends up to two invites per open spot, so the group fills faster. Whoever accepts first gets in, and the game turns away anyone accepting once you're full. If two people for the same spot accept at once, you can end up with one extra.", 1, 1, 1, true)
	GameTooltip:Show()
end)
extraCheck:SetScript("OnLeave", GameTooltip_Hide)

function AI.paint()
	if not p:IsShown() then return end
	local c = AI.cfg()
	for k, cb in pairs(srcChecks) do cb:SetChecked(c.src[k] == true) end
	extraCheck:SetChecked(c.extra == true)
end
p:SetScript("OnShow", function() AI.paint() end)

-- a click anywhere else closes it
pcall(p.RegisterEvent, p, "GLOBAL_MOUSE_DOWN")
p:SetScript("OnEvent", function(self)
	if self:IsShown() and not self:IsMouseOver() and not (self.anchor and self.anchor:IsMouseOver()) then self:Hide() end
end)

-- open (or close) the options under a button; it grows to the left, away from the side tabs
function AI.options(anchor)
	if p:IsShown() and p.anchor == anchor then p:Hide() return end
	p.anchor = anchor
	p:ClearAllPoints()
	if anchor then p:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2) else p:SetPoint("CENTER") end
	p:Show()
end
AI.frame = p
