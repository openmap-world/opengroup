-- Groups from outside OpenGroup, on your own shard: the game's Group Finder and what people post
-- in the LookingForGroup, Trade and General channels. They fill Browse while few people run
-- OpenGroup yet, with a grey tag so it's always clear where a row came from. Nothing here is
-- passed on to other players. Everyone seen gets the usual hidden hello, so the OpenGroup users
-- among them join your network.
--
-- The game's Group Finder data can be "secret" while chat is locked down (in some instances and
-- encounters): every value is checked with canaccessvalue before it's compared, joined or used
-- as a key, and anything unreadable is skipped.
local L = OpenGroup
local A = OpenGroup_Activities
local P = OpenGroup_Proto
local N = {}
OpenGroup_Nearby = N
L.nearby = {}   -- [name] = a listing-shaped table, plus src = "finder" | "chat"

local FINDER_KEEP = 300   -- a Group Finder row lives this long after the last search that showed it
local CHAT_KEEP = 600     -- a chat post, this long after the person last posted
local SEARCH_GAP = 30     -- our own Group Finder searches, at most this often (a click forces 5)
local TANK, HEAL, DPS = 1, 2, 4

N.stats = { finder = 0, chat = 0, searches = 0, posted = 0 }

local canaccess = canaccessvalue or function() return true end
local function readable(v) return v ~= nil and canaccess(v) end
local function str(v) return readable(v) and type(v) == "string" and v or nil end
local function num(v) return readable(v) and tonumber(v) or nil end
local function enabled() return not (type(OpenGroupDB) == "table" and OpenGroupDB.nearby == false) end
local function clock() return time() end

-- many chat lines a second in a capital: redraw at most twice a second
local redrawPending
local function changed()
	if redrawPending then return end
	redrawPending = true
	local function go() redrawPending = false if L.onChange then L.onChange() end end
	if C_Timer and C_Timer.After then C_Timer.After(0.5, go) else go() end
end

local function catOf(acts)
	local i = acts[1] and A.info[acts[1]]
	return i and i.cat or 0
end

local function put(l)
	l.seq, l.hops, l.price, l.quest = 0, 0, 0, 0
	l.shard = L.shard()
	l.cat = l.cat or catOf(l.acts)
	l.title, l.note = l.title or "", l.note or ""
	l.level, l.size, l.need = l.level or 0, l.size or 1, l.need or 0
	L.nearby[l.leader] = l
end

function N.count(src)
	local n = 0
	for _, l in pairs(L.nearby) do if not src or l.src == src then n = n + 1 end end
	return n
end

-- --------------------------------------------------------------------------------------------
-- chat: "LFM BRD need heals", "LFG strat UD as tank"

-- what people type -> words in the activity's name, in English (other languages fall back to
-- matching the activity's full or short name)
local SHORT = {
	rfc = "ragefire", wc = "wailing", vc = "deadmines", deadmines = "deadmines", dm = "deadmines",
	sfk = "shadowfang", bfd = "blackfathom", stocks = "stockade", stockade = "stockade", stockades = "stockade",
	gnomer = "gnomeregan", gnomeregan = "gnomeregan", rfk = "razorfen kraul", sm = "scarlet", scarlet = "scarlet",
	rfd = "razorfen downs", ulda = "uldaman", uld = "uldaman", uldaman = "uldaman", zf = "zul'farrak",
	mara = "maraudon", maraudon = "maraudon", st = "sunken temple", sunken = "sunken temple",
	brd = "blackrock depths", lbrs = "lower blackrock", ubrs = "upper blackrock",
	dme = "dire maul", dmw = "dire maul", dmn = "dire maul", dmt = "dire maul",
	scholo = "scholomance", scholomance = "scholomance", strat = "stratholme", strath = "stratholme",
	stratholme = "stratholme",
}
-- a wing named in the post narrows to the activities with that word in their name, if any have it
local WINGS = {
	lib = "library", library = "library", arm = "armory", armory = "armory", armoury = "armory",
	cath = "cathedral", cathedral = "cathedral", gy = "graveyard", graveyard = "graveyard",
	east = "east", west = "west", north = "north", tribute = "north",
	dme = "east", dmw = "west", dmn = "north", dmt = "north",
}
local SKIP = { "wts", "wtb", "wtt", "selling", "buying", "recruit", "recruiting", "guild", "boost", "boosting",
	"enchanter", "enchanting", "enchants", "lfw", "crafter", "crafting", "summon", "summons", "portal", "port", "carry" }
local GROUP_MARKS = { "lfm", "lf%dm", "need", "needs", "lf tanks?", "lf heals?", "lf healers?", "lf dps", "lf more", "looking for more" }
local PLAYER_MARKS = { "lfg", "lf group", "lf grp", "lf party", "looking for group", "looking for a group" }
-- a plain "need ..." counts only with a dungeon or a role in it; these stand on their own
local STRONG = { "lfm", "lf%dm", "lf more", "looking for more", "lfg", "lf group", "lf grp", "lf party", "looking for group", "looking for a group" }

