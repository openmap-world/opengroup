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
--   U1;<leader>;<seq>                 the leader delisted
-- Fields never contain ";" or "|" (stripped on the way in and out). A message stays under 250 bytes.

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

P.VERSION = "0.6.0-test"
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

-- "0.6.0-test" -> 600; nil for anything else
function P.versionNumber(v)
	local a, b, c = tostring(v or ""):match("^(%d+)%.(%d+)%.(%d+)")
	if not a then return nil end
	return tonumber(a) * 10000 + tonumber(b) * 100 + tonumber(c)
end
function P.ping(token) return "P1;" .. clean(token, 16) end
function P.pong(token, shard) return ("Q1;%s;%d"):format(clean(token, 16), shard or 0) end
function P.unlist(leader, seq) return ("U1;%s;%d"):format(clean(leader, P.NAME_LEN), seq or 0) end

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
	if #msg > P.MAX_LEN then msg = msg:sub(1, P.MAX_LEN) end
	return msg
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
		}
		if not l.price or not l.quest then return nil end
		if l.quest > 0 and l.title == "" then return nil end
		if l.cat == P.SUMMON_CAT and (l.title == "" or l.class ~= "WARLOCK") then return nil end
		if l.leader == "" or (l.title == "" and #l.acts == 0) then return nil end
		if not (l.seq and l.shard and l.level and l.size and l.age and l.hops and l.need and l.cat) then return nil end
		if l.age > P.MAX_AGE then return nil end
		return kind, l
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
