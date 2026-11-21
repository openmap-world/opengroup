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
-- chat: "LFM BRD need heals", "LF1 tank strat", "healer LFG scholo", "suche Heiler fuer BRD".
-- tools/chat_corpus.txt holds the lines this is tuned against (tools/chat_corpus.py runs them),
-- and "/og chatlog on" collects real ones from an evening of play.

-- what people type -> a piece of the activity's (English) name; every one is matched against the
-- activities the game actually has, so one with no such activity simply finds nothing
local SHORT = {
	rfc = "ragefire", wc = "wailing", vc = "deadmines", deadmines = "deadmines", deadmine = "deadmines",
	sfk = "shadowfang", bfd = "blackfathom", stocks = "stockade", stockade = "stockade", stockades = "stockade",
	gnomer = "gnomeregan", gnomeregan = "gnomeregan", rfk = "razorfen kraul", sm = "scarlet", scarlet = "scarlet",
	rfd = "razorfen downs", ulda = "uldaman", uld = "uldaman", uldaman = "uldaman", zf = "zul'farrak",
	mara = "maraudon", maraudon = "maraudon", princess = "maraudon",
	st = "sunken temple", sunken = "sunken temple",
	brd = "blackrock depths", emp = "blackrock depths", jailbreak = "blackrock depths",
	lbrs = "lower blackrock", ubrs = "upper blackrock",
	dme = "dire maul", dmw = "dire maul", dmn = "dire maul", dmt = "dire maul", dire = "dire maul",
	scholo = "scholomance", scholomance = "scholomance", strat = "stratholme", strath = "stratholme",
	stratholme = "stratholme", baron = "stratholme",
	-- raids
	mc = "molten core", ony = "onyxia", onyxia = "onyxia", zg = "zul'gurub", bwl = "blackwing",
	aq20 = "ahn'qiraj", aq40 = "ahn'qiraj", aq = "ahn'qiraj", naxx = "naxxramas", naxxramas = "naxxramas",
	-- Forever's own
	krol = "krol", kroldok = "krol", thanes = "thanes", lordaeron = "lordaeron", ruins = "lordaeron",
	blackmaw = "blackmaw", shaper = "shaper", shapers = "shaper",
}
-- typed in other alphabets (matched as plain text)
local SHORT_UTF8 = { ["\208\177\209\128\208\180"] = "blackrock depths", ["\208\145\208\160\208\148"] = "blackrock depths", ["\209\129\209\130\209\128\208\176\209\130"] = "stratholme",
	["\208\161\209\130\209\128\208\176\209\130"] = "stratholme", ["\209\136\208\190\208\187\208\190"] = "scholomance", ["\208\168\208\190\208\187\208\190"] = "scholomance" }
-- a wing named in the post narrows to the activities with that word in their name, if any have it
local WINGS = {
	lib = "library", library = "library", arm = "armory", armory = "armory", armoury = "armory",
	cath = "cathedral", cathedral = "cathedral", gy = "graveyard", graveyard = "graveyard",
	east = "east", west = "west", north = "north", tribute = "north",
	dme = "east", dmw = "west", dmn = "north", dmt = "north",
	live = "main", ud = "service", undead = "service", baron = "service",
	princess = "inner", inner = "inner", orange = "orange", purple = "purple",
}
-- service and sell lines: never a group post
local SELL = { "wts", "wtb", "wtt", "lfw", "selling", "buying", "boost", "boosts", "boosting", "carry", "carries",
	"recruit", "recruiting", "lf guild", "lfguild", "guild lf", "apply" }
-- these alone make a line a service ad, unless it's plainly a group post ("LFM BRD, can summon")
local SERVICE = { "summons?", "portals?", "port", "enchanter", "enchanting", "enchants", "crafter", "crafting", "guild" }

-- role words: English shorthands, and the obvious words in other languages
local TANK_W = { "tanks?", "tnk", "mt", "prot", "tanque" }
local HEAL_W = { "heals?", "healers?", "healz", "heala", "hps", "resto", "heiler", "soigneur", "sanador", "curandero" }
local DPS_W = { "dps", "dd", "rdps", "mdps", "casters?", "melee", "ranged", "damage", "dmg" }
local TANK_U = { "\209\130\208\176\208\189\208\186" }
local HEAL_U = { "\209\133\208\184\208\187" }
local DPS_U = { "\208\180\208\180", "\208\180\208\191\209\129" }
-- a class asked for, when no role word says which role: the role it most likely fills
local CLASS_ROLE = { priest = HEAL, druid = HEAL, shaman = HEAL, shammy = HEAL, paladin = HEAL, pala = HEAL, pally = HEAL,
	mage = DPS, lock = DPS, warlock = DPS, hunter = DPS, hunt = DPS, rogue = DPS }

local function has(t, pat) return t:find("%f[%w]" .. pat .. "%f[^%w]") ~= nil end
local function any(t, list) for _, p in ipairs(list) do if has(t, p) then return true end end return false end
local function anyPlain(t, list) for _, p in ipairs(list) do if t:find(p, 1, true) then return true end end return false end

-- (spaces by hand: %s can take bytes of other alphabets, e.g. the 0xA0 inside a Cyrillic letter)
local function clean(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
		:gsub("{.-}", ""):gsub("[%[%]]", " "):gsub("[ \t\r\n]+", " "):gsub("^ ", ""):gsub(" $", ""))
end