local function has(t, pat) return t:find("%f[%w]" .. pat .. "%f[^%w]") ~= nil end
local function any(t, list) for _, p in ipairs(list) do if has(t, p) then return true end end return false end

local function clean(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
		:gsub("{.-}", ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

local function actsMatching(fragment)
	local out = {}
	for id, i in pairs(A.info) do
		if type(i.name) == "string" and i.name:lower():find(fragment, 1, true) then out[#out + 1] = id end
	end
	table.sort(out, function(a, b) return (A.info[a].min or 0) > (A.info[b].min or 0) end)
	return out
end

local function findActs(t)
	local found, seen = {}, {}
	local function add(list) for _, id in ipairs(list) do if not seen[id] then seen[id] = true found[#found + 1] = id end end end
	local wing
	for w in t:gmatch("[%w']+") do
		local frag = SHORT[w]
		-- "dm" alone is the Deadmines; with a direction or "tribute" it's Dire Maul
		if w == "dm" and (has(t, "east") or has(t, "west") or has(t, "north") or has(t, "tribute")) then frag = "dire maul" end
		if frag then add(actsMatching(frag)) end
		wing = wing or WINGS[w]
	end
	-- the game's own names and short names, in the player's language
	for id, i in pairs(A.info) do
		if not seen[id] then
			local name, short = (i.name or ""):lower(), (i.short or ""):lower()
			if (#name >= 5 and t:find(name, 1, true)) or (#short >= 3 and short ~= name and has(t, short:gsub("(%p)", "%%%1"))) then
				seen[id] = true found[#found + 1] = id
			end
		end
	end
	if wing and #found > 1 then
		local narrowed = {}
		for _, id in ipairs(found) do if A.info[id].name:lower():find(wing, 1, true) then narrowed[#narrowed + 1] = id end end
		if #narrowed > 0 then found = narrowed end
	end
	return found
end

local function roles(t)
	local need = 0
	if has(t, "tanks?") then need = need + TANK end
	if has(t, "heals?") or has(t, "healers?") or has(t, "heala") then need = need + HEAL end
	if has(t, "dps") or has(t, "dd") or has(t, "damage") then need = need + DPS end
	if need == 0 and (has(t, "need all") or has(t, "all roles")) then need = TANK + HEAL + DPS end
	return need
end

-- One chat line -> { kind = "group" | "player", acts, need, size, text } or nil. Pure, for tests.
function N.parse(text)
	if type(text) ~= "string" or #text < 3 then return nil end
	local shown = clean(text)
	local t = " " .. shown:lower() .. " "
	if any(t, SKIP) then return nil end
	local group = any(t, GROUP_MARKS)
	local player = not group and any(t, PLAYER_MARKS)
	if not group and not player then return nil end
	if A.load then A.load() end
	local p = { kind = group and "group" or "player", acts = findActs(t), need = roles(t), text = shown }
	-- "need help" is noise; "need a tank for BRD" or "LF2M Hogger" is a group
	if #p.acts == 0 and p.need == 0 and not any(t, STRONG) then return nil end
	if group then
		local have = tonumber(t:match("(%d)%s*/%s*5"))
		local more = tonumber(t:match("lf(%d)m"))
		p.size = (have and have >= 1 and have <= 4 and have) or (more and more >= 1 and more <= 4 and 5 - more) or 2
		p.sizeGuess = not have and not more
	else
		p.size = 1
	end
	return p
end

local CHANNELS = { "^lookingforgroup", "^lfg", "^trade", "^general", "^world" }
local function wanted(chan)
	chan = chan:gsub("^%d+%.%s*", ""):lower()
	for _, pat in ipairs(CHANNELS) do if chan:find(pat) then return true end end
	return false
end

function N.onChat(text, author, chanName, baseName, guid)
	if not enabled() then return end
	text, author = str(text), str(author)
	if not text or not author or author == "" or L.isMe(author) then return end
	local chan = str(baseName) or str(chanName) or ""
	if chan == "" or not wanted(chan) then return end
	local p = N.parse(text)
	if not p then return end
	local class
	if str(guid) and GetPlayerInfoByGUID then
		local ok, _, cls = pcall(GetPlayerInfoByGUID, guid)
		if ok then class = str(cls) end
	end
	local matched = #p.acts > 0
	put({
		leader = author, src = "chat", chan = (chan:gsub("^%d+%.%s*", ""):gsub("%s*%d+$", "")),
		class = class, size = p.size, sizeGuess = p.sizeGuess, need = p.need, acts = p.acts,
		title = matched and "" or p.text:sub(1, 70), note = matched and p.text:sub(1, 120) or "",
		got = clock(),
	})
	N.stats.chat = N.stats.chat + 1
	L.probe(author, "chat")
	changed()
end

-- --------------------------------------------------------------------------------------------
-- the game's Group Finder

local function finderListing(id, now)
	local ok, info = pcall(C_LFGList.GetSearchResultInfo, id)
	if not ok or not readable(info) or type(info) ~= "table" then return nil end
	local leader = str(info.leaderName)
	if not leader or leader == "" or L.isMe(leader) then return nil end
	if readable(info.isDelisted) and info.isDelisted == true then return nil end
	if readable(info.hasSelf) and info.hasSelf == true then return nil end
	local size = num(info.numMembers) or 1
	local acts = {}
	local ids = info.activityIDs
	if readable(ids) and type(ids) == "table" then
		for _, a in ipairs(ids) do local n = num(a) if n then acts[#acts + 1] = n end end
	elseif num(info.activityID) then
		acts[1] = num(info.activityID)
	end
	local who
	if size <= 1 and C_LFGList.GetSearchResultPlayerInfo then
		local okP, m = pcall(C_LFGList.GetSearchResultPlayerInfo, id, 1)
		if okP and readable(m) and type(m) == "table" then who = m end
	elseif C_LFGList.GetSearchResultLeaderInfo then
		local okP, m = pcall(C_LFGList.GetSearchResultLeaderInfo, id)
		if okP and readable(m) and type(m) == "table" then who = m end
	end
	local need = 0
	if size <= 1 then
		-- the roles a solo player signed up as
		local r = who and who.lfgRoles
		if readable(r) and type(r) == "table" then
			if readable(r.tank) and r.tank == true then need = need + TANK end
			if readable(r.healer) and r.healer == true then need = need + HEAL end
			if readable(r.dps) and r.dps == true then need = need + DPS end
		end
	elseif size < 5 and C_LFGList.GetSearchResultMemberCounts then
		-- a group: the roles it's short of, for a party of 1 tank, 1 healer, 3 damage
		local okC, c = pcall(C_LFGList.GetSearchResultMemberCounts, id)
		if okC and readable(c) and type(c) == "table" then
			if (num(c.TANK) or 1) < 1 then need = need + TANK end
			if (num(c.HEALER) or 1) < 1 then need = need + HEAL end
			if (num(c.DAMAGER) or 3) < 3 then need = need + DPS end
		end
	end
	return {
		leader = leader, src = "finder", size = size, acts = acts, need = need,
		class = who and str(who.classFilename), level = who and num(who.level) or 0,
		note = str(info.comment) or "", got = now,
	}
end

local waitingCat   -- the category of the search we sent, until its results arrive

-- when the last Group Finder results came in (from our search or anyone else's, the game's own
-- window or another addon): older than 2 minutes counts as stale
N.resultsAt = nil
function N.stale() return not N.resultsAt or GetTime() - N.resultsAt > 120 end

function N.readFinder()
	if not enabled() or not C_LFGList then return end
	N.resultsAt = GetTime()
	local get = C_LFGList.GetFilteredSearchResults or C_LFGList.GetSearchResults
	if not get then return end
	local ok, total, ids = pcall(get)
	if not ok or not readable(total) or not readable(ids) or type(ids) ~= "table" then waitingCat = nil return end
	local now, seen = clock(), {}
	for _, id in ipairs(ids) do
		local l = readable(id) and finderListing(id, now)
		if l then
			seen[l.leader] = true
			put(l)
			L.probe(l.leader, "finder")
		end
	end
	-- after our own search, anyone in that category the game no longer lists has delisted
	if waitingCat then
		for name, l in pairs(L.nearby) do
			if l.src == "finder" and l.cat == waitingCat and not seen[name] then L.nearby[name] = nil end
		end
	end
	waitingCat = nil
	N.stats.finder = N.count("finder")
	changed()
end

function N.readOne(id)
	if not enabled() or not C_LFGList or not readable(id) then return end
	local l = finderListing(id, clock())
	if l then put(l) changed() end
end

-- the categories worth searching (ones with activities), dungeons first; each search takes the next
local turn = 0
local function nextCategory()
	local cats = {}
	for _, c in ipairs(A.load()) do
		if not c.fallback and c.id and c.id > 0 and #c.acts > 0 and not c.summon then
			if tostring(c.name):lower():find("dungeon") then table.insert(cats, 1, c) else cats[#cats + 1] = c end
		end
	end
	if #cats == 0 then return nil end
	-- dungeons every other search, the rest in turn between
	turn = turn + 1
	if turn % 2 == 1 or #cats == 1 then return cats[1] end
	return cats[2 + (math.floor(turn / 2) - 1) % (#cats - 1)]
end

-- --------------------------------------------------------------------------------------------
-- Languages. With no language filter the game's search returns your own language only; given a
-- set, it returns those and the default ones it locks (yours). Results carry no language, so this
-- only works on the search. OpenGroup sends every offered language by default ("All languages"
-- in Browse's Filter menu), or the ones picked there; it never changes the game's own saved
-- language filter. Saved: OpenGroupDB.langAll (nil = on) and OpenGroupDB.langs = { [code] = true }.

-- the codes the game offers, in its order (none if it answers anything else)
function N.offeredLanguages()
	local out, seen = {}, {}
	local get = C_LFGList and C_LFGList.GetAvailableLanguageSearchFilter
	local ok, list = false, nil
	if get then ok, list = pcall(get) end
	if ok and type(list) == "table" then
		for _, code in ipairs(list) do
			if type(code) == "string" and not seen[code] then seen[code] = true out[#out + 1] = code end
		end
	end
	return out
end
-- the ones the game always searches (yours), as a set
function N.lockedLanguages()
	local get = C_LFGList and C_LFGList.GetDefaultLanguageSearchFilter
	local ok, set = false, nil
	if get then ok, set = pcall(get) end
	return (ok and type(set) == "table") and set or {}
end
function N.allLanguages() return not (type(OpenGroupDB) == "table" and OpenGroupDB.langAll == false) end
-- the set for C_LFGList.Search: every offered language, or the locked ones and those picked;
-- nil (the game's default, your language) when that adds nothing
function N.languageFilter()
	local locked, picked = N.lockedLanguages(), type(OpenGroupDB) == "table" and type(OpenGroupDB.langs) == "table" and OpenGroupDB.langs or {}
	local all = N.allLanguages()
	local filter, beyond = {}, false
	for _, code in ipairs(N.offeredLanguages()) do
		if locked[code] then filter[code] = true
		elseif all or picked[code] then filter[code] = true beyond = true end
	end
	return beyond and filter or nil
end
-- a language's name: the game's own string where it has one, else the code
function N.languageName(code)
	return _G["LFG_LIST_LANGUAGE_" .. tostring(code):upper()] or tostring(code)
end

local lastSearch = -SEARCH_GAP
N.searchAt = nil   -- GetTime() of our last search call, to tell a blocked search from anything else
-- The game allows a Group Finder search only inside a click (a hardware event), so this is only
-- called straight from OpenGroup's click handlers (Scan.auto(true), Refresh). It calls the game's
-- function directly, once, with the signature the game's own window uses: not through pcall and
-- with no second try, since a second call in the same click is refused.
-- explicit: the player clicked Search themselves; that may try again even after the game refused
-- a search earlier this session, and even with the game's own window open. catID: search this
-- category (the one Browse is filtered to) instead of taking turns.
function N.search(force, explicit, catID)
	if not enabled() or (N.noSearch and not explicit) or not (C_LFGList and C_LFGList.Search) then return false end
	local t = GetTime()
	if t - lastSearch < (force and 5 or SEARCH_GAP) then return false end
	-- leave the game's own list alone while the player has it open (unless they asked)
	if not explicit and LFGParentFrame and LFGParentFrame.IsShown and LFGParentFrame:IsShown() then return false end
	local c = catID and A.category and A.category(catID)
	if not (c and not c.fallback and c.id > 0 and #c.acts > 0 and not c.summon) then c = nextCategory() end
	if not c then return false end
	lastSearch = t
	waitingCat = c.id
	N.stats.searches = N.stats.searches + 1
	N.searchAt = t
	-- which click it came from, for /og status if the game blocks it
	N.searchFrom = debugstack and debugstack(2, 4, 0) or nil
	C_LFGList.Search(c.id, 0, 0, N.languageFilter(), false, nil, c.acts)
	return true
end

-- --------------------------------------------------------------------------------------------
-- posting your listing in LookingForGroup (on the List click, once)

function N.lfgChannel()
	local list = { GetChannelList() }
	for i = 1, #list, 3 do
		local id, name = list[i], list[i + 1]
		if type(name) == "string" and name:gsub("^%d+%.%s*", ""):lower():find("^lookingforgroup") then return id end
	end
	if GetChannelName then
		for id = 1, 10 do
			local ok, cid, name = pcall(GetChannelName, id)
			if ok and type(name) == "string" and name:lower():find("^lookingforgroup") then return cid end
		end
	end
	return nil
end

function N.post(text)
	local id = N.lfgChannel()
	if not id then return false, "You're not in the LookingForGroup channel, so nothing was posted there." end
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
		local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
		if ok and locked then return false, "Chat is locked here, so nothing was posted in LookingForGroup." end
	end
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	local ok = send and pcall(send, text, "CHANNEL", nil, id)
	if ok then N.stats.posted = N.stats.posted + 1 end
	return ok and true or false, (not ok) and "The game didn't let OpenGroup post in LookingForGroup." or nil
end

-- --------------------------------------------------------------------------------------------
-- events and housekeeping

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_CHANNEL")
f:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
f:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
f:RegisterEvent("LFG_LIST_SEARCH_FAILED")
f:RegisterEvent("ADDON_ACTION_BLOCKED")
f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
f:SetScript("OnEvent", function(_, ev, ...)
	if ev == "CHAT_MSG_CHANNEL" then
		local text, author, _, chanName, _, _, _, _, baseName, _, _, guid = ...
		pcall(N.onChat, text, author, chanName, baseName, guid)
	elseif ev == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
		pcall(N.readFinder)
	elseif ev == "LFG_LIST_SEARCH_RESULT_UPDATED" then
		pcall(N.readOne, (...))
	elseif ev == "LFG_LIST_SEARCH_FAILED" then
		waitingCat = nil
	elseif ev == "ADDON_ACTION_BLOCKED" or ev == "ADDON_ACTION_FORBIDDEN" then
		-- "Interface action failed because of an AddOn": say what the game refused, and if it was
		-- our Group Finder search, stop searching for this session (chat rows keep coming)
		-- the event fires for every addon: only ours counts, and it's said once a session
		local who, what = ...
		if who == "OpenGroup" then
			N.blocked = tostring(what or "?")
			N.blockedCount = (N.blockedCount or 0) + 1
			-- right after one of our two click-only calls: that call. The most recent one wins.
			local S, t = L.scan, GetTime()
			local whoRecent = S and S.whoAt and t - S.whoAt <= 0.5
			local searchRecent = N.searchAt and t - N.searchAt <= 0.5
			if N.blocked:find("SendWho") or (whoRecent and (not searchRecent or S.whoAt >= N.searchAt)) then
				N.blocked = "C_FriendList.SendWho"
				if S and not S.noWho then L.print("the game didn't allow OpenGroup's /who search, so it won't run it again this session.") end
				if S then S.noWho = true end
			elseif N.blocked:find("Search") or searchRecent then
				N.blocked = "C_LFGList.Search"
				N.blockedAfter = N.searchAt and (GetTime() - N.searchAt) or nil
				N.blockedFrom = N.searchFrom
				if not N.noSearch then L.print("the game didn't allow OpenGroup's Group Finder search, so it won't search again this session. Groups from chat and other OpenGroup players still show.") end
				N.noSearch = true
			elseif N.blockedCount == 1 then
				L.print(("the game blocked an action (%s) and named OpenGroup. /og status shows it again."):format(N.blocked))
			end
		end
	end
end)

function N.expire()
	local now, gone = clock(), false
	for name, l in pairs(L.nearby) do
		if now - (l.got or 0) > (l.src == "chat" and CHAT_KEEP or FINDER_KEEP) then L.nearby[name] = nil gone = true end
	end
	if not enabled() and next(L.nearby) then L.nearby = {} gone = true end
	if gone then changed() end
end
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(30, function() pcall(N.expire) end) end

-- --------------------------------------------------------------------------------------------
-- Every shard's Group Finder. The game only shows a shard its own groups, so each shard's
-- Group Finder results travel to OpenGroup players on the other shards: one reporter per shard
-- (the OpenGroup player there whose name sorts first among those reporting; the others stand by),
-- a digest every 90 seconds of what that shard's searches showed (any search: ours, the game's
-- window, another addon), at most 60 groups. Groups from other shards show in Browse marked as
-- seen in that shard's Group Finder; they're never auto-invited, and they go when the reporter's
-- next digest leaves them out or after 5 minutes.

L.remote = {}             -- [leader] = a listing-shaped row, src = "remote", shard, reporter
N.claims = {}             -- [name] = time: an OpenGroup player on our shard said they report
N.stats.harvested, N.stats.reported, N.stats.remoteBy = 0, 0, {}
-- how many passed-on groups we already had in our own Group Finder results: if the game's Group
-- Finder turns out to be shared between shards, this is near 100% and the sharing adds nothing
N.stats.overlapSeen, N.stats.overlapTotal = 0, 0
N.stats.overlapBy = {}    -- [shard] = { seen, total } from that shard's latest complete digest

-- "shard 56 100% (30 groups), shard 12 0% (18 groups)", or nil before any digest
function N.overlapText()
	local list = {}
	for shard, o in pairs(N.stats.overlapBy) do list[#list + 1] = { shard = shard, o = o } end
	if #list == 0 then return nil end
	table.sort(list, function(a, b) return a.shard < b.shard end)
	local out = {}
	for _, e in ipairs(list) do
		out[#out + 1] = ("" .. L.CHAN .. " %d %d%% (%d %s)"):format(e.shard, e.o.total > 0 and math.floor(100 * e.o.seen / e.o.total + 0.5) or 0, e.o.total, e.o.total == 1 and "group" or "groups")
	end
	return table.concat(out, ", ")
end
-- Trade channel numbers aren't servers: several Trade numbers can share one hidden server (and
-- with it one Group Finder, LookingForGroup channel and Trade chat). Another Trade number whose
-- passed-on Group Finder groups we nearly all had already is our server; one we had almost none
-- of is another server; anything else (or too few groups to tell) is unknown.
local SAME_AT, DIFF_AT, MIN_GROUPS = 0.9, 0.3, 5
function N.matchOf(trade)
	local o = N.stats.overlapBy[trade]
	if o and o.total >= MIN_GROUPS then return o.seen / o.total, o.total end
	return nil
end
-- true: our server, false: another server, nil: can't tell yet
function N.sameServer(trade, mine)
	mine = mine or (L.shard and L.shard()) or 0
	if not trade or trade <= 0 or mine <= 0 then return nil end
	if trade == mine then return true end
	local m = N.matchOf(trade)
	if not m then return nil end
	if m >= SAME_AT then return true elseif m <= DIFF_AT then return false end
	return nil
end
-- the Trade numbers on our server, lowest first
function N.myTrades()
	local mine = (L.shard and L.shard()) or 0
	if mine <= 0 then return {} end
	local list = { mine }
	for k in pairs(N.stats.overlapBy) do if k ~= mine and N.sameServer(k, mine) then list[#list + 1] = k end end
	table.sort(list)
	return list
end
-- our server as its channel numbers: "Chat 47 + 56" once another number matched; before that
-- "Chat 47, no other numbers compared yet" (or "no other number matched yet"). No made-up names:
-- the numbers are what players can check.
function N.serverName()
	local t = N.myTrades()
	if #t == 0 then return L.CHAN .. " ?, not known yet" end
	if #t == 1 then
		return ("%s %d, %s"):format(L.CHAN, t[1], next(N.stats.overlapBy) and "no other number matched yet" or "no other numbers compared yet")
	end
	return L.CHAN .. " " .. table.concat(t, " + ")
end
-- the Network tab's headline: { big line, small line or nil }
function N.serverHeadline()
	local t = N.myTrades()
	if #t > 1 then return "Your server: " .. L.CHAN .. " " .. table.concat(t, " + "), nil end
	if #t == 0 then return "You're on " .. L.CHAN .. " ?", "The channel number shows once you're in Trade or LookingForGroup." end
	return ("You're on %s %d"):format(L.CHAN, t[1]), next(N.stats.overlapBy) and "No other number matched yet." or "No other numbers compared yet."
end
-- for a row: "Your server", "Other server" or "Trade 61"
function N.whereText(trade)
	local same = N.sameServer(trade)
	if same == true then return "Your server" elseif same == false then return "Other server" end
	return (trade or 0) > 0 and (L.CHAN .. " " .. trade) or (L.CHAN .. " ?")
end
-- for a tooltip: the Trade number and how we know
function N.whereTip(trade)
	if not trade or trade <= 0 then return (L.CHAN .. " unknown") end
	local mine = (L.shard and L.shard()) or 0
	if trade == mine then return ("" .. L.CHAN .. " %d, your server"):format(trade) end
	local m, n = N.matchOf(trade)
	local same = N.sameServer(trade)
	local how = m and (" (Group Finder %d%% the same as yours, %d groups)"):format(math.floor(m * 100 + 0.5), n) or ""
	if same == true then return ("" .. L.CHAN .. " %d, your server%s"):format(trade, how)
	elseif same == false then return ("" .. L.CHAN .. " %d, another server%s"):format(trade, how) end
	return ("" .. L.CHAN .. " %d, server unknown%s"):format(trade, how)
end
local REPORT_EVERY, CLAIM_KEEP, REMOTE_KEEP, MAX_TARGETS = 90, 150, 300, 8
local CHAT_SHARE_KEEP = 600   -- a passed-on chat post, this long
N.stats.chatShared, N.stats.chatBy = 0, {}
local digestSeq = 0
local chatPartial = {}

-- "Share LFG chat from my shard": on unless turned off
function N.shareChat() return not (type(OpenGroupDB) == "table" and OpenGroupDB.shareChat == false) end

-- our shard's recent LookingForGroup posts worth passing on: newest first, not OpenGroup users
function N.chatItems()
	local items, t = {}, clock()
	for name, l in pairs(L.nearby) do
		if l.src == "chat" and t - (l.got or 0) < CHAT_SHARE_KEEP and not L.listings[name] and not L.peers[name] then
			local text = (l.note ~= "" and l.note) or l.title or ""
			if text ~= "" then
				items[#items + 1] = { leader = name, age = math.max(0, t - (l.got or t)), act = (l.acts or {})[1] or 0,
					need = l.need or 0, size = l.size or 1, text = text, got = l.got or 0 }
			end
		end
	end
	table.sort(items, function(a, b) return a.got > b.got end)
	while #items > P.MAX_CHAT do table.remove(items) end
	return items
end
local partial = {}        -- [reporter] = { digest, seen = { [leader] = true }, parts = n }

-- our shard's Group Finder groups worth passing on: fresh, not OpenGroup users (they travel themselves)
function N.digestItems()
	local items, t = {}, clock()
	for name, l in pairs(L.nearby) do
		if l.src == "finder" and t - (l.got or 0) < FINDER_KEEP and not L.listings[name] and not L.peers[name] then
			items[#items + 1] = { leader = name, act = (l.acts or {})[1] or 0, more = { (l.acts or {})[2], (l.acts or {})[3], (l.acts or {})[4] }, size = l.size or 1, need = l.need or 0, age = math.max(0, t - (l.got or t)), got = l.got or 0 }
		end
	end
	table.sort(items, function(a, b) return a.got > b.got end)
	while #items > P.MAX_DIGEST do table.remove(items) end
	N.stats.harvested = #items
	return items
end

-- Do we report our shard? Only with fresh results of our own, and only if no OpenGroup player on our
-- shard whose name sorts first has said recently that they report. Pure, for tests.
function N.shouldReport(me, claims, now, haveFresh)
	if not haveFresh then return false end
	for name, at in pairs(claims) do
		if now - at < CLAIM_KEEP and name < me then return false end
	end
	return true
end

local turn, chatTurn = 0, 0
N.chatClaims = {}         -- [name] = time: an OpenGroup player on our chat number said they pass on its LFG chat
function N.report()
	if not enabled() or not L.shard or L.shard() <= 0 then return false end
	local fresh = N.resultsAt and GetTime() - N.resultsAt < FINDER_KEEP
	local items = fresh and N.digestItems() or {}
	local posts = N.shareChat() and N.chatItems() or {}
	local me, now = L.me() or "", clock()
	-- two elections: the Group Finder is per server (several chat numbers can share one), so one
	-- reporter per server; LookingForGroup chat is per chat number, so one reporter per number,
	-- whatever server the numbers turn out to share
	local gf = #items > 0 and N.shouldReport(me, N.claims, now, true)
	local chat = #posts > 0 and N.shouldReport(me, N.chatClaims, now, true)
	if not gf and not chat then return false end
	local mine = L.shard()
	local gfTo, chatTo, near = {}, {}, {}
	for name, p in pairs(L.live()) do
		local n = p.shard or 0
		local same = N.sameServer(n, mine)
		if n > 0 and same ~= true then gfTo[#gfTo + 1] = name end
		if n > 0 and n ~= mine then chatTo[#chatTo + 1] = name end
		local what = ((gf and same == true) and "f" or "") .. ((chat and n == mine) and "c" or "")
		if what ~= "" then near[#near + 1] = { name = name, what = what } end
	end
	if not gf then gfTo = {} end
	if not chat then chatTo = {} end
	if #gfTo == 0 and #chatTo == 0 then return false end
	digestSeq = digestSeq + 1
	local sent = false
	if #gfTo > 0 then
		table.sort(gfTo)
		local msgs = P.finderDigest(mine, digestSeq, items)
		for i = 1, math.min(MAX_TARGETS, #gfTo) do
			turn = turn % #gfTo + 1
			for _, m in ipairs(msgs) do L.send(gfTo[turn], m, true) end
		end
		N.stats.reported = N.stats.reported + #items
		sent = true
	end
	if #chatTo > 0 then
		table.sort(chatTo)
		local msgs = P.chatDigest(mine, digestSeq, posts)
		for i = 1, math.min(MAX_TARGETS, #chatTo) do
			chatTurn = chatTurn % #chatTo + 1
			for _, m in ipairs(msgs) do L.send(chatTo[chatTurn], m, true) end
		end
		N.stats.chatShared = N.stats.chatShared + #posts
		sent = true
	end
	-- tell the others on our server / our number that we report, so they stand by
	table.sort(near, function(a, b) return a.name < b.name end)
	for i = 1, math.min(10, #near) do L.send(near[i].name, P.reporting(#items + #posts, near[i].what), true) end
	return sent
end

L.onReporter = function(sender, d)
	local p = L.peers[sender]
	if not p then return end
	local what = d.what or "fc"
	if what:find("f", 1, true) and N.sameServer(p.shard) == true then N.claims[L.short(sender)] = clock() end
	if what:find("c", 1, true) and p.shard == L.shard() then N.chatClaims[L.short(sender)] = clock() end
end

-- a passed-on group's activities: the first, then the others it's queued for
local function remoteActs(it)
	local out = {}
	if (it.act or 0) > 0 then out[1] = it.act end
	for _, v in ipairs(it.more or {}) do out[#out + 1] = v end
	return out
end

L.onFinderDigest = function(sender, d)
	if d.shard <= 0 or d.shard == L.shard() then return end   -- our own shard we see ourselves
	local t = clock()
	local reporter = L.short(sender)
	local pend = partial[reporter]
	if not pend or pend.digest ~= d.digest then pend = { digest = d.digest, seen = {}, got = 0, ovSeen = 0, ovTotal = 0 } partial[reporter] = pend end
	pend.got = pend.got + 1
	for _, it in ipairs(d.items) do
		local name = it.leader
		local mine = L.nearby[name]
		N.stats.overlapTotal = N.stats.overlapTotal + 1
		pend.ovTotal = pend.ovTotal + 1
		if mine and mine.src == "finder" then N.stats.overlapSeen = N.stats.overlapSeen + 1 pend.ovSeen = pend.ovSeen + 1 end
		-- someone OpenGroup knows directly, or in our own results, is shown from there instead
		if not L.isMe(name) and not L.listings[name] and not L.nearby[name] and not (L.ignored and L.ignored(name)) then
			L.remote[name] = {
				leader = name, src = "remote", shard = d.shard, reporter = reporter, digest = d.digest,
				size = it.size, need = it.need, acts = remoteActs(it), cat = catOf({ it.act }),
				level = 0, got = t - it.age, seq = 0, hops = 0, price = 0, quest = 0, title = "", note = "",
			}
			pend.seen[name] = true
		end
	end
	-- the last part of a digest: what this reporter no longer lists is gone
	if d.part == d.parts then
		local n = 0
		for name, r in pairs(L.remote) do
			if r.reporter == reporter and r.src == "remote" then
				if not pend.seen[name] then L.remote[name] = nil else n = n + 1 end
			end
		end
		N.stats.remoteBy[d.shard] = n
		N.stats.overlapBy[d.shard] = { seen = pend.ovSeen, total = pend.ovTotal }
		partial[reporter] = nil
	end
	changed()
end

-- another shard's LookingForGroup posts: kept like its Group Finder groups, as "LFG <shard>" rows
L.onChatDigest = function(sender, d)
	if d.shard <= 0 or d.shard == L.shard() then return end
	local t = clock()
	local reporter = L.short(sender)
	local pend = chatPartial[reporter]
	if not pend or pend.digest ~= d.digest then pend = { digest = d.digest, seen = {} } chatPartial[reporter] = pend end
	for _, it in ipairs(d.items) do
		local name = it.leader
		local held = L.remote[name]
		if not L.isMe(name) and not L.listings[name] and not L.nearby[name] and not (L.ignored and L.ignored(name))
			and not (held and held.src == "remote") then   -- a Group Finder group of theirs says more
			local matched = it.act > 0
			L.remote[name] = {
				leader = name, src = "remotechat", shard = d.shard, reporter = reporter, digest = d.digest, chan = "LFG",
				size = it.size, need = it.need, acts = matched and { it.act } or {}, cat = catOf({ it.act }),
				level = 0, got = t - it.age, seq = 0, hops = 0, price = 0, quest = 0,
				title = matched and "" or it.text:sub(1, 70), note = matched and it.text or "",
			}
			pend.seen[name] = true
		end
	end
	if d.part == d.parts then
		local n = 0
		for name, r in pairs(L.remote) do
			if r.reporter == reporter and r.src == "remotechat" then
				if not pend.seen[name] then L.remote[name] = nil else n = n + 1 end
			end
		end
		N.stats.chatBy[d.shard] = n
		chatPartial[reporter] = nil
	end
	changed()
end

function N.expireRemote()
	local t, gone = clock(), false
	for name, r in pairs(L.remote) do
		if t - (r.got or 0) > (r.src == "remotechat" and CHAT_SHARE_KEEP or REMOTE_KEEP) then L.remote[name] = nil gone = true end
	end
	for name, at in pairs(N.claims) do if t - at > CLAIM_KEEP then N.claims[name] = nil end end
	for name, at in pairs(N.chatClaims) do if t - at > CLAIM_KEEP then N.chatClaims[name] = nil end end
	if not enabled() and next(L.remote) then L.remote = {} gone = true end
	if gone then changed() end
end
if C_Timer and C_Timer.NewTicker then
	C_Timer.NewTicker(REPORT_EVERY, function() pcall(N.report) end)
	C_Timer.NewTicker(30, function() pcall(N.expireRemote) end)
end
