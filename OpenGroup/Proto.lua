-- OpenGroup message format. Pure functions only (no WoW API), so tools/test.py can run them.
--
-- Every message is one addon whisper under the prefix "OpenGroup", fields split by ";".
--   H1;<shard>;<level>;<version>      hello: "do you run OpenGroup?" (version added in 0.6; older
--                                     clients send three fields and ignore a fourth)
--   A1;<shard>;<level>;<version>      answer to a hello
--   X1;<name>:<shard>,<name>:<shard>  peer exchange: OpenGroup players the sender has heard from
--                                     recently, so a new user's network grows from one contact
--   P1;<token>                        ping (the cross-shard test button)
--   Q1;<token>;<shard>                pong
--   L1;<leader>;<seq>;<shard>;<level>;<size>;<age>;<hops>;<class>;<need>;<cat>;<acts>;<price>;<quest>;<title>;<note>
--                                     a listing; age = seconds since the leader sent it, hops = times relayed,
--                                     class = leader's class file name (WARRIOR), need = roles
--                                     wanted as bits (1 tank, 2 healer, 4 damage); for a solo
--                                     player (size 1) the roles they can play. cat = Group Finder
--                                     category id, acts = activity ids "12,34" (the game's ids, so
--                                     each client shows the names in its own language). title is
--                                     free text (Custom), may be empty when acts is not.
--                                     price = copper asked (warlock summons, cat P.SUMMON_CAT);
--                                     for a summon the title is the destination. quest = quest id
--                                     when listing for one quest (title then holds its name).
--                                     cat 90002 / 90003 = battleground queue offer / request
--                                     (acts = the battlegrounds), see P.BGQ_OFFER.
--      ...;<note>;<spots>             added in 0.6: the group's open spots, one per spot, split by
--                                     ",": <role>/<class>/<min>/<max>, role = A (any), T, H or D,
--                                     class = class file name or blank (any), min/max = level or
--                                     blank. "T/WARRIOR//,D/HUNTER/52/54,A///". need still carries
--                                     the roles, so older clients (which stop at <note>) see those.
--   U1;<leader>;<seq>                 the leader delisted
--   J1;<class>;<level>;<need>         "please invite me" (sent with Ask to Join), so a leader's auto
--                                     invite knows the asker's class, level and roles (need bits)
--   I1;<title>                        "my auto invite just invited you, for <title>"
--   G1;<the L1 fields>                to PARTY/RAID: the leader's listing, so the party's OpenGroup shows it
--   G0;<seq>                          to PARTY/RAID: the leader unlisted the group
--   GQ                                to PARTY/RAID: "what is our group listed for?" (after a reload)
--   F1;<shard>;<digest>;<part>;<parts>;<items>
--                                     the game's Group Finder groups on the sender's shard, for OpenGroup
--                                     players on other shards: items split by ",", each
--                                     <leader>/<activity>/<size>/<need>/<age>. A digest (numbered) may
--                                     take several parts; groups missing from a reporter's latest
--                                     complete digest are gone. These leaders don't run OpenGroup.
--   C1;<shard>;<digest>;<part>;<parts>;<items>
--                                     the sender's shard's recent LookingForGroup chat posts, for other
--                                     shards: items split by "~", each <name>^<age>^<activity>^<need>^<size>^<text>
--                                     (text cut to 100 characters, without "~" or "^")
--   R1;<groups>                       to OpenGroup players on the same shard: "I'm reporting this
--                                     shard's Group Finder" (one reporter per shard at a time)
-- Fields never contain ";" or "|" (stripped on the way in and out). A message stays under 250 bytes.
--
-- Keeping versions compatible (anyone can run their own client, and players update at different
-- times), so a change to this format must follow these rules:
--   * Never change what an existing field means or where it sits. Add new fields only at the end
--     of a message (like L1's <spots>); older clients read the fields they know and ignore the rest.
--   * A new kind of message gets a new type ("G1", "J1" ...). Clients ignore types they don't know.
--   * Bump the number in a type ("L1" -> "L2") only for a change older clients can't read safely,
--     and keep reading the old one for at least a release.
--   * Everything from another player is untrusted: numbers are range-checked, text is cleaned and
--     cut to length, and anything malformed is dropped (P.parse never errors).
--   * The hello carries the sender's version (P.VERSION), so /og status can show who runs what.

local P = {}
OpenGroup_Proto = P

P.PREFIX = "OpenGroup"
P.MAX_HOPS = 2          -- leader -> peer -> peer: three shards' worth of reach per announce
P.MAX_LEN = 250
P.TITLE_LEN = 40
P.NOTE_LEN = 60
P.NAME_LEN = 48
P.MAX_AGE = 300         -- a listing not refreshed for 5 minutes is gone

local function clean(s, len)
	if type(s) ~= "string" then return "" end
	s = s:gsub("[;|\r\n]", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if #s > len then s = s:sub(1, len) end
	return s
end
P.clean = clean

-- a whole number in [lo, hi], or nil (NaN, inf, text, out of range all fail)
local function int(v, lo, hi)
	local n = tonumber(v)
	if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
	n = math.floor(n)
	if n < lo or n > hi then return nil end
	return n
end
P.int = int

local function split(s)
	local out = {}
	for field in (s .. ";"):gmatch("([^;]*);") do out[#out + 1] = field end
	return out
end

P.VERSION = "0.6.2-test"
P.MAX_PX = 10           -- names per peer-exchange message

function P.hello(shard, level) return ("H1;%d;%d;%s"):format(shard or 0, level or 0, clean(P.VERSION, 16)) end
function P.answer(shard, level) return ("A1;%d;%d;%s"):format(shard or 0, level or 0, clean(P.VERSION, 16)) end

-- peers = { { name, shard }, ... }; names lose the characters the format uses
function P.peerList(peers)
	local msg = "X1;"
	local n = 0
	for _, e in ipairs(peers) do
		local name = clean(e[1], P.NAME_LEN):gsub("[:,]", "")
		local entry = ("%s%s:%d"):format(n > 0 and "," or "", name, int(e[2], 0, 99999) or 0)
		if name ~= "" and n < P.MAX_PX and #msg + #entry <= P.MAX_LEN then msg = msg .. entry n = n + 1 end
	end
	return n > 0 and msg or nil
end

-- "0.6.0-beta" -> 600; nil for anything else
function P.versionNumber(v)
	local a, b, c = tostring(v or ""):match("^(%d+)%.(%d+)%.(%d+)")
	if not a then return nil end
	return tonumber(a) * 10000 + tonumber(b) * 100 + tonumber(c)
end
function P.ping(token) return "P1;" .. clean(token, 16) end
function P.pong(token, shard) return ("Q1;%s;%d"):format(clean(token, 16), shard or 0) end
function P.unlist(leader, seq) return ("U1;%s;%d"):format(clean(leader, P.NAME_LEN), seq or 0) end
function P.join(class, level, need)
	return ("J1;%s;%d;%d"):format(clean(class or "", 12):upper():gsub("[^A-Z]", ""), int(level, 0, 200) or 0, int(need, 0, 7) or 0)
end
function P.invited(title) return "I1;" .. clean(title, P.TITLE_LEN) end
function P.groupListing(l) return "G1;" .. P.listing(l):sub(4) end
function P.groupUnlisted(seq) return ("G0;%d"):format(int(seq, 0, 2^31) or 0) end
function P.groupAsk() return "GQ" end

-- Group Finder digests: items = { { leader, act, size, need, age } }. Returns the messages, each
-- under the length limit, at most P.MAX_DIGEST groups in all.
P.MAX_DIGEST = 60
function P.finderDigest(shard, digest, items)
	local entries = {}
	for _, it in ipairs(items or {}) do
		if #entries >= P.MAX_DIGEST then break end
		local name = clean(it.leader, P.NAME_LEN):gsub("[,/]", "")
		local act = int(it.act, 0, 2^31) or 0
		if name ~= "" then
			entries[#entries + 1] = ("%s/%d/%d/%d/%d"):format(name, act, int(it.size, 1, 40) or 1, int(it.need, 0, 7) or 0, int(it.age, 0, 86400) or 0)
		end
	end
	local head = ("F1;%d;%d;"):format(int(shard, 0, 99999) or 0, int(digest, 0, 2^31) or 0)
	local parts, cur = {}, {}
	local room = P.MAX_LEN - #head - 8   -- the part numbers
	local len = 0
	for _, e in ipairs(entries) do
		if #cur > 0 and len + #e + 1 > room then parts[#parts + 1] = cur cur, len = {}, 0 end
		cur[#cur + 1] = e
		len = len + #e + 1
	end
	if #cur > 0 or #parts == 0 then parts[#parts + 1] = cur end
	local out = {}
	for i, p in ipairs(parts) do out[i] = head .. i .. ";" .. #parts .. ";" .. table.concat(p, ",") end
	return out
end
-- LFG chat digests: items = { { leader, age, act, need, size, text } }, at most P.MAX_CHAT
P.MAX_CHAT, P.CHAT_TEXT = 30, 100
local function chatClean(s, len) return (clean(s, len):gsub("[~%^]", " ")) end
function P.chatDigest(shard, digest, items)
	local entries = {}
	for _, it in ipairs(items or {}) do
		if #entries >= P.MAX_CHAT then break end
		local name = chatClean(it.leader, P.NAME_LEN)
		local text = chatClean(it.text, P.CHAT_TEXT)
		if name ~= "" and text ~= "" then
			entries[#entries + 1] = ("%s^%d^%d^%d^%d^%s"):format(name, int(it.age, 0, 86400) or 0, int(it.act, 0, 2^31) or 0,
				int(it.need, 0, 7) or 0, int(it.size, 1, 40) or 1, text)
		end
	end
	local head = ("C1;%d;%d;"):format(int(shard, 0, 99999) or 0, int(digest, 0, 2^31) or 0)
	local parts, cur, len = {}, {}, 0
	local room = P.MAX_LEN - #head - 8
	for _, e in ipairs(entries) do
		if #cur > 0 and len + #e + 1 > room then parts[#parts + 1] = cur cur, len = {}, 0 end
		cur[#cur + 1] = e
		len = len + #e + 1
	end
	if #cur > 0 or #parts == 0 then parts[#parts + 1] = cur end
	local out = {}
	for i, p in ipairs(parts) do out[i] = head .. i .. ";" .. #parts .. ";" .. table.concat(p, "~") end
	return out
end

function P.reporting(groups) return ("R1;%d"):format(int(groups, 0, 999) or 0) end

P.TANK, P.HEALER, P.DAMAGE = 1, 2, 4

P.MAX_ACTS = 8
P.SUMMON_CAT = 90001     -- not a Group Finder category: warlock summons
-- Battleground queues: in the classic battleground system a group leader at a battlemaster can
-- queue the whole group, wherever the members are. OFFER = "I'm at a battlemaster and can queue
-- you", WANT = "invite me and queue us". acts = the battlegrounds (the game's PvP activity ids).
P.BGQ_OFFER = 90002
P.BGQ_WANT = 90003
function P.isBGQ(cat) return cat == P.BGQ_OFFER or cat == P.BGQ_WANT end
P.MAX_PRICE = 100000000  -- 10,000 gold

-- open spots: { { role = 0 (any) | P.TANK | P.HEALER | P.DAMAGE, class = "HUNTER" | nil, min, max } }
P.MAX_SPOTS = 4
local ROLE_LETTER = { [0] = "A", [1] = "T", [2] = "H", [4] = "D" }
local LETTER_ROLE = { A = 0, T = 1, H = 2, D = 4 }
P.CLASS_ROLES = { WARRIOR = 5, PALADIN = 7, DRUID = 7, PRIEST = 6, SHAMAN = 6, HUNTER = 4, ROGUE = 4, MAGE = 4, WARLOCK = 4 }

local function has(bits, b) return (bits or 0) % (b * 2) >= b end

function P.spot(role, class, min, max)
	local s = { role = LETTER_ROLE[ROLE_LETTER[role or 0] or "A"] }
	class = clean(class or "", 12):upper():gsub("[^A-Z]", "")
	if P.CLASS_ROLES[class] then s.class = class end
	s.min, s.max = int(min, 1, 200), int(max, 1, 200)
	if s.min and s.max and s.min > s.max then s.min, s.max = s.max, s.min end
	return s
end

function P.spotsText(spots)
	local out = {}
	for _, sp in ipairs(type(spots) == "table" and spots or {}) do
		if #out >= P.MAX_SPOTS then break end
		local s = P.spot(sp.role, sp.class, sp.min, sp.max)
		out[#out + 1] = ("%s/%s/%s/%s"):format(ROLE_LETTER[s.role], s.class or "", s.min or "", s.max or "")
	end
	return table.concat(out, ",")
end

function P.spotsParse(text)
	local out = {}
	if type(text) ~= "string" then return out end
	for item in text:gmatch("[^,]+") do
		local r, c, lo, hi = item:match("^(%a)/(%a*)/(%d*)/(%d*)$")
		if r and LETTER_ROLE[r:upper()] and #out < P.MAX_SPOTS then
			out[#out + 1] = P.spot(LETTER_ROLE[r:upper()], c, lo, hi)
		end
	end
	return out
end

-- the need bits for a set of spots (an "any" spot asks for every role)
function P.needOfSpots(spots)
	local need = 0
	for _, s in ipairs(spots or {}) do
		for _, r in ipairs({ 1, 2, 4 }) do
			if (s.role == 0 or s.role == r) and not has(need, r) then need = need + r end
		end
	end
	return need
end

-- n spots from need bits: a tank and a healer if wanted, the rest damage (or any role when the
-- group doesn't want damage). need 0 counts as every role.
function P.spotsFromNeed(need, n)
	need = (need and need > 0) and need or 7
	local out = {}
	if has(need, 1) and #out < n then out[#out + 1] = P.spot(1) end
	if has(need, 2) and #out < n then out[#out + 1] = P.spot(2) end
	while #out < n do out[#out + 1] = P.spot(has(need, 4) and 4 or 0) end
	return out
end

-- The role a player would fill this spot as, or nil. roles = the roles they play (need bits);
-- 0 means unknown, then their class decides.
function P.spotFits(s, class, level, roles)
	if s.class and s.class ~= class then return nil end
	level = level or 0
	if s.min and not (level > 0 and level >= s.min) then return nil end
	if s.max and not (level > 0 and level <= s.max) then return nil end
	roles = (roles and roles > 0) and roles or (P.CLASS_ROLES[class or ""] or 7)
	if s.role ~= 0 then return has(roles, s.role) and s.role or nil end
	for _, r in ipairs({ 1, 2, 4 }) do if has(roles, r) then return r end end
	return nil
end

-- how picky a spot is: a class counts most, then a role, then a level range
function P.spotScore(s)
	return (s.class and 4 or 0) + ((s.role or 0) ~= 0 and 2 or 0) + ((s.min or s.max) and 1 or 0)
end

-- The spot a player fits best, most specific first. skip = { [index] = true } for spots taken.
-- Returns index, role or nil.
function P.bestSpot(spots, class, level, roles, skip)
	local best, bestRole, bestScore
	for i, s in ipairs(spots or {}) do
		if not (skip and skip[i]) then
			local r = P.spotFits(s, class, level, roles)
			if r and (not bestScore or P.spotScore(s) > bestScore) then best, bestRole, bestScore = i, r, P.spotScore(s) end
		end
	end
	return best, bestRole
end

local function actsText(acts)
	local out = {}
	for _, id in ipairs(type(acts) == "table" and acts or {}) do
		local n = int(id, 1, 2^31)
		if n and #out < P.MAX_ACTS then out[#out + 1] = tostring(n) end
	end
	return table.concat(out, ",")
end

local function actsParse(s)
	local out = {}
	if type(s) ~= "string" then return out end
	for v in s:gmatch("[^,]+") do
		local n = int(v, 1, 2^31)
		if n and #out < P.MAX_ACTS then out[#out + 1] = n end
	end
	return out
end

-- l = { leader, seq, shard, level, size, age, hops, class, need, cat, acts, title, note }
function P.listing(l)
	local msg = ("L1;%s;%d;%d;%d;%d;%d;%d;%s;%d;%d;%s;%d;%d;%s;%s"):format(
		clean(l.leader, P.NAME_LEN), l.seq or 0, l.shard or 0, l.level or 0, l.size or 1,
		math.floor(l.age or 0), l.hops or 0, clean(l.class, 12):upper(), l.need or 0,
		math.max(0, int(l.cat, 0, 99999) or 0), actsText(l.acts), int(l.price, 0, P.MAX_PRICE) or 0,
		int(l.quest, 0, 10000000) or 0, clean(l.title, P.TITLE_LEN), clean(l.note, P.NOTE_LEN))
	-- the spots go last; if it's too long the note gives way, not the spots
	local spots = P.spotsText(l.spots)
	local tail = spots ~= "" and (";" .. spots) or ""
	if #msg + #tail > P.MAX_LEN then msg = msg:sub(1, P.MAX_LEN - #tail) end
	return msg .. tail
end

-- Returns kind, table; or nil for anything malformed. Never errors.
function P.parse(msg)
	if type(msg) ~= "string" or #msg > 255 then return nil end
	local f = split(msg)
	local kind = f[1]
	if kind == "H1" or kind == "A1" then
		local shard, level = int(f[2], 0, 99999), int(f[3], 0, 200)
		if not shard or not level then return nil end
		return kind, { shard = shard, level = level, version = clean(f[4] or "", 16) }
	elseif kind == "X1" then
		local out = {}
		for entry in (f[2] or ""):gmatch("[^,]+") do
			local name, shard = entry:match("^(.+):(%d+)$")
			name = clean(name, P.NAME_LEN)
			shard = int(shard, 0, 99999)
			if name ~= "" and shard and #out < P.MAX_PX then out[#out + 1] = { name = name, shard = shard } end
		end
		if #out == 0 then return nil end
		return kind, { peers = out }
	elseif kind == "P1" then
		if not f[2] or f[2] == "" then return nil end
		return kind, { token = clean(f[2], 16) }
	elseif kind == "Q1" then
		local shard = int(f[3], 0, 99999)
		if not f[2] or f[2] == "" or not shard then return nil end
		return kind, { token = clean(f[2], 16), shard = shard }
	elseif kind == "L1" then
		local l = {
			leader = clean(f[2], P.NAME_LEN), seq = int(f[3], 0, 2^31), shard = int(f[4], 0, 99999),
			level = int(f[5], 0, 200), size = int(f[6], 1, 40), age = int(f[7], 0, 86400),
			hops = int(f[8], 0, 10), class = clean(f[9], 12):upper():gsub("[^A-Z]", ""), need = int(f[10], 0, 7),
			cat = int(f[11], 0, 99999), acts = actsParse(f[12]), price = int(f[13], 0, P.MAX_PRICE),
			quest = int(f[14], 0, 10000000), title = clean(f[15], P.TITLE_LEN), note = clean(f[16], P.NOTE_LEN),
			spots = P.spotsParse(f[17]),
		}
		if not l.price or not l.quest then return nil end
		if l.quest > 0 and l.title == "" then return nil end
		if l.cat == P.SUMMON_CAT and (l.title == "" or l.class ~= "WARLOCK") then return nil end
		if l.leader == "" or (l.title == "" and #l.acts == 0) then return nil end
		if not (l.seq and l.shard and l.level and l.size and l.age and l.hops and l.need and l.cat) then return nil end
		if l.age > P.MAX_AGE then return nil end
		return kind, l
	elseif kind == "J1" then
		local level, need = int(f[3], 0, 200), int(f[4], 0, 7)
		if not level or not need then return nil end
		return kind, { class = clean(f[2], 12):upper():gsub("[^A-Z]", ""), level = level, need = need }
	elseif kind == "F1" then
		local shard, digest = int(f[2], 0, 99999), int(f[3], 0, 2^31)
		local part, parts = int(f[4], 1, 99), int(f[5], 1, 99)
		if not (shard and digest and part and parts and part <= parts) then return nil end
		local items = {}
		for e in (f[6] or ""):gmatch("[^,]+") do
			local name, act, size, need, age = e:match("^([^/]+)/(%d+)/(%d+)/(%d+)/(%d+)$")
			name = clean(name, P.NAME_LEN)
			act, size, need, age = int(act, 0, 2^31), int(size, 1, 40), int(need, 0, 7), int(age, 0, 86400)
			if name ~= "" and act and size and need and age and #items < P.MAX_DIGEST then
				items[#items + 1] = { leader = name, act = act, size = size, need = need, age = age }
			end
		end
		return kind, { shard = shard, digest = digest, part = part, parts = parts, items = items }
	elseif kind == "C1" then
		local shard, digest = int(f[2], 0, 99999), int(f[3], 0, 2^31)
		local part, parts = int(f[4], 1, 99), int(f[5], 1, 99)
		if not (shard and digest and part and parts and part <= parts) then return nil end
		local items = {}
		for e in (f[6] or ""):gmatch("[^~]+") do
			local name, age, act, need, size, text = e:match("^([^%^]+)%^(%d+)%^(%d+)%^(%d+)%^(%d+)%^(.+)$")
			name, text = clean(name, P.NAME_LEN), clean(text, P.CHAT_TEXT)
			age, act, need, size = int(age, 0, 86400), int(act, 0, 2^31), int(need, 0, 7), int(size, 1, 40)
			if name ~= "" and text ~= "" and age and act and need and size and #items < P.MAX_CHAT then
				items[#items + 1] = { leader = name, age = age, act = act, need = need, size = size, text = text }
			end
		end
		return kind, { shard = shard, digest = digest, part = part, parts = parts, items = items }
	elseif kind == "R1" then
		return kind, { groups = int(f[2], 0, 999) or 0 }
	elseif kind == "G1" then
		local k, l = P.parse("L1;" .. msg:sub(4))
		if k ~= "L1" then return nil end
		return kind, l
	elseif kind == "G0" then
		return kind, { seq = int(f[2], 0, 2^31) or 0 }
	elseif kind == "GQ" then
		return kind, {}
	elseif kind == "I1" then
		return kind, { title = clean(f[2], P.TITLE_LEN) }
	elseif kind == "U1" then
		local leader, seq = clean(f[2], P.NAME_LEN), int(f[3], 0, 2^31)
		if leader == "" or not seq then return nil end
		return kind, { leader = leader, seq = seq }
	end
	return nil
end

-- The shard number from a channel name: "Trade 47", "LookingForGroup 47", "General - Elwynn 47".
function P.shardFromChannel(name)
	if type(name) ~= "string" then return nil end
	local n = name:match("%s(%d+)%s*$")
	return int(n, 1, 99999)
end

-- Which peers to relay a listing to: ones not on the sender's or leader's shard first, never the
-- sender or leader, at most `count`. peers = { [name] = { shard = n, seen = t } }; order is stable
-- (sorted by name) so tests are repeatable; `rand` shuffles when given.
function P.relayTargets(peers, l, sender, count, rand)
	local far, near = {}, {}
	for name, p in pairs(peers) do
		if name ~= sender and name ~= l.leader then
			if p.shard ~= l.shard then far[#far + 1] = name else near[#near + 1] = name end
		end
	end
	table.sort(far); table.sort(near)
	if rand then
		for _, t in ipairs({ far, near }) do
			for i = #t, 2, -1 do local j = rand(i); t[i], t[j] = t[j], t[i] end
		end
	end
	local out = {}
	for _, t in ipairs({ far, near }) do
		for _, name in ipairs(t) do
			if #out >= count then return out end
			out[#out + 1] = name
		end
	end
	return out
end

-- Should an incoming listing replace what we hold? (newer seq from the same leader, or new leader)
function P.isNewer(held, l)
	return held == nil or l.seq > held.seq
end

-- The same listing, re-announced by its leader: is it fresh enough to keep it alive and pass on?
-- (Without this a listing expired five minutes after it was first heard, re-announced or not.)
P.REFRESH_GAP = 45
function P.isRefresh(held, l, now)
	return held ~= nil and l.seq == held.seq and (now - (l.age or 0)) > (held.got or 0) + P.REFRESH_GAP
end

return P