local function actsMatching(fragment)
	local out = {}
	for id, i in pairs(A.info) do
		if type(i.name) == "string" and i.name:lower():find(fragment, 1, true) then out[#out + 1] = id end
	end
	table.sort(out, function(a, b) return (A.info[a].min or 0) > (A.info[b].min or 0) end)
	return out
end

local function findActs(t, raw)
	local found, seen = {}, {}
	local function add(list) for _, id in ipairs(list) do if not seen[id] then seen[id] = true found[#found + 1] = id end end end
	local wing
	local lvl = UnitLevel and UnitLevel("player") or 60
	for w in t:gmatch("[%w']+") do
		w = w:gsub("'", "")
		local frag = SHORT[w]
		-- "dm" alone: Dire Maul at 55 and up (or with a wing named), the Deadmines below
		if w == "dm" then
			frag = (lvl >= 55 or has(t, "east") or has(t, "west") or has(t, "north") or has(t, "tribute")) and "dire maul" or "deadmines"
		end
		if frag then add(actsMatching(frag)) end
		wing = wing or WINGS[w]
	end
	for word, frag in pairs(SHORT_UTF8) do if raw:find(word, 1, true) then add(actsMatching(frag)) end end
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

local function roles(t, raw)
	local need = 0
	if any(t, TANK_W) or anyPlain(raw, TANK_U) then need = need + TANK end
	if any(t, HEAL_W) or anyPlain(raw, HEAL_U) then need = need + HEAL end
	if any(t, DPS_W) or anyPlain(raw, DPS_U) then need = need + DPS end
	if need == 0 and (has(t, "need all") or has(t, "all roles")) then need = TANK + HEAL + DPS end
	if need == 0 then
		for cls, r in pairs(CLASS_ROLE) do if has(t, cls .. "s?") and need % (r * 2) < r then need = need + r end end
	end
	return need
end

-- "need 2 more" / "LF1M" / "LF2" / "LFM1" -> how many they still want (1-4), or nil
local function stillWanted(t)
	local n = t:match("lf%s?(%d)%s?m%f[^%w]") or t:match("lfm%s?(%d)%f[^%d]") or t:match("lf(%d)%f[^%d]")
		or t:match("need (%d) more") or t:match("%f[%w](%d) more%f[^%w]") or t:match("need (%d)%f[^%w]")
	n = tonumber(n)
	return n and n >= 1 and n <= 4 and n or nil
end

-- seeking players for a group / a group for oneself, in other languages (plain text)
local SEEK_U = { "\208\184\209\137\209\131", "\208\184\209\137\208\181\208\188", "\208\189\209\131\208\182\208\181\208\189", "\208\189\209\131\208\182\208\189\208\176", "\208\189\209\131\208\182\208\189\209\139", "\208\187\209\132\208\188", "\208\152\209\137\209\131", "\208\152\209\137\208\181\208\188", "\208\157\209\131\208\182\208\181\208\189", "\208\157\209\131\208\182\208\189\208\176", "\208\157\209\131\208\182\208\189\209\139", "\208\155\208\164\208\156" }
local SEEK = { "suche", "suchen", "such", "cherche", "recherche", "cherchons", "busco", "buscamos", "procuro", "procuramos" }
local GROUP_WORD = { "gruppe", "grp", "groupe", "grupo", "group", "gruppo" }

-- One chat line -> { kind = "group" | "player", acts, need, size, min, max, text } or nil. Pure, for tests.
function N.parse(text)
	if type(text) ~= "string" or #text < 3 then return nil end
	local shown = clean(text)
	local t = " " .. shown:lower() .. " "
	if any(t, SELL) then return nil end
	local lfRole = has(t, "lf") and (any(t, TANK_W) or any(t, HEAL_W) or any(t, DPS_W)) and t:find("lf%s+%a") ~= nil
	local lfClass = false
	for cls in pairs(CLASS_ROLE) do if has(t, "lf " .. cls) or has(t, "need " .. cls) then lfClass = true end end
	local n = stillWanted(t)
	local seek = any(t, SEEK) or anyPlain(shown, SEEK_U)
	local seekGroup = seek and any(t, GROUP_WORD)
	local player = any(t, { "lfg", "lf group", "lf grp", "lf party", "looking for group", "looking for a group" })
		or seekGroup or (has(t, "sucht") and any(t, GROUP_WORD))
	local group = not player and (any(t, { "lfm", "lf more", "looking for more", "need", "needs" }) or n ~= nil
		or lfRole or lfClass or t:find("%d%s*/%s*%d") ~= nil or seek)
	if not group and not player then return nil end
	local strong = player or any(t, { "lfm", "lf more", "looking for more" }) or n ~= nil or lfRole or lfClass or seek
	-- "can summon" in a group post is fine; on its own it's a service ad
	if any(t, SERVICE) and not strong then return nil end
	if A.load then A.load() end
	local p = { kind = group and "group" or "player", acts = findActs(t, shown), need = roles(t, shown), text = shown }
	-- "need help" is noise; "need a tank for BRD" or "LF2M Hogger" is a group
	if #p.acts == 0 and p.need == 0 and not strong then return nil end
	if group then
		local have, of = t:match("(%d+)%s*/%s*(%d+)")
		have, of = tonumber(have), tonumber(of)
		if not (have and (of == 5 or of == 10 or of == 20 or of == 40) and have >= 1 and have < of) then have = nil end
		p.size = have or (n and 5 - n) or 2
		p.sizeGuess = not have and not n
	else
		p.size = 1
	end
	-- levels: "48-52", "lvl 50+", "50+"
	local lo, hi = t:match("%f[%d](%d%d)%s*%-%s*(%d%d)%f[^%d]")
	if lo then p.min, p.max = tonumber(lo), tonumber(hi)
	else
		lo = t:match("%f[%d](%d%d)%+") or t:match("lvl%s*(%d%d)%f[^%d]") or t:match("level%s*(%d%d)%f[^%d]")
		if lo then p.min, p.max = tonumber(lo), 60 end
	end
	if p.min and (p.min < 1 or p.min > 60 or (p.max or 60) < p.min) then p.min, p.max = nil, nil end
	return p
end

local CHANNELS = { "^lookingforgroup", "^lfg", "^trade", "^general", "^world" }
local function wanted(chan)
	chan = chan:gsub("^%d+%.%s*", ""):lower()
	for _, pat in ipairs(CHANNELS) do if chan:find(pat) then return true end end
	return false
end

-- "/og chatlog on": the last 300 lines from LookingForGroup and Trade, with what the parser made of
-- them, kept in SavedVariables for tuning (no names). Off unless turned on.
function N.logChat(chan, text, p)
	local c = type(OpenGroupDB) == "table" and OpenGroupDB.chatlog
	if type(c) ~= "table" or not c.on then return end
	local low = chan:lower()
	if not (low:find("lookingforgroup", 1, true) or low:find("lfg", 1, true) or low:find("trade", 1, true)) then return end
	c.lines = type(c.lines) == "table" and c.lines or {}
	local got = ""
	if p then
		local r = (p.need % 2 >= 1 and "t" or "") .. (p.need % 4 >= 2 and "h" or "") .. (p.need % 8 >= 4 and "d" or "")
		got = ("%s %s %s %s"):format(p.kind == "group" and "g" or "p", p.acts[1] and (A.name(p.acts[1]) or "?") or "-", r ~= "" and r or "-", tostring(p.size))
	end
	c.lines[#c.lines + 1] = { at = time(), chan = (chan:gsub("^%d+%.%s*", "")), text = text:sub(1, 255), got = got }
	while #c.lines > 300 do table.remove(c.lines, 1) end
end

function N.onChat(text, author, chanName, baseName, guid)
	if not enabled() then return end
	text, author = str(text), str(author)
	if not text or not author or author == "" or L.isMe(author) then return end
	local chan = str(baseName) or str(chanName) or ""
	if chan == "" or not wanted(chan) then return end
	local p = N.parse(text)
	N.logChat(chan, text, p)
	local class
	if str(guid) and GetPlayerInfoByGUID then
		local ok, _, cls = pcall(GetPlayerInfoByGUID, guid)
		if ok then class = str(cls) end
	end
	-- World chat: our number's useful LFG and Trade lines
	pcall(N.captureFeed, chan, author, text, class)
	if not p then return end
	local matched = #p.acts > 0
	put({
		leader = author, src = "chat", chan = (chan:gsub("^%d+%.%s*", ""):gsub("%s*%d+$", "")),
		class = class, size = p.size, sizeGuess = p.sizeGuess, need = p.need, acts = p.acts, lmin = p.min, lmax = p.max,
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
N.onEvent = function(_, ev, ...)
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
			local gp = N.game and (N.game.pending and N.game.pending.at or N.game.refused)
			if N.blocked:find("Listing") or (gp and t - gp <= 3) then
				-- our listing in the game's Group Finder: N.onGameEvent says so
			elseif N.blocked:find("SendWho") or (whoRecent and (not searchRecent or S.whoAt >= N.searchAt)) then
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
end
f:SetScript("OnEvent", N.onEvent)

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
		-- 0.6.3 and later get LFG chat in World chat (T1); older versions the old way
		if n > 0 and n ~= mine and (P.versionNumber(p.v) or 0) < 603 then chatTo[#chatTo + 1] = name end
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
	if what:find("t", 1, true) and p.shard == L.shard() and N.tradeClaims then N.tradeClaims[L.short(sender)] = clock() end
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

-- --------------------------------------------------------------------------------------------
-- Listing in the game's own Group Finder too, so players without OpenGroup see it (on your server
-- shard only; that's as far as the game's list reaches). Same calls as the game's Post button
-- (Blizzard_LFGVanilla_Listing.lua, CreateOrUpdateListing): activities and the new-player flag,
-- no text; roles saved separately. The game wants a click for these, so they're only called
-- from OpenGroup's List / Update / Leave clicks, directly and once per click (nothing else
-- restricted in the same click). Solo players and group leaders only.
-- Saved: OpenGroupDB.gameList (nil = on).
N.game = { pending = nil, listed = false, refused = nil }
function N.gameListOn() return not (type(OpenGroupDB) == "table" and OpenGroupDB.gameList == false) end
function N.canGameList()
	if not (C_LFGList and C_LFGList.CreateListing) then return false end
	if (GetNumGroupMembers and GetNumGroupMembers() or 0) > 1 and UnitIsGroupLeader and not UnitIsGroupLeader("player") then return false end
	return true
end
-- the activities the game knows, from a listing's (at most 3, like the game's own picker allows)
function N.gameActs(acts)
	local out = {}
	for _, id in ipairs(acts or {}) do
		if type(id) == "number" and id > 0 and C_LFGList.GetActivityInfoTable then
			local ok, t = pcall(C_LFGList.GetActivityInfoTable, id)
			if ok and type(t) == "table" and #out < 3 then out[#out + 1] = id end
		end
	end
	return out
end
-- from a click: create or update the game's listing for these activities. need = our role bits
-- (solo: the roles you play). Returns true when the call was made.
function N.gameList(acts, need, solo)
	if not N.gameListOn() or not N.canGameList() then return false end
	local ids = N.gameActs(acts)
	if #ids == 0 then return false end
	-- solo: the game lists you with the roles saved in its window; set them only when they differ
	if solo and C_LFGListRoles and C_LFGListRoles.SetRoles then
		local want = { tank = (need or 0) % 2 >= 1, healer = (need or 0) % 4 >= 2, dps = (need or 0) % 8 >= 4 }
		local ok, have = false, nil
		if C_LFGListRoles.GetRoles then ok, have = pcall(C_LFGListRoles.GetRoles) end
		local same = ok and type(have) == "table" and (not have.tank) == (not want.tank) and (not have.healer) == (not want.healer) and (not have.dps) == (not want.dps)
		if not same then pcall(C_LFGListRoles.SetRoles, want) end
	end
	local update = false
	if C_LFGList.HasActiveEntryInfo then
		local ok, v = pcall(C_LFGList.HasActiveEntryInfo)
		update = ok and v == true
	end
	N.game.pending, N.game.refused, N.game.ours = { at = GetTime(), update = update }, nil, true
	if update then
		C_LFGList.UpdateListing({ activityIDs = ids, newPlayerFriendly = false })
	else
		C_LFGList.CreateListing({ activityIDs = ids, newPlayerFriendly = false })
	end
	return true
end
-- from a click (Leave / Delist): take the game's listing down, if there is one
function N.gameUnlist()
	-- only a listing OpenGroup made: one the player made in the game's window is theirs to remove
	if not N.game.ours or not (C_LFGList and C_LFGList.RemoveListing) or not N.canGameList() then return false end
	local has = false
	if C_LFGList.HasActiveEntryInfo then
		local ok, v = pcall(C_LFGList.HasActiveEntryInfo)
		has = ok and v == true
	end
	if not has then return false end
	N.game.pending, N.game.ours = { at = GetTime(), remove = true }, nil
	C_LFGList.RemoveListing()
	return true
end
-- what the game said: listed, taken down, or refused (the addon isn't allowed to)
function N.onGameEvent(ev, addon)
	local p = N.game.pending
	if ev == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
		local has = false
		if C_LFGList.HasActiveEntryInfo then local ok, v = pcall(C_LFGList.HasActiveEntryInfo) has = ok and v == true end
		local was = N.game.listed
		N.game.listed = has
		if p and GetTime() - p.at < 10 then
			N.game.pending = nil
			if has and not p.remove then L.print(p.update and "your listing in the game's Group Finder is updated." or "also listed in the game's Group Finder (players without OpenGroup on your server see it).")
			elseif not has and p.remove then L.print("taken off the game's Group Finder.") end
		end
		if was ~= has then changed() end
	elseif (ev == "ADDON_ACTION_BLOCKED" or ev == "ADDON_ACTION_FORBIDDEN") and addon == "OpenGroup" and p and GetTime() - p.at < 3 then
		N.game.pending = nil
		N.game.refused = GetTime()
		L.print("the game refused OpenGroup's listing in its Group Finder. Your OpenGroup listing is out anyway; to be in the game's list too, use its Group Finder window.")
		changed()
	end
end
if CreateFrame then
	local gfEv = CreateFrame("Frame")
	for _, ev in ipairs({ "LFG_LIST_ACTIVE_ENTRY_UPDATE", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do pcall(gfEv.RegisterEvent, gfEv, ev) end
	gfEv:SetScript("OnEvent", function(_, ev, a1) pcall(N.onGameEvent, ev, a1) end)
end

-- --------------------------------------------------------------------------------------------
-- World chat: the useful LookingForGroup and Trade lines of every chat number, in one feed.
--
-- Collecting: each chat number has a reporter for its LookingForGroup lines (the LFG chat
-- election) and one for its Trade lines (only players actually in Trade, i.e. in a city, stand).
-- Every 20 seconds the reporter sends its new lines: trade ads, crafters and group posts only (no
-- chatter, gold sellers, boosts or websites), links as IDs, the same author and text at most once
-- per 10 minutes, many lines to a batch, compressed (Proto.lua, P.feedPack).
--
-- Passing on: every OpenGroup user who takes World chat, whatever their chat number, is in one
-- relay tree, in name order: users 1 and 2 are the roots and user i passes on to users 2i+1 and
-- 2i+2. Reporters send their lines (on the same 20-second beat everywhere) to the two roots. What
-- arrives is kept, and the lines new to us are merged, from every chat number, into one
-- compressed batch that goes on to our two children 3 seconds later. So passing on costs the
-- same however many chat numbers there are: about one batch to each of two players per round.
-- Everyone keeps to a World chat budget of about 24 messages a minute (OpenGroup's whole send
-- rate is about one a second), so listings and answers are never held up; past it, the oldest
-- Trade lines are left out. Trade lines reach players on the reporter's own number too, so
-- players out in the world, not in Trade, see their city's Trade.
--
-- Keeping: lines are kept for 3 hours (at most 3000), saved between sessions, searchable by text
-- and item name. On login, and when the World chat tab opens, one OpenGroup user is asked for the
-- last hour (B1), so the history fills in even right after logging in.
-- Older versions keep getting LFG chat the old way (C1) and ignore T1 and B1.

N.feed = {}               -- { key, chan, kind, leader, text, got, relay, mine, class }
N.tradeClaims = {}        -- [name] = time: a player in Trade on our number said they pass it on
N.stats.feedOut, N.stats.feedIn, N.stats.feedFwd, N.stats.feedDropped, N.stats.backlogs = 0, 0, 0, 0, 0
local FEED_EVERY, FEED_KEEP, FEED_MAX, FEED_REPEAT = 20, 3 * 3600, 3000, 600
local FEED_SEND_MAX = 8            -- messages a reporter sends per round
local FEED_RATE, FEED_BURST = 0.4, 12
local BACKLOG_SPAN, BACKLOG_LINES, BACKLOG_PARTS = 3600, 150, 8
local feedTokens, feedTokensAt = FEED_BURST, nil
local feedPending = {}             -- lines on our number not sent yet
local feedSentKeys = {}            -- [key] = time sent (repeats within 10 minutes aren't)
local feedSeen = {}                -- [origin:digest:part] = time (a message reaches us once)
local feedParts = {}               -- [origin:digest] = { parts, got = n, pieces = {}, at }
local feedIndex = {}               -- [key] = line
local feedClaimAt, backlogAskedAt, backlogAnsweredAt = -1000, -1000, -1000

function N.shareTrade() return not (type(OpenGroupDB) == "table" and OpenGroupDB.shareTrade == false) end
-- in a city, i.e. in Trade: Trade is the one channel you only have there
function N.inTrade()
	local list = { GetChannelList() }
	for i = 1, #list, 3 do
		local name = list[i + 1]
		if type(name) == "string" and name:gsub("^%d+%.%s*", ""):lower():find("^trade") then return true end
	end
	return false
end

-- the history: saved in OpenGroupDB.feedHist, 3 hours, 3000 lines
local function bindHistory()
	if N.feedBound or type(OpenGroupDB) ~= "table" then return end
	N.feedBound = true
	local saved = type(OpenGroupDB.feedHist) == "table" and OpenGroupDB.feedHist or {}
	local t, keep = clock(), {}
	for _, e in ipairs(saved) do
		if type(e) == "table" and type(e.key) == "string" and type(e.got) == "number" and t - e.got < FEED_KEEP then keep[#keep + 1] = e end
	end
	for _, e in ipairs(N.feed) do keep[#keep + 1] = e end
	N.feed, feedIndex = {}, {}
	for _, e in ipairs(keep) do
		local x = feedIndex[e.key]
		if x then if e.got > x.got then x.got = e.got end else N.feed[#N.feed + 1] = e feedIndex[e.key] = e end
	end
	while #N.feed > FEED_MAX do feedIndex[table.remove(N.feed, 1).key] = nil end
	OpenGroupDB.feedHist = N.feed
end
N.bindHistory = bindHistory

-- the World chat budget: true if a message may go out now
function N.feedSpend(n)
	local t = clock()
	feedTokens = math.min(FEED_BURST, feedTokens + (t - (feedTokensAt or t)) * FEED_RATE)
	feedTokensAt = t
	if feedTokens < (n or 1) then return false end
	feedTokens = feedTokens - (n or 1)
	return true
end
function N.feedTokensReset() feedTokens, feedTokensAt = FEED_BURST, nil end
function N.feedTokensLeft()
	local t = clock()
	feedTokens = math.min(FEED_BURST, feedTokens + (t - (feedTokensAt or t)) * FEED_RATE)
	feedTokensAt = t
	return feedTokens
end

-- links -> {i<item>[:enchant:suffix]}, {e<enchant>}, {s<spell>}; colours and textures dropped
function N.packLinks(text)
	text = text:gsub("|c%x%x%x%x%x%x%x%x(|H.-|h.-|h)|r", "%1")
	text = text:gsub("|Hitem:([%-%d:]+)|h%[.-%]|h", function(payload)
		local f = {}
		for v in (payload .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
		local id, ench, suffix = tonumber(f[1]), tonumber(f[2]) or 0, tonumber(f[7]) or 0
		if not id then return "" end
		if ench ~= 0 or suffix ~= 0 then return ("{i%d:%d:%d}"):format(id, ench, suffix) end
		return ("{i%d}"):format(id)
	end)
	text = text:gsub("|Henchant:(%d+)|h%[.-%]|h", "{e%1}")
	text = text:gsub("|Hspell:(%d+)[^|]*|h%[.-%]|h", "{s%1}")
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
	return text
end
-- back to real links, as far as the game knows them yet (unknown items are asked for)
local function spellName(id) local n = GetSpellInfo and GetSpellInfo(id) return n end
function N.unpackLinks(text)
	text = text:gsub("{i(%d+):?(%-?%d*):?(%-?%d*)}", function(id, ench, suffix)
		id = tonumber(id)
		local str = ("item:%d:%s:0:0:0:0:%s"):format(id, ench ~= "" and ench or "0", suffix ~= "" and suffix or "0")
		local link = GetItemInfo and select(2, GetItemInfo(str))
		if not link and GetItemInfo then link = select(2, GetItemInfo(id)) end
		if link then return link end
		if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
		return "[item " .. id .. "]"
	end)
	text = text:gsub("{e(%d+)}", function(id)
		local n = spellName(tonumber(id))
		return n and ("|cffffd000|Henchant:" .. id .. "|h[" .. n .. "]|h|r") or ("[enchant " .. id .. "]")
	end)
	text = text:gsub("{s(%d+)}", function(id)
		local n = spellName(tonumber(id))
		return n and ("|cff71d5ff|Hspell:" .. id .. "|h[" .. n .. "]|h|r") or ("[spell " .. id .. "]")
	end)
	return text
end
function N.firstItem(text) return tonumber((text or ""):match("{i(%d+)")) end
-- what search looks at: the line with its links' names, lower case
function N.searchText(e)
	local t = N.unpackLinks(e.text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
	return (e.leader .. " " .. t):lower()
end

-- worth passing on? Trade ads, crafters, group posts. Pure, for tests.
local FEED_SPAM = { "www", "http", "%.com", "%.net", "%.org", "discord", "cheap gold", "gold for", "%d+k gold",
	"boost", "boosts", "boosting", "carry", "carries", "%$" }
local FEED_SELL = { "wts", "wtb", "wtt", "lfw", "selling", "buying", "crafting", "crafter", "enchanter", "enchanting",
	"enchants", "your mats", "tips", "alchemist", "blacksmith", "leatherworker", "tailor", "engineer", "transmute" }
function N.feedKeep(text)
	if type(text) ~= "string" or #text < 3 then return false end
	local t = " " .. N.packLinks(text):lower() .. " "
	for _, pat in ipairs(FEED_SPAM) do if t:find(pat) then return false end end
	for _, w in ipairs(FEED_SELL) do if t:find("%f[%w]" .. w .. "%f[^%w]") then return true end end
	return N.parse(text) ~= nil
end

local function feedKey(leader, text) return L.short(leader) .. "\31" .. text end
local function addLine(e)
	bindHistory()
	local x = feedIndex[e.key]
	if x then
		if e.got > x.got then x.got = e.got end
		x.relay = x.relay or e.relay
		return x, false
	end
	N.feed[#N.feed + 1] = e
	feedIndex[e.key] = e
	while #N.feed > FEED_MAX do feedIndex[table.remove(N.feed, 1).key] = nil end
	-- ask for the items now, so their names are there to search by
	for id in e.text:gmatch("{i(%d+)") do
		if GetItemInfo and not GetItemInfo(tonumber(id)) and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, tonumber(id)) end
	end
	return e, true
end
N.addFeedLine = addLine
function N.hasLine(key) return feedIndex[key] ~= nil end
function N.resetFeedIndex() feedIndex = {} for _, e in ipairs(N.feed) do feedIndex[e.key] = e end end

-- a line from our own LookingForGroup / Trade (called from N.onChat)
function N.captureFeed(chan, author, text, class)
	local low = chan:lower()
	local kind = low:find("trade", 1, true) and "t" or (low:find("lookingforgroup", 1, true) or low:find("^lfg")) and "l" or nil
	if not kind or not N.feedKeep(text) then return false end
	local packed = N.packLinks(text):gsub("[ \t\r\n]+", " ")
	local e = { key = feedKey(author, packed), chan = L.shard(), kind = kind, leader = L.short(author), text = packed,
		got = clock(), class = class, mine = true }
	e = addLine(e)
	local k = e.key
	if not (feedSentKeys[k] and clock() - feedSentKeys[k] < FEED_REPEAT) then
		for _, x in ipairs(feedPending) do if x.key == k then return true end end
		feedPending[#feedPending + 1] = e
		while #feedPending > 60 do table.remove(feedPending, 1) end
	end
	return true
end

-- OpenGroup users on chat number n who take World chat (0.6.3 on), in name order, without `skip`
local function feedPeers(n, skip)
	local out = {}
	for name, p in pairs(L.live()) do
		if p.shard == n and (P.versionNumber(p.v) or 0) >= 603 and name ~= skip then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end
N.feedPeers = feedPeers

-- The relay tree, built from names, so players who don't all know each other still agree well
-- enough: every copy of a batch carries the range of names it's for (strictly between lo and hi).
-- Whoever gets it keeps it, and splits the OpenGroup users it knows in that range (itself left
-- out) into two halves by name: the first of each half gets the batch, with that half's range.
-- Players nobody above knew are the only ones it misses (and the backlog fills those in later).
-- Everyone sends their reports to the root, the OpenGroup user whose name sorts first.
function N.feedKnown()
	local out = {}
	for name, p in pairs(L.live()) do
		if (P.versionNumber(p.v) or 0) >= 603 then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end
-- the (at most two) children for a range, each with its own range
function N.feedChildren(lo, hi)
	local me = L.me() and L.short(L.me())
	local s = {}
	for _, n in ipairs(N.feedKnown()) do
		if (not lo or n > lo) and (not hi or n < hi) and n ~= me then s[#s + 1] = n end
	end
	if #s == 0 then return {} end
	local half = math.ceil(#s / 2)
	local a, b = s[1], s[half + 1]
	-- each child's range starts at its own name, so nobody gets a copy meant for those above it
	local out = { { name = a, lo = a, hi = b or hi } }
	if b then out[2] = { name = b, lo = b, hi = hi } end
	return out
end

-- What we pass on this round: lines new to us, merged from everything that arrived (any chat
-- number), sent as one compressed batch a few seconds after the first of them, so passing on
-- costs the same however many chat numbers there are.
local outbox, outboxKeys, flushAt = {}, {}, nil
local outLo, outHi, outOpen = nil, nil, false   -- the range we pass this round's lines on for
-- lines we've passed down the tree (or put in): a line we already had, e.g. from our own Trade,
-- still goes on to our children the first time it comes down the tree
local passedOn = {}
local FLUSH_AFTER = 2
-- widen this round's range to take in (lo, hi); nil = open
local function widen(lo, hi)
	if outOpen then return end
	if outLo == nil and outHi == nil then outLo, outHi = lo or false, hi or false
	else
		if outLo ~= false then if not lo then outLo = false elseif lo < outLo then outLo = lo end end
		if outHi ~= false then if not hi then outHi = false elseif hi > outHi then outHi = hi end end
	end
	if outLo == false and outHi == false then outOpen = true end
end
local function queueOut(items)
	for _, it in ipairs(items) do
		local k = feedKey(it.leader, it.text)
		if not outboxKeys[k] and not passedOn[k] then outboxKeys[k] = true passedOn[k] = clock() outbox[#outbox + 1] = it end
	end
	if #outbox == 0 then outLo, outHi, outOpen = nil, nil, false end
	if #outbox > 0 and not flushAt then
		flushAt = clock() + FLUSH_AFTER
		if C_Timer and C_Timer.After then C_Timer.After(FLUSH_AFTER, function() pcall(N.feedFlush) end) end
	end
end
N.queueOut = queueOut

-- pack lines for these players within what the budget has left: the oldest Trade lines go first
local function packFor(items, nTargets, digest)
	local me = L.me() or "?"
	local keep = {}
	for _, it in ipairs(items) do keep[#keep + 1] = it end
	-- LFG before Trade, newest first within each
	table.sort(keep, function(a, b) if a.kind ~= b.kind then return a.kind == "l" end return a.age < b.age end)
	local msgs = P.feedPack(me, L.shard(), digest, keep)
	local room = math.floor(N.feedTokensLeft())
	while #keep > 0 and #msgs * nTargets > room do
		local drop = math.max(1, math.floor(#keep * 0.2))
		for _ = 1, drop do table.remove(keep) N.stats.feedDropped = N.stats.feedDropped + 1 end
		msgs = #keep > 0 and P.feedPack(me, L.shard(), digest, keep) or {}
	end
	return msgs, keep
end

function N.feedFlush()
	flushAt = nil
	if #outbox == 0 then return 0 end
	local items, t = outbox, clock()
	local lo, hi = outLo or nil, outHi or nil
	if outOpen then lo, hi = nil, nil end
	outbox, outboxKeys, outLo, outHi, outOpen = {}, {}, nil, nil, false
	local kids = N.feedChildren(lo, hi)
	-- a whole-tree batch, but we know someone whose name sorts before ours: it's the root, not us
	if not lo and not hi then
		local known = N.feedKnown()
		local me = L.me() and L.short(L.me())
		if known[1] and me and known[1] < me then kids = { { name = known[1] } } end
	end
	if #kids == 0 then return 0 end
	for _, it in ipairs(items) do it.age = math.max(0, t - (it.got or t)) end
	local sent = 0
	local digest = math.random(1, 2^30)
	local msgsFor = {}
	-- what fits the budget for both children
	local _, keep = packFor(items, #kids, digest)
	for _, k in ipairs(kids) do
		local msgs = P.feedPack(L.me() or "?", L.shard(), digest, keep, k.lo, k.hi)
		for _, m in ipairs(msgs) do
			if N.feedSpend() then L.send(k.name, m, true) sent = sent + 1 N.stats.feedFwd = N.stats.feedFwd + 1 end
		end
	end
	return sent
end

-- every 20 seconds (on the same beat for everyone): our number's new lines into the tree, if we report
function N.feedReport()
	if not enabled() or not L.shard or L.shard() <= 0 or #feedPending == 0 then return false end
	local mine, me, t = L.shard(), L.me() or "", clock()
	local doLFG = N.shareChat() and N.shouldReport(me, N.chatClaims, t, true)
	local doTrade = N.shareTrade() and N.inTrade() and N.shouldReport(me, N.tradeClaims, t, true)
	local items = {}
	local nl, nt = 0, 0
	for i = #feedPending, 1, -1 do
		local e = feedPending[i]
		if (e.kind == "l" and doLFG) or (e.kind == "t" and doTrade) then
			if #items < 60 then
				items[#items + 1] = { leader = e.leader, age = math.max(0, t - e.got), got = e.got, kind = e.kind, chan = mine, text = e.text, key = e.key }
				if e.kind == "l" then nl = nl + 1 else nt = nt + 1 end
			end
		end
	end
	feedPending = {}
	if #items == 0 then return false end
	for _, it in ipairs(items) do feedSentKeys[it.key] = t end
	N.stats.feedOut = N.stats.feedOut + #items
	-- the others on our number stand by
	local home = feedPeers(mine, me)
	if t - feedClaimAt > 60 then
		feedClaimAt = t
		local what = (nl > 0 and "c" or "") .. (nt > 0 and "t" or "")
		for i = 1, math.min(10, #home) do L.send(home[i], P.reporting(#items, what), true) end
	end
	-- into the tree: to the root (the name that sorts first). Our own lines come back down to us
	-- like everyone else's and go on merged with the rest; if we are the root, they start here
	local known = N.feedKnown()
	local me = L.short(me)
	local root = known[1]
	if not root or me < root then widen(nil, nil) queueOut(items) return true end
	local msgs = select(1, packFor(items, 1, math.random(1, 2^30)))
	local sent = 0
	for _, m in ipairs(msgs) do if N.feedSpend() then L.send(root, m, true) sent = sent + 1 end end
	return sent > 0
end

-- lines arriving (relayed, or a backlog): kept, deduplicated, ignored players left out; returns
-- the ones that were new to us
local function takeLines(items, relay, now)
	local mine = L.shard()
	local fresh = {}
	for _, it in ipairs(items) do
		if not L.isMe(it.leader) and not (L.ignored and L.ignored(it.leader)) then
			local _, isNew = addLine({ key = feedKey(it.leader, it.text), chan = it.chan, kind = it.kind, leader = it.leader, text = it.text,
				got = now - it.age, relay = relay, mine = (it.chan == mine) or nil })
			fresh[#fresh + 1] = { leader = it.leader, age = it.age, got = now - it.age, kind = it.kind, chan = it.chan, text = it.text, new = isNew }
			-- group posts from another number's LookingForGroup still show in Browse
			if isNew and it.kind == "l" and it.chan ~= mine and it.age < 600 and not L.listings[it.leader] and not L.nearby[it.leader] then
				local p = N.parse(N.unpackLinks(it.text))
				if p then
					L.remote[it.leader] = {
						leader = it.leader, src = "remotechat", shard = it.chan, reporter = relay, chan = "LFG",
						size = p.size, sizeGuess = p.sizeGuess, need = p.need, acts = p.acts, cat = catOf(p.acts),
						level = 0, got = now - it.age, seq = 0, hops = 0, price = 0, quest = 0,
						title = #p.acts > 0 and "" or it.text:sub(1, 70), note = #p.acts > 0 and it.text:sub(1, 120) or "",
						lmin = p.min, lmax = p.max,
					}
				end
			end
		end
	end
	local n = 0
	for _, f in ipairs(fresh) do if f.new then n = n + 1 end end
	N.stats.feedIn = N.stats.feedIn + n
	return fresh, n
end

-- a World chat message: once all its parts are in, keep its lines and pass the new ones on
L.onFeed = function(sender, d, msg)
	local t = clock()
	local id = d.origin .. ":" .. d.digest .. ":" .. d.part
	if feedSeen[id] or L.isMe(d.origin) then return end
	feedSeen[id] = t
	local relay = L.short(sender)
	local key = d.origin .. ":" .. d.digest
	local a = feedParts[key]
	if not a then a = { parts = d.parts, got = 0, pieces = {}, at = t } feedParts[key] = a end
	if a.pieces[d.part] or d.parts ~= a.parts then return end
	a.pieces[d.part], a.got = d.piece, a.got + 1
	if a.got < a.parts then return end
	feedParts[key] = nil
	local items = P.feedUnpack(table.concat(a.pieces))
	if not items then N.stats.feedBad = (N.stats.feedBad or 0) + 1 return end
	local lines, nNew = takeLines(items, relay, t)
	-- a backlog (sent past the hop limit) is ours alone; anything else goes down the tree
	if d.hop < P.FEED_HOPS and #lines > 0 then widen(d.lo, d.hi) queueOut(lines) end
	if nNew > 0 then changed() end
end

-- the last hour, for someone who just logged in (B1), at most once every 2 minutes
L.onBacklogAsk = function(sender, d)
	local t = clock()
	if t - backlogAnsweredAt < 120 then return end
	bindHistory()
	local items = {}
	for i = #N.feed, 1, -1 do
		local e = N.feed[i]
		if t - e.got < BACKLOG_SPAN and #items < math.min(d.max or BACKLOG_LINES, BACKLOG_LINES) then
			items[#items + 1] = { leader = e.leader, age = t - e.got, kind = e.kind, chan = e.chan, text = e.text }
		end
	end
	if #items == 0 then return end
	local msgs = P.feedPack(L.me() or "?", 0, math.random(1, 2^30), items)
	while #msgs > BACKLOG_PARTS and #items > 1 do
		for _ = 1, math.max(1, math.floor(#items * 0.3)) do table.remove(items) end
		msgs = P.feedPack(L.me() or "?", 0, math.random(1, 2^30), items)
	end
	backlogAnsweredAt = t
	-- one hop past the limit: a backlog isn't passed on
	for _, m in ipairs(msgs) do L.send(sender, P.feedHop(m, P.FEED_HOPS) or m, true) end
	N.stats.backlogs = N.stats.backlogs + 1
end
-- ask one OpenGroup user (0.6.3 on) for the last hour; at most every 10 minutes
function N.askBacklog()
	local t = clock()
	if t - backlogAskedAt < 600 then return false end
	local best, bestSeen
	for name, p in pairs(L.live()) do
		if (P.versionNumber(p.v) or 0) >= 603 and (p.seen or 0) > (bestSeen or 0) then best, bestSeen = name, p.seen end
	end
	if not best then return false end
	backlogAskedAt = t
	L.send(best, P.backlogAsk(BACKLOG_LINES), true)
	return true
end

function N.expireFeed()
	bindHistory()
	local t = clock()
	local keep = {}
	for _, e in ipairs(N.feed) do if t - e.got < FEED_KEEP then keep[#keep + 1] = e else feedIndex[e.key] = nil end end
	if #keep ~= #N.feed then
		for i = #N.feed, 1, -1 do N.feed[i] = nil end
		for i, e in ipairs(keep) do N.feed[i] = e end
		changed()
	end
	for k, at in pairs(feedSentKeys) do if t - at > FEED_REPEAT then feedSentKeys[k] = nil end end
	for k, at in pairs(feedSeen) do if t - at > 3600 then feedSeen[k] = nil end end
	for k, at in pairs(passedOn) do if t - at > 3600 then passedOn[k] = nil end end
	for k, a in pairs(feedParts) do if t - a.at > 120 then feedParts[k] = nil end end
	for name, at in pairs(N.tradeClaims) do if t - at > 150 then N.tradeClaims[name] = nil end end
end
if C_Timer and C_Timer.NewTicker then
	local lastRound
	C_Timer.NewTicker(1, function()
		local r = math.floor(clock() / FEED_EVERY)
		if r ~= lastRound then lastRound = r pcall(N.feedReport) end
	end)
	C_Timer.NewTicker(30, function() pcall(N.expireFeed) end)
	-- a minute after login, fill in the last hour
	if C_Timer.After then C_Timer.After(60, function() pcall(N.askBacklog) end) end
end
if CreateFrame then
	local ff = CreateFrame("Frame")
	pcall(ff.RegisterEvent, ff, "GET_ITEM_INFO_RECEIVED")
	ff:SetScript("OnEvent", function() N.feedEpoch = (N.feedEpoch or 0) + 1 end)
end
