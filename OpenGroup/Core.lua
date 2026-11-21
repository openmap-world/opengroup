-- OpenGroup core: who we know, what's listed, and the hidden-whisper traffic between OpenGroup users.
local P = OpenGroup_Proto
local L = {}
OpenGroup = L

-- the addon's own icon (gold ring, a cross over a party)
L.ICON = "Interface\\AddOns\\OpenGroup\\Media\\icon"
-- the same art without its gold ring, for square spots (a tab on the game's window)
L.ICON_SQUARE = "Interface\\AddOns\\OpenGroup\\Media\\icon-square"

L.VERSION = P.VERSION
-- The word shown before the channel number ("Chat 47"). The number is the one the game puts after
-- every global channel (Trade, LookingForGroup, General), so it isn't named after one of them.
L.CHAN = "Chat"
L.peers = {}        -- [name] = { shard, level, seen }   OpenGroup users we can whisper (saved)
L.listings = {}     -- [leader] = { leader, seq, shard, level, size, title, note, hops, got, age, via }
L.mine = nil        -- our own listing while we're listed
L.pings = {}        -- [token] = { to, at }   the cross-shard test
L.probed = {}       -- [name] = time a hello went out (not saved)
L.stats = { sent = 0, refused = 0, got = 0, bad = 0, missed = 0, learned = 0 }
L.sentTo = {}       -- [short name] = time we last whispered them (to hide and learn from misses)
L.newest = nil      -- newest OpenGroup version heard from anyone

local PEER_KEEP = 7 * 24 * 3600   -- forget peers not heard from in a week
local ANNOUNCE_EVERY = 90         -- re-send our listing this often while listed
local ANNOUNCE_PEERS = 25         -- to this many peers per round (rotating)
local RELAY_COUNT = 3
local OFFLINE_FOR = 600           -- a peer the game says is offline is skipped this long
local PEER_MAX = 600              -- remember at most this many (newest kept)
local PX_SEND = 20                -- names to share in a peer exchange (sent as messages of P.MAX_PX)
local PX_PROBE = 20               -- hellos to send per peer exchange message we receive

-- --------------------------------------------------------------------------------------------
-- helpers

local function now() return time() end

function L.print(...)
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffOpenGroup|r: " .. strjoin(" ", tostringall(...)))
end

-- Forever names are "First Surname"; an addon sender can arrive as "First Surname-Realm".
-- Keep what the game gave us for whispering back, show the short form.
function L.short(name)
	return type(name) == "string" and (name:match("^([^%-]+)") or name) or "?"
end

-- A unit's full name. Forever's names have two parts ("Ji Unit"), and UnitName hands the second
-- one back separately (where other clients put the realm), so taking only its first value cut
-- "Stuxnet Metasploit" to "Stuxnet": whispers then went to the wrong name.
function L.unitName(unit)
	local ok, n, r = pcall(UnitName, unit)
	if not ok or type(n) ~= "string" or n == "" then return nil end
	if n:find(" ", 1, true) then return n end
	if type(r) == "string" and r ~= "" then return n .. " " .. r end
	return n
end

function L.me() return L.unitName("player") end

-- Is this name us? /who and addon senders may add "-Realm" to our own name.
function L.isMe(name)
	return type(name) == "string" and L.short(name) == L.short(L.me())
end

function L.faction() return (UnitFactionGroup("player")) end

-- A listing's display title: the activity names in this client's language, else the free text.
function L.titleOf(l)
	if l.cat == P.SUMMON_CAT then return "Summon to " .. (l.title or "?") end
	if (l.quest or 0) > 0 then
		local Q = OpenGroup_Quests
		return (Q and Q.name(l.quest)) or l.title or ("Quest " .. l.quest)
	end
	local A = OpenGroup_Activities
	local acts = l.acts or {}
	if #acts == 1 and A and A.name(acts[1]) then return A.name(acts[1]) end
	if #acts > 1 and A then
		local first = A.name(acts[1])
		if first then return ("%s +%d"):format(first, #acts - 1) end
	end
	if l.title and l.title ~= "" then return l.title end
	return #acts == 1 and "1 activity" or #acts > 1 and (#acts .. " activities") or "?"
end

-- Our shard: the number the game puts after Trade / LookingForGroup ("Trade 47"). Where it sits
-- differs by API, so look everywhere: the name GetChannelList gives, GetChannelName's instance id,
-- and the channel names chat events carry (cached by the event handler below).
L.shardSeen = nil
local SHARD_CHANNELS = { "^Trade", "^LookingForGroup", "^LFG", "^General", "^Local" }
local function isShardChannel(name)
	if type(name) ~= "string" then return false end
	name = name:gsub("^%d+%.%s*", "")
	for _, pat in ipairs(SHARD_CHANNELS) do if name:find(pat) then return true end end
	return false
end
L.isShardChannel = isShardChannel

function L.shard()
	local list = { GetChannelList() }
	for i = 1, #list, 3 do
		local name = list[i + 1]
		if isShardChannel(name) then
			local n = P.shardFromChannel(name)
			if n then return n end
		end
	end
	if GetChannelName then
		for id = 1, 10 do
			local okC, cid, name, instanceID = pcall(GetChannelName, id)
			if okC and isShardChannel(name) then
				local n = P.shardFromChannel(name) or P.int(instanceID, 1, 99999)
				if n then return n end
			end
		end
	end
	return L.shardSeen or 0
end

-- Our chat number can change: joining a group on another server shard or layer, a zone change, or
-- the game moving us. Check after those events (and a moment later, once the channels have
-- rejoined); when it changed, tell the OpenGroup players we heard from lately with a hello, so
-- they file us under the new number, and redraw. At most one round of hellos per 30 seconds.
L.lastShard = nil
local shardToldAt = -1000
function L.checkShard()
	local n = L.shard()
	if n <= 0 or n == L.lastShard then return false end
	local old = L.lastShard
	L.lastShard = n
	if old and old > 0 then
		L.shardChanges = (L.shardChanges or 0) + 1
		if now() - shardToldAt >= 30 then
			shardToldAt = now()
			for _, name in ipairs(L.recent(15, true)) do L.send(name, P.hello(n, UnitLevel("player")), true) end
		end
		if L.onChange then pcall(L.onChange) end
	end
	return true
end
local function checkSoon()
	pcall(L.checkShard)
	if C_Timer and C_Timer.After then C_Timer.After(3, function() pcall(L.checkShard) end) end
end
L.checkShardSoon = checkSoon

-- Everything the game says about our channels, for /og shard (the "?" hunt).
function L.shardReport()
	local lines = {}
	local list = { GetChannelList() }
	for i = 1, #list, 3 do lines[#lines + 1] = ("list %s: %q"):format(tostring(list[i]), tostring(list[i + 1])) end
	if GetChannelName then
		for id = 1, 10 do
			local ok, a, b, c, d = pcall(GetChannelName, id)
			if ok and a and a ~= 0 then lines[#lines + 1] = ("name %d: %s, %q, %s, %s"):format(id, tostring(a), tostring(b), tostring(c), tostring(d)) end
		end
	end
	lines[#lines + 1] = "from chat: " .. tostring(L.shardSeen) .. " (" .. tostring(L.shardSeenFrom) .. ")"
	return lines
end

-- --------------------------------------------------------------------------------------------
-- sending: the client allows about 10 messages per prefix at once, then about 1 a second.

-- Two queues: what other players are waiting on (answers, listings) goes first; hellos to players
-- who may not run OpenGroup wait in the slow lane, so growing the network never delays a listing.
local queue, slow, tokens = {}, {}, 8
local MAX_QUEUE, MAX_SLOW = 200, 300

function L.send(target, msg, low)
	if not target or target == "" or L.isMe(target) then return end
	local q = low and slow or queue
	if #q >= (low and MAX_SLOW or MAX_QUEUE) then return end
	q[#q + 1] = { target, msg }
end

local function pump()
	tokens = math.min(8, tokens + 0.25)
	while tokens >= 1 and (#queue > 0 or #slow > 0) do
		local item = table.remove(#queue > 0 and queue or slow, 1)
		tokens = tokens - 1
		L.sentTo[L.short(item[1])] = now()
		local ok, res = pcall(C_ChatInfo.SendAddonMessage, P.PREFIX, item[2], "WHISPER", item[1])
		-- newer clients return an Enum.SendAddonMessageResult (0 = Success); older ones true/false
		if ok and (res == nil or res == true or res == 0) then
			L.stats.sent = L.stats.sent + 1
		else
			L.stats.refused = L.stats.refused + 1
			L.lastRefusal = tostring(res)
		end
	end
end

function L.queued() return #queue + #slow end

-- --------------------------------------------------------------------------------------------
-- peers and listings

function L.addPeer(name, shard, level, version)
	local p = L.peers[name] or {}
	p.shard, p.level, p.seen, p.off = shard or p.shard or 0, level or p.level or 0, now(), nil
	if version and version ~= "" then p.v = version end
	L.peers[name] = p
	L.probed[name] = nil
end

-- peers worth whispering now: not reported offline in the last few minutes
function L.live()
	local out, t = {}, now()
	for name, p in pairs(L.peers) do
		if not (p.off and t - p.off < OFFLINE_FOR) then out[name] = p end
	end
	return out
end

-- names sorted newest-heard first (optionally live only)
function L.recent(max, liveOnly)
	local src = liveOnly and L.live() or L.peers
	local list = {}
	-- (players on your ignore list are left out: not shown, not whispered)
	for name, p in pairs(src) do if not (L.ignored and L.ignored(name)) then list[#list + 1] = { name, p.seen or 0 } end end
	table.sort(list, function(a, b) return a[2] > b[2] end)
	local out = {}
	for i = 1, math.min(max or #list, #list) do out[i] = list[i][1] end
	return out
end

-- a hidden hello to someone who may run OpenGroup; only users answer. why: for /og status
function L.probe(name, why)
	if type(name) ~= "string" or name == "" or L.peers[name] or L.isMe(name) then return false end
	local t = L.probed[name]
	if t and now() - t < 1800 then return false end
	L.probed[name] = now()
	L.stats.probes = (L.stats.probes or 0) + 1
	if why then L.probeWhy = L.probeWhy or {} L.probeWhy[why] = (L.probeWhy[why] or 0) + 1 end
	L.send(name, P.hello(L.shard(), UnitLevel("player")), true)
	return true
end

-- Players around you: the ones you mouse over and whose nameplates show up get a quiet hello too
-- (same faction, real players, not in instances or combat). A small queue, one hello every 2
-- seconds, the oldest dropped past 30; anyone asked this way isn't asked again this session
-- (only OpenGroup users answer, so most never do).
L.nearQueue, L.nearAsked = {}, {}
local NEAR_MAX = 30
function L.noteNearby(unit)
	if type(OpenGroupDB) == "table" and OpenGroupDB.nearHello == false then return false end
	if not UnitIsPlayer or not UnitIsPlayer(unit) then return false end
	if UnitIsUnit and UnitIsUnit(unit, "player") then return false end
	if UnitFactionGroup and UnitFactionGroup(unit) ~= UnitFactionGroup("player") then return false end
	if IsInInstance then local inside = IsInInstance() if inside then return false end end
	local name = L.unitName(unit)
	if not name or (canaccessvalue and not canaccessvalue(name)) then return false end
	name = L.short(name)
	if L.peers[name] or L.nearAsked[name] or L.isMe(name) then return false end
	for _, n in ipairs(L.nearQueue) do if n == name then return false end end
	L.nearQueue[#L.nearQueue + 1] = name
	while #L.nearQueue > NEAR_MAX do table.remove(L.nearQueue, 1) end
	-- the 2-second drip starts with the first player noticed
	if not L.nearTicker and C_Timer and C_Timer.NewTicker then L.nearTicker = C_Timer.NewTicker(2, function() pcall(L.nearTick) end) end
	return true
end
-- the next one in the queue: every 2 seconds
function L.nearTick()
	if InCombatLockdown and InCombatLockdown() then return false end
	while #L.nearQueue > 0 do
		local name = table.remove(L.nearQueue, 1)
		if not L.peers[name] and not L.nearAsked[name] then
			L.nearAsked[name] = true
			if L.probe(name, "nearby") then return true end
		end
	end
	return false
end

-- who to tell a newcomer about: recently heard, live, other shards than theirs first
local function shareList(to, toShard, max)
	local far, near = {}, {}
	for _, name in ipairs(L.recent(60, true)) do
		local p = L.peers[name]
		if name ~= to and now() - (p.seen or 0) < 2 * 86400 then
			local t = (p.shard ~= toShard) and far or near
			t[#t + 1] = { name, p.shard or 0 }
		end
	end
	local out = {}
	for _, t in ipairs({ far, near }) do for _, e in ipairs(t) do if #out < max then out[#out + 1] = e end end end
	return out
end

-- up to PX_SEND names, newest first and other chat numbers first, in messages of at most P.MAX_PX
-- (what older versions read from one message)
local function sharePeers(to, toShard)
	local list = shareList(to, toShard, PX_SEND)
	local i = 1
	while i <= #list do
		local chunk = {}
		for k = i, math.min(#list, i + P.MAX_PX - 1) do chunk[#chunk + 1] = list[k] end
		local msg = P.peerList(chunk)
		if msg then L.send(to, msg) end
		i = i + P.MAX_PX
	end
end
L.sharePeers = sharePeers

-- "a newer OpenGroup is out": only for released versions. A local test build ("-test", "-dev")
-- someone is trying isn't out, and must not send everyone else looking for it.
L.newerFrom = {}   -- [version] = { [sender] = true }: who runs a newer released version
function L.notePeerVersion(v, sender)
	if P.isPrerelease(v) then return end
	local n = P.versionNumber(v)
	if not n then return end
	local mine = P.versionNumber(L.VERSION) or 0
	if n <= mine or n <= (P.versionNumber(L.newest) or 0) then return end
	-- at least two different players run it before we say it's out
	local from = L.newerFrom[v] or {}
	L.newerFrom[v] = from
	if sender then from[L.short(sender)] = true end
	if L.count(from) < 2 then return end
	L.newest = v
	if not L.toldNewer then
		L.toldNewer = true
		L.print(("a newer OpenGroup (%s) is out; you have %s. Update when you can."):format(v, L.VERSION))
	end
end

-- --------------------------------------------------------------------------------------------
-- Guarding against other clients (anyone can run their own): your ignore list, a per-sender
-- message budget, caps on what's kept, and relayed listings checked with their leader.

-- on your ignore list: nothing from them is shown, answered or invited
function L.ignored(name)
	if type(name) ~= "string" or name == "" or not (C_FriendList and C_FriendList.IsIgnored) then return false end
	local ok, yes = pcall(C_FriendList.IsIgnored, L.short(name))
	return ok and yes == true
end

-- each sender gets a burst of 20 messages, refilled at one a second; past that they're dropped
local budget = {}
local BUDGET_MAX, BUDGET_RATE = 20, 1
function L.spend(sender)
	local t = GetTime()
	local b = budget[sender]
	if not b then b = { n = BUDGET_MAX, t = t } budget[sender] = b end
	b.n = math.min(BUDGET_MAX, b.n + (t - b.t) * BUDGET_RATE)
	b.t = t
	if b.n < 1 then L.stats.dropped = (L.stats.dropped or 0) + 1 return false end
	b.n = b.n - 1
	return true
end
local function pruneBudgets()
	local t = GetTime()
	for name, b in pairs(budget) do if t - b.t > 120 then budget[name] = nil end end
end

L.MAX_LISTINGS = 300
-- A listing passed on by someone else may name any leader. It shows as unconfirmed, and the leader
-- gets a hidden hello: if they're listed they answer with their own listing (confirmed); if no
-- listing of theirs arrives within a minute, the passed-on one is dropped.
L.directAt = {}   -- [leader] = when their own listing last came straight from them
L.verify = {}     -- [leader] = when we asked
local VERIFY_WAIT = 60

local function store(l, via)
	local fresh = L.listings[l.leader] == nil
	l.got = now() - (l.age or 0)
	l.via = via
	if l.hops == 0 then
		L.directAt[l.leader], L.verify[l.leader] = now(), nil
	elseif not (L.directAt[l.leader] and now() - L.directAt[l.leader] < P.MAX_AGE) then
		l.unconfirmed = true
		if not L.verify[l.leader] then
			L.verify[l.leader] = now()
			L.send(l.leader, P.hello(L.shard(), UnitLevel("player")), true)
		end
	end
	L.listings[l.leader] = l
	-- too many held: the oldest go
	if fresh and L.count(L.listings) > L.MAX_LISTINGS then
		local oldest
		for name, x in pairs(L.listings) do if not oldest or x.got < L.listings[oldest].got then oldest = name end end
		if oldest then L.listings[oldest] = nil end
	end
	if fresh and L.onNewListing then pcall(L.onNewListing, l) end
	if L.onChange then L.onChange() end
end

local function relay(l, sender)
	if l.hops >= P.MAX_HOPS then return end
	local copy = {}
	for k, v in pairs(l) do copy[k] = v end
	copy.hops = l.hops + 1
	copy.age = now() - l.got
	local msg = P.listing(copy)
	for _, name in ipairs(P.relayTargets(L.live(), l, sender, RELAY_COUNT, math.random)) do
		L.send(name, msg)
	end
end

-- a few fresh listings for someone who just said hello, so a new user sees groups at once
local function sendKnown(to, max)
	local n = 0
	for _, l in pairs(L.listings) do
		if n >= max then return end
		local age = now() - l.got
		if age < P.MAX_AGE and l.leader ~= to then
			local copy = {}
			for k, v in pairs(l) do copy[k] = v end
			copy.age, copy.hops = age, math.min(P.MAX_HOPS, l.hops + 1)
			L.send(to, P.listing(copy))
			n = n + 1
		end
	end
end

local answeredAt = {}
function L.receive(msg, sender)
	if L.isMe(sender) then return end
	if L.ignored(sender) then L.stats.ignored = (L.stats.ignored or 0) + 1 return end
	if not L.spend(sender) then return end
	local kind, d = P.parse(msg)
	if not kind then L.stats.bad = L.stats.bad + 1 return end
	L.stats.got = L.stats.got + 1
	if kind == "H1" then
		local isNew = L.peers[sender] == nil
		L.addPeer(sender, d.shard, d.level, d.version)
		L.notePeerVersion(d.version, sender)
		-- answer a given sender's hello at most every 30 seconds (one hello makes several whispers)
		if answeredAt[sender] and now() - answeredAt[sender] < 30 then return end
		answeredAt[sender] = now()
		L.send(sender, P.answer(L.shard(), UnitLevel("player")))
		if L.mine then L.send(sender, P.listing(L.mineForSend())) end
		sendKnown(sender, 5)
		sharePeers(sender, d.shard)
		if isNew and L.onPeer then L.onPeer(sender) end
	elseif kind == "A1" then
		local isNew = L.peers[sender] == nil
		L.addPeer(sender, d.shard, d.level, d.version)
		L.notePeerVersion(d.version, sender)
		if L.mine then L.send(sender, P.listing(L.mineForSend())) end
		if isNew then sharePeers(sender, d.shard) end
		if isNew and L.onPeer then L.onPeer(sender) end
	elseif kind == "X1" then
		if L.peers[sender] then L.peers[sender].seen = now() end
		local sent = 0
		for _, e in ipairs(d.peers) do
			if sent >= PX_PROBE then break end
			if not L.isMe(e.name) and L.probe(e.name, "shared") then sent = sent + 1 L.stats.learned = L.stats.learned + 1 end
		end
	elseif kind == "P1" then
		L.send(sender, P.pong(d.token, L.shard()))
	elseif kind == "Q1" then
		local p = L.pings[d.token]
		if p then
			L.print(("ping to %s came back from " .. L.CHAN .. " %d in %.1fs: hidden whispers reach them."):format(
				L.short(sender), d.shard, GetTime() - p.at))
			L.pings[d.token] = nil
		end
		L.addPeer(sender, d.shard)
	elseif kind == "L1" then
		L.peers[sender] = L.peers[sender] or { shard = 0, level = 0 }
		L.peers[sender].seen = now()
		if L.isMe(d.leader) or L.ignored(d.leader) then return end
		-- the leader's own message: whisper the name the game gave us, it's the reliable spelling
		if d.hops == 0 then d.leader = sender end
		-- a straight-from-the-leader listing settles an unconfirmed one even when it isn't newer
		local had = L.listings[d.leader]
		if d.hops == 0 and had and had.unconfirmed and d.seq >= had.seq then had.unconfirmed = nil L.directAt[d.leader] = now() L.verify[d.leader] = nil end
		local held = L.listings[d.leader]
		if P.isNewer(held, d) or P.isRefresh(held, d, now()) then
			store(d, sender)
			relay(d, sender)
		end
	elseif kind == "F1" then
		-- another shard's Group Finder groups (Nearby keeps them)
		if L.peers[sender] then L.peers[sender].seen = now() end
		if L.onFinderDigest then pcall(L.onFinderDigest, sender, d) end
	elseif kind == "T1" then
		if L.peers[sender] then L.peers[sender].seen = now() end
		if L.onFeed then pcall(L.onFeed, sender, d, msg) end
	elseif kind == "B1" then
		if L.onBacklogAsk then pcall(L.onBacklogAsk, sender, d) end
	elseif kind == "C1" then
		if L.peers[sender] then L.peers[sender].seen = now() end
		if L.onChatDigest then pcall(L.onChatDigest, sender, d) end
	elseif kind == "R1" then
		if L.onReporter then pcall(L.onReporter, sender, d) end
	elseif kind == "J1" then
		if L.onJoinRequest then pcall(L.onJoinRequest, sender, d) end
	elseif kind == "I1" then
		L.print(("%s's auto invite just invited you%s."):format(L.short(sender), d.title ~= "" and (" for " .. d.title) or ""))
	elseif kind == "U1" then
		local held = L.listings[d.leader] or L.listings[sender]
		if held and d.seq >= held.seq then
			L.listings[held.leader] = nil
			if L.onChange then L.onChange() end
			if d.seq > 0 then
				for _, name in ipairs(P.relayTargets(L.live(), held, sender, RELAY_COUNT, math.random)) do
					L.send(name, msg)
				end
			end
		end
	end
end

-- --------------------------------------------------------------------------------------------
-- our own listing

-- age on the wire is "seconds since the leader last sent this", not since it was first listed:
-- a listing older than five minutes used to be rejected everywhere even while its leader was on.
function L.mineForSend()
	local m = L.mine
	return { leader = L.me(), seq = m.seq, shard = L.shard(), level = UnitLevel("player"),
		size = math.max(1, GetNumGroupMembers()), age = 0, hops = 0,
		class = select(2, UnitClass("player")) or "", need = m.need or 0, cat = m.cat or 0, acts = m.acts or {}, price = m.price or 0, quest = m.quest or 0,
		title = m.title, note = m.note, spots = m.spots }
end

local announceAt = 1
-- change the roles a listing still wants (auto invite, as people join) without a new listing
function L.setNeed(need)
	need = P.int(need, 0, 7) or 0
	if not L.mine or L.mine.need == need then return end
	OpenGroupDB.seq = (OpenGroupDB.seq or 0) + 1
	L.mine.need, L.mine.seq = need, OpenGroupDB.seq
	L.announce()
	if L.onChange then L.onChange() end
end

-- change the open spots (auto invite fills them, the group grows) without a new listing
function L.setSpots(spots)
	if not L.mine then return end
	local clean = {}
	-- tidied in place: auto invite holds on to these tables for its pending invites
	for _, sp in ipairs(spots or {}) do
		if #clean < P.MAX_SPOTS and type(sp) == "table" then
			local n = P.spot(sp.role, sp.class, sp.min, sp.max)
			sp.role, sp.class, sp.min, sp.max = n.role, n.class, n.min, n.max
			clean[#clean + 1] = sp
		end
	end
	-- (auto invite edits the spots in place, so compare with what was last sent)
	local text = P.spotsText(clean)
	if text == L.mine.spotsSent then return end
	OpenGroupDB.seq = (OpenGroupDB.seq or 0) + 1
	L.mine.spots, L.mine.seq, L.mine.spotsSent = clean, OpenGroupDB.seq, text
	if #clean > 0 then L.mine.need = P.needOfSpots(clean) end
	L.announce()
	if L.onChange then L.onChange() end
end

function L.announce()
	if not L.mine then return end
	local names = {}
	for name in pairs(L.live()) do names[#names + 1] = name end
	table.sort(names)
	if #names == 0 then return end
	local msg = P.listing(L.mineForSend())
	for i = 1, math.min(ANNOUNCE_PEERS, #names) do
		announceAt = (announceAt - 1) % #names + 1
		L.send(names[announceAt], msg)
		announceAt = announceAt + 1
	end
end

-- need: bits of P.TANK / P.HEALER / P.DAMAGE. acts: Group Finder activity ids (the game's, > 0);
-- a title is free text for Custom, or for a client without Group Finder data. Returns true when listed.
-- spots: the group's open spots (P.spot), or nil; when given, need comes from them
function L.post(title, note, need, cat, acts, price, quest, spots)
	title = P.clean(title, P.TITLE_LEN)
	local ids = {}
	for _, id in ipairs(type(acts) == "table" and acts or {}) do
		if type(id) == "number" and id > 0 and #ids < P.MAX_ACTS then ids[#ids + 1] = id end
		-- built-in names (negative ids) travel as the title
		if type(id) == "number" and id < 0 and title == "" and OpenGroup_Activities then title = OpenGroup_Activities.name(id) or "" end
	end
	quest = P.int(quest, 0, 10000000) or 0
	if quest > 0 and title == "" then quest = 0 end
	if title == "" and #ids == 0 then L.print("pick a dungeon or type what you're doing first.") return false end
	OpenGroupDB.seq = (OpenGroupDB.seq or 0) + 1
	local first = L.mine == nil
	local sp = {}
	for _, x in ipairs(type(spots) == "table" and spots or {}) do if #sp < P.MAX_SPOTS then sp[#sp + 1] = P.spot(x.role, x.class, x.min, x.max) end end
	if #sp > 0 then need = P.needOfSpots(sp) end
	L.mine = { title = title, note = P.clean(note or "", P.NOTE_LEN), need = P.int(need, 0, 7) or 0, spots = sp,
		cat = P.int(cat, 0, 99999) or 0, acts = ids, price = P.int(price, 0, P.MAX_PRICE) or 0, quest = quest,
		seq = OpenGroupDB.seq, at = first and now() or L.mine.at, spotsSent = P.spotsText(sp) }
	if L.onListed then L.onListed(first) end
	L.announce()
	if first then
		L.print(("listed \"%s\" to %d OpenGroup users (" .. L.CHAN .. " %d)."):format(L.titleOf(L.mine), math.min(ANNOUNCE_PEERS, L.count(L.peers)), L.shard()))
	end
	if L.onChange then L.onChange() end
	return true
end

function L.delist()
	if not L.mine then return end
	OpenGroupDB.seq = (OpenGroupDB.seq or 0) + 1
	local msg = P.unlist(L.me(), OpenGroupDB.seq)
	-- the newest 40 hear it from us; relays carry it on, and it expires everywhere in 5 minutes anyway
	for _, name in ipairs(L.recent(40, true)) do L.send(name, msg) end
	L.mine = nil
	L.print("delisted.")
	if L.onDelisted then L.onDelisted() end
	if L.onChange then L.onChange() end
end

-- Blizzard's own listing, when there is one: its activity name becomes our title.
function L.blizzardTitle()
	if not (C_LFGList and C_LFGList.GetActiveEntryInfo) then return nil end
	local ok, info = pcall(C_LFGList.GetActiveEntryInfo)
	if not ok or type(info) ~= "table" then return nil end
	local id = info.activityID or (type(info.activityIDs) == "table" and info.activityIDs[1])
	local name
	if id and C_LFGList.GetActivityInfoTable then
		local ok2, a = pcall(C_LFGList.GetActivityInfoTable, id)
		if ok2 and type(a) == "table" then name = a.shortName ~= "" and a.shortName or a.fullName end
	end
	return name, type(info.comment) == "string" and info.comment or ""
end

function L.ping(name)
	-- a hidden whisper to yourself never goes out, so there'd be nothing to answer
	if L.isMe(name) then L.print("that's you: target another player who runs OpenGroup to test the connection.") return end
	local token = tostring(math.random(100000, 999999))
	L.pings[token] = { to = name, at = GetTime() }
	L.send(name, P.ping(token))
	L.print(("pinging %s with a hidden whisper..."):format(name))
	C_Timer.After(15, function()
		if L.pings[token] then
			L.pings[token] = nil
			L.print(("no answer from %s in 15s: not running OpenGroup, offline, or hidden whispers don't reach them."):format(name))
		end
	end)
end

-- Refresh: say hello to known players again; each answers with its own listing and what it knows.
local lastAskAll = 0
function L.askAll()
	if GetTime() - lastAskAll < 10 then return end
	lastAskAll = GetTime()
	for _, name in ipairs(L.recent(15, true)) do L.send(name, P.hello(L.shard(), UnitLevel("player"))) end
end

function L.count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

-- --------------------------------------------------------------------------------------------
-- housekeeping: expire listings, forget old peers, re-announce

local sinceAnnounce = 0
local function tick()
	local t = now()
	local changed
	for leader, l in pairs(L.listings) do
		if t - l.got > P.MAX_AGE then L.listings[leader] = nil changed = true end
	end
	for name, p in pairs(L.peers) do
		if t - (p.seen or 0) > PEER_KEEP then L.peers[name] = nil end
	end
	if L.count(L.peers) > PEER_MAX then
		local keep = {}
		for _, name in ipairs(L.recent(PEER_MAX)) do keep[name] = true end
		for name in pairs(L.peers) do if not keep[name] then L.peers[name] = nil end end
	end
	for leader, asked in pairs(L.verify) do
		local l = L.listings[leader]
		if l and l.unconfirmed and t - asked > VERIFY_WAIT then L.listings[leader] = nil changed = true end
		if t - asked > 1800 then L.verify[leader] = nil end
	end
	for name, at in pairs(answeredAt) do if t - at > 60 then answeredAt[name] = nil end end
	pruneBudgets()
	sinceAnnounce = sinceAnnounce + 5
	if sinceAnnounce >= ANNOUNCE_EVERY then sinceAnnounce = 0 L.announce() end
	if changed and L.onChange then L.onChange() end
end

-- "No player named X is currently playing." after a whisper of ours: hide the line, and if X is a
-- peer, skip them for a while (they logged off) instead of whispering them every round.
local missPattern
local function missName(text)
	if not missPattern then
		local fmt = type(ERR_CHAT_PLAYER_NOT_FOUND_S) == "string" and ERR_CHAT_PLAYER_NOT_FOUND_S or "No player named '%s' is currently playing."
		missPattern = "^" .. fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", "(.+)") .. "$"
	end
	return text:match(missPattern)
end
L.missName = missName

local function hideOurMisses(_, _, text)
	if type(text) ~= "string" then return false end
	local name = missName(text)
	if not name then return false end
	local short = L.short(name)
	local at = L.sentTo[short]
	if not at or now() - at > 30 then return false end
	L.stats.missed = L.stats.missed + 1
	for peer, p in pairs(L.peers) do
		if L.short(peer) == short then
			p.off = now()
			-- every miss: World chat resends whatever went to them since the last one
			if L.onPeerGone then pcall(L.onPeerGone, peer) end
		end
	end
	return true
end
L.hideOurMisses = hideOurMisses

-- --------------------------------------------------------------------------------------------
-- growing the network without anyone clicking: everyone the player already plays with is a
-- likely OpenGroup user. A hello is invisible to players without it, and only users answer.

local lastGroupHello = 0
local function broadcastHello(channel)
	if channel == "GUILD" and not (IsInGuild and IsInGuild()) then return end
	pcall(C_ChatInfo.SendAddonMessage, P.PREFIX, P.hello(L.shard(), UnitLevel("player")), channel)
end

function L.seedGroup()
	if GetTime() - lastGroupHello < 30 then return end
	if (GetNumGroupMembers() or 0) <= 1 then return end
	lastGroupHello = GetTime()
	broadcastHello(IsInRaid and IsInRaid() and "RAID" or "PARTY")
end

function L.seedFriends()
	local n = 0
	if C_FriendList and C_FriendList.GetNumFriends then
		for i = 1, math.min(50, C_FriendList.GetNumFriends() or 0) do
			local ok, info = pcall(C_FriendList.GetFriendInfoByIndex, i)
			if ok and type(info) == "table" and info.connected and L.probe(info.name, "friends") then n = n + 1 end
		end
	end
	-- Battle.net friends playing this game on our faction
	if C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends then
		local fac = L.faction()
		for i = 1, math.min(100, (BNGetNumFriends()) or 0) do
			local ok, a = pcall(C_BattleNet.GetFriendAccountInfo, i)
			local g = ok and type(a) == "table" and a.gameAccountInfo
			if g and g.isOnline and g.clientProgram == (BNET_CLIENT_WOW or "WoW") and g.characterName and g.characterName ~= ""
				and (not g.factionName or g.factionName == fac) and (not WOW_PROJECT_ID or not g.wowProjectID or g.wowProjectID == WOW_PROJECT_ID) then
				local name = g.realmName and g.realmName ~= "" and (g.characterName .. "-" .. g.realmName:gsub("%s", "")) or g.characterName
				if L.probe(name, "friends") then n = n + 1 end
			end
		end
	end
	return n
end

function L.seedGuild()
	broadcastHello("GUILD")
end

-- anyone the player trades whispers with (that's how groups get made)
function L.seedWhisper(name)
	if type(name) == "string" then L.probe(name, "whispers") end
end

-- --------------------------------------------------------------------------------------------
-- events

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("CHAT_MSG_CHANNEL")
f:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
for _, ev in ipairs({ "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "CHANNEL_UI_UPDATE" }) do pcall(f.RegisterEvent, f, ev) end
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
f:SetScript("OnEvent", function(_, ev, a1, a2, a3, a4, ...)
	if ev == "CHAT_MSG_CHANNEL" or ev == "CHAT_MSG_CHANNEL_NOTICE" then
		-- arg4 is the channel's full name ("2. Trade 47"), arg9 its base name: a trailing number from either
		local a9 = select(5, ...)
		for _, name in ipairs({ a4, a9 }) do
			if isShardChannel(name) then
				local n = P.shardFromChannel(name)
				if n then
					L.shardSeen, L.shardSeenFrom = n, tostring(name)
					if ev == "CHAT_MSG_CHANNEL_NOTICE" or n ~= L.lastShard then pcall(L.checkShard) end
					return
				end
			end
		end
		return
	end
	if ev == "GROUP_ROSTER_UPDATE" then
		L.seedGroup()
		checkSoon()
		return
	elseif ev == "ZONE_CHANGED_NEW_AREA" or ev == "PLAYER_ENTERING_WORLD" or ev == "CHANNEL_UI_UPDATE" then
		checkSoon()
		return
	elseif ev == "CHAT_MSG_WHISPER" or ev == "CHAT_MSG_WHISPER_INFORM" then
		L.seedWhisper(a2)
		return
	end
	if ev == "ADDON_LOADED" and a1 == "OpenGroup" then
		OpenGroupDB = type(OpenGroupDB) == "table" and OpenGroupDB or {}
		OpenGroupDB.peers = type(OpenGroupDB.peers) == "table" and OpenGroupDB.peers or {}
		-- per faction: a whisper never reaches the other one
		L.peers = OpenGroupDB.peers
	elseif ev == "PLAYER_LOGIN" then
		local fac = L.faction() or "?"
		OpenGroupDB.peers[fac] = type(OpenGroupDB.peers[fac]) == "table" and OpenGroupDB.peers[fac] or {}
		L.peers = OpenGroupDB.peers[fac]
		for name, p in pairs(L.peers) do
			if type(name) ~= "string" or type(p) ~= "table" or L.isMe(name) then L.peers[name] = nil end
		end
		C_ChatInfo.RegisterAddonMessagePrefix(P.PREFIX)
		C_Timer.NewTicker(0.25, pump)
		C_Timer.NewTicker(5, tick)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", hideOurMisses)
		-- say hello to known peers so they know we're back (and send us what's listed and who they
		-- know), then to the guild, group and friends: the people most likely to run OpenGroup too
		C_Timer.After(10, function()
			for _, name in ipairs(L.recent(20)) do L.send(name, P.hello(L.shard(), UnitLevel("player"))) end
			L.seedGuild()
			L.seedGroup()
		end)
		C_Timer.After(20, function() L.seedFriends() end)
		L.print(("v%s loaded. /og to open. %d OpenGroup users known."):format(L.VERSION, L.count(L.peers)))
	elseif ev == "CHAT_MSG_ADDON" and a1 == P.PREFIX and a3 == "WHISPER" then
		local ok, err = pcall(L.receive, a2, a4)
		if not ok then L.stats.bad = L.stats.bad + 1 L.lastError = err end
	elseif ev == "CHAT_MSG_ADDON" and a1 == P.PREFIX and (a3 == "GUILD" or a3 == "PARTY" or a3 == "RAID") then
		-- only hellos travel on these (the answer goes back as a whisper like any other), and on
		-- PARTY / RAID the leader's group listing
		if type(a2) == "string" and a2:sub(1, 3) == "H1;" then
			local ok, err = pcall(L.receive, a2, a4)
			if not ok then L.stats.bad = L.stats.bad + 1 L.lastError = err end
		elseif type(a2) == "string" and a3 ~= "GUILD" and a2:sub(1, 1) == "G" and L.receiveGroup then
			local ok, err = pcall(L.receiveGroup, a2, a4)
			if not ok then L.stats.bad = L.stats.bad + 1 L.lastError = err end
		end
	end
end)

-- --------------------------------------------------------------------------------------------
-- Browse rows: one shape for every source (OpenGroup on another shard or yours, the game's Group
-- Finder, LFG chat), and the filtering, sorting, grouping and column layout Browse uses. Pure
-- functions (no frames), so tools/test.py can run them.

local function hasBit(bits, b) return (bits or 0) % (b * 2) >= b end

-- where: "other" (OpenGroup, another shard), "mine" (OpenGroup, your shard), "finder", "chat"
-- prefer(id): an optional test for the activity to show it under (the one the player filtered or
-- searched for), when a listing has several
function L.rowOf(l, myShard, prefer)
	local A, Q = OpenGroup_Activities, OpenGroup_Quests
	local r = { l = l, leader = l.leader or "?", class = l.class, level = l.level or 0, size = l.size or 1,
		need = l.need or 0, spots = l.spots, note = l.note or "", got = l.got or 0, shard = l.shard or 0, cat = l.cat or 0 }
	r.where = l.src == "finder" and "finder" or l.src == "chat" and "chat" or (l.shard == myShard and "mine" or "other")
	-- another shard's Group Finder group or LFG post, passed on by an OpenGroup player there
	r.remote = l.src == "remote" or l.src == "remotechat"
	r.gf, r.chatPost = l.src == "remote", l.src == "remotechat"
	r.kind = l.cat == P.SUMMON_CAT and "summon" or P.isBGQ(l.cat) and "bgq" or (r.size > 1 and "group" or "player")
	-- the activity: the one the player is looking for, else the first one we know; the level range
	-- covers all of them. actNames: every activity's name, for the search box
	local min, max, names, picked = nil, nil, {}, nil
	for _, id in ipairs(l.acts or {}) do
		local i = A and A.get and A.get(id)
		if i then
			r.act = r.act or id
			if not picked and prefer and prefer(id) then picked = id end
			names[#names + 1] = A.searchText and A.searchText(id) or (i.name or "")
			r.acts = r.acts or {}
			r.acts[#r.acts + 1] = id
			if prefer and prefer(id) then r.wanted = r.wanted or {} r.wanted[#r.wanted + 1] = id end
			if (i.min or 0) > 0 then min = math.min(min or i.min, i.min) end
			if (i.max or 0) > 0 then max = math.max(max or i.max, i.max) end
		end
	end
	if picked then r.act = picked end
	r.actNames = table.concat(names, " ")
	-- a chat post that named levels ("48-52", "50+") and no activity we know
	if not min and not max and (l.lmin or 0) > 0 then min, max = l.lmin, l.lmax or 60 end
	if (l.quest or 0) > 0 then
		local ql = Q and Q.level and Q.level(l.quest)
		if ql then min, max = ql, ql end
	end
	r.min, r.max = min or 0, max or 0
	r.title = L.titleOf(l)
	if r.kind == "summon" then r.groupKey, r.groupName = "summon", "Warlock Summons"
	elseif r.kind == "bgq" then r.groupKey, r.groupName = "bgq", "Battleground Queues"
	elseif r.act then r.groupKey, r.groupName = "a" .. r.act, (A and A.name(r.act)) or r.title
	else r.groupKey, r.groupName = "t" .. tostring(r.title):lower(), r.title end
	return r
end

-- Is it in the player's level band? An activity's range with 3 levels of slack either side; with
-- no range (custom, a quest not on our log, chat without a dungeon), the leader within 5 levels.
function L.inBand(r, lvl)
	if r.kind == "summon" then return true end
	if r.min > 0 or r.max > 0 then
		return (r.min == 0 or lvl >= r.min - 3) and (r.max == 0 or lvl <= r.max + 3)
	end
	return r.level == 0 or math.abs(r.level - lvl) <= 5
end

-- how far it is from the player's level (0 inside the range)
function L.levelDistance(r, lvl)
	if r.min > 0 or r.max > 0 then
		if r.min > 0 and lvl < r.min then return r.min - lvl end
		if r.max > 0 and lvl > r.max then return lvl - r.max end
		return 0
	end
	if r.level > 0 then return math.abs(r.level - lvl) end
	return 10
end

-- me = { class, level, roles (bits, 0 = by class), grouped, need (our listing's need bits) }
-- fit: we'd fill a spot or role in their group, or (as a leader) they bring a role we want.
-- dim: a group we can't join (full, or wanting nothing we play), shown last and greyed.
function L.rowFit(r, me)
	local roles = (me.roles and me.roles > 0) and me.roles or (P.CLASS_ROLES[me.class or ""] or 7)
	if r.kind == "group" and not me.grouped then
		if r.size >= 5 then return false, true end
		if type(r.spots) == "table" and #r.spots > 0 then
			local ok = P.bestSpot(r.spots, me.class, me.level, roles) ~= nil
			return ok, not ok
		end
		local want = r.need > 0 and r.need or 7
		for _, b in ipairs({ 1, 2, 4 }) do if hasBit(want, b) and hasBit(roles, b) then return true, false end end
		return false, true
	end
	if r.kind == "player" and me.grouped and (me.need or 0) > 0 then
		for _, b in ipairs({ 1, 2, 4 }) do if hasBit(me.need, b) and hasBit(r.need, b) then return true, false end end
	end
	return false, false
end

local WHERE_ORDER = { other = 1, mine = 2, finder = 3, chat = 4 }
function L.whereOK(r, where)
	if not where or where == "all" then return true end
	if where == "og" then return (r.where == "other" or r.where == "mine") and not r.remote end
	-- the Group Finder and LFG chat filters take in other shards' too
	if where == "finder" then return r.where == "finder" or r.gf == true end
	if where == "chat" then return r.where == "chat" or r.chatPost == true end
	return r.where == where
end

local function bits(n) local c = 0 for _, b in ipairs({ 1, 2, 4 }) do if hasBit(n, b) then c = c + 1 end end return c end
local function needCount(r) return (type(r.spots) == "table" and #r.spots > 0) and #r.spots or bits(r.need) end

-- relevance: groups we can't join last, then ones we fit, then nearest our level, then newest
local function relevance(a, b)
	if (a.dim or false) ~= (b.dim or false) then return not a.dim end
	if (a.fit or false) ~= (b.fit or false) then return a.fit == true end
	if a.dist ~= b.dist then return a.dist < b.dist end
	if a.got ~= b.got then return a.got > b.got end
	return a.leader < b.leader
end
L.SORT_KEYS = {
	lvl = function(r) return r.level end,
	leader = function(r) return r.leader:lower() end,
	act = function(r) return tostring(r.groupName or r.title):lower() end,
	levels = function(r) return r.min > 0 and r.min or 999 end,
	size = function(r) return r.size end,
	needs = function(r) return needCount(r) end,
	where = function(r) return WHERE_ORDER[r.where] * 100000 + (r.where == "other" and r.shard or 0) end,
	age = function(r) return -r.got end,
}
-- rows need dist (L.levelDistance) set; key nil = relevance
function L.sortRows(rows, key, desc)
	local f = key and L.SORT_KEYS[key]
	table.sort(rows, function(a, b)
		if f then
			local x, y = f(a), f(b)
			if x ~= y then if desc then return x > y end return x < y end
		end
		return relevance(a, b)
	end)
	return rows
end

-- by = "act" | "shard" | anything else (no groups). Returns { { key, text, rows, dist, min, max } }
-- in order: activities nearest our level first (then the busiest), shards in Where order.
function L.groupRows(rows, by)
	if by ~= "act" and by ~= "shard" then return nil end
	local groups, index = {}, {}
	local A = OpenGroup_Activities
	local expanded = rows
	if by == "act" then
		expanded = {}
		for _, r in ipairs(rows) do
			local ids = r.wanted or r.acts
			if r.kind ~= "summon" and r.kind ~= "bgq" and ids and (#ids > 1 or (r.wanted and #(r.acts or {}) > 1)) then
				for _, id in ipairs(ids) do
					local c = {}
					for k, v in pairs(r) do c[k] = v end
					local i = A and A.get(id)
					c.act, c.groupKey, c.groupName = id, "a" .. id, (A and A.name(id)) or r.groupName
					if i and (i.min or 0) > 0 then c.min, c.max = i.min, i.max end
					expanded[#expanded + 1] = c
				end
			else
				expanded[#expanded + 1] = r
			end
		end
	end
	for _, r in ipairs(expanded) do
		local key, text
		if by == "act" then key, text = r.groupKey, r.groupName
		else
			key = r.where == "other" and ("s" .. r.shard) or r.where
			text = r.where == "other" and (L.CHAN .. " " .. r.shard) or r.where == "mine" and "Your server" or r.where == "finder" and "Group Finder" or "LFG chat"
		end
		local g = index[key]
		if not g then
			g = { key = key, text = text, rows = {}, dist = r.dist or 0, min = r.min, max = r.max, order = (WHERE_ORDER[r.where] or 9) * 100000 + (r.where == "other" and r.shard or 0) }
			index[key] = g
			groups[#groups + 1] = g
		end
		g.rows[#g.rows + 1] = r
		if (r.dist or 0) < g.dist then g.dist = r.dist end
	end
	-- within each activity: groups first, then solo players (keeping the sort order otherwise)
	if by == "act" then
		for _, g in ipairs(groups) do
			local grp, solo = {}, {}
			for _, r in ipairs(g.rows) do if r.kind == "player" then solo[#solo + 1] = r else grp[#grp + 1] = r end end
			for _, r in ipairs(solo) do grp[#grp + 1] = r end
			g.rows = grp
		end
	end
	table.sort(groups, function(a, b)
		if by == "shard" then return a.order < b.order end
		if a.dist ~= b.dist then return a.dist < b.dist end
		if #a.rows ~= #b.rows then return #a.rows > #b.rows end
		return tostring(a.text) < tostring(b.text)
	end)
	return groups
end

-- Browse's saved settings, moved to the 0.6 ones: Where replaces "Other shards only" and "Group
-- Finder and chat"; Group by defaults to activity.
function L.migrateBrowse(db)
	if db.where == nil then
		db.where = db.otherOnly and "other" or (db.nearby == false and "og") or "all"
	end
	db.otherOnly = nil
	if db.groupBy == nil then db.groupBy = "act" end
	return db
end

-- Columns for a row this wide: { order = { {key, x, w}, ... }, at = { key = {x, w} } }. Activity takes
-- what's left; when that gets too small, Leader and Where shrink, then the least useful columns go
-- (Size, then Age, then Where).
L.COLUMNS = {
	{ key = "cls", w = 16 }, { key = "lvl", w = 22 }, { key = "leader", w = 112, min = 86 }, { key = "act", flex = true, min = 96 },
	{ key = "levels", w = 50 }, { key = "size", w = 30, drop = 1 }, { key = "needs", w = 74 },
	{ key = "where", w = 82, min = 66, drop = 3 }, { key = "age", w = 30, drop = 2 },
}
L.COL_GAP = 6
function L.columns(width)
	local cols, hidden = {}, {}
	for _, c in ipairs(L.COLUMNS) do cols[#cols + 1] = { key = c.key, w = c.w, min = c.min, flex = c.flex, drop = c.drop } end
	local function flexWidth()
		local used, n = 0, 0
		for _, c in ipairs(cols) do if not hidden[c.key] then n = n + 1 if not c.flex then used = used + c.w end end end
		return width - used - (n - 1) * L.COL_GAP
	end
	local actMin = 96
	if flexWidth() < actMin then for _, c in ipairs(cols) do if c.min and not c.flex then c.w = c.min end end end
	for step = 1, 3 do
		if flexWidth() >= actMin then break end
		for _, c in ipairs(cols) do if c.drop == step then hidden[c.key] = true end end
	end
	local out, at, x = {}, {}, 0
	local fw = math.max(40, flexWidth())
	for _, c in ipairs(cols) do
		if not hidden[c.key] then
			local w = c.flex and fw or c.w
			out[#out + 1] = { key = c.key, x = x, w = w }
			at[c.key] = { x = x, w = w }
			x = x + w + L.COL_GAP
		end
	end
	return { order = out, at = at, hidden = hidden }
end

-- --------------------------------------------------------------------------------------------
-- Whispers since login, for the Whispers tab: everyone, with the people OpenGroup links you to
-- (they're listed, you asked or invited them, or you whispered them from a row) marked and first.
-- The game can hand addons "secret" values during lockdown; those are never compared or shown,
-- only counted.

L.whispers = {}        -- [name] = { name, msgs = { { at, out, text | nil, hidden } }, unread, last }
L.whisperLinks = {}    -- [name] = true: whispered or asked from an OpenGroup row
L.whisperHidden = 0    -- messages the game didn't let us read
local MAX_MSGS, MAX_PEOPLE = 60, 60

local function readable(v)
	if canaccessvalue and not canaccessvalue(v) then return false end
	return v ~= nil
end

-- one whisper in or out; viewing = the player is looking at this conversation (no unread then)
function L.addWhisper(text, who, out, now, viewing)
	if not readable(who) or type(who) ~= "string" or who == "" then L.whisperHidden = L.whisperHidden + 1 return nil end
	local name = L.short(who)
	local c = L.whispers[name]
	if not c then
		c = { name = name, msgs = {}, unread = 0, last = now }
		L.whispers[name] = c
		-- keep the newest conversations
		local n, oldest = 0, nil
		for k, v in pairs(L.whispers) do n = n + 1 if not oldest or v.last < L.whispers[oldest].last then oldest = k end end
		if n > MAX_PEOPLE and oldest and oldest ~= name then L.whispers[oldest] = nil end
	end
	local hidden = not readable(text) or type(text) ~= "string"
	if hidden then L.whisperHidden = L.whisperHidden + 1 end
	c.msgs[#c.msgs + 1] = { at = now, out = out and true or false, text = (not hidden) and text or nil, hidden = hidden or nil }
	while #c.msgs > MAX_MSGS do table.remove(c.msgs, 1) end
	c.last = now
	if not out and not viewing then c.unread = c.unread + 1 end
	return c
end

-- Class and level for a name, for the Whispers tab: the class from the whisper's GUID (the game
-- gives it for anyone), the level from what OpenGroup already knows (a hello or listing), else the
-- party, friends, guild, or a /who already on hand. Never a /who of its own. Cached per name.
L.people = {}          -- [name] = { class = "WARRIOR", level = 52 }
local function readable2(v) return readable(v) end
function L.notePerson(name, guid)
	local p = L.people[name] or {}
	L.people[name] = p
	if not p.class and readable2(guid) and type(guid) == "string" and GetPlayerInfoByGUID then
		local ok, _, cls = pcall(GetPlayerInfoByGUID, guid)
		if ok and readable2(cls) and type(cls) == "string" and cls ~= "" then p.class = cls end
	end
	return p
end
local CLASS_OF = nil
local function classToken(localized)
	if type(localized) ~= "string" then return nil end
	if not CLASS_OF then
		CLASS_OF = {}
		for token, n in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do CLASS_OF[n] = token end
		for token, n in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do CLASS_OF[n] = token end
	end
	return CLASS_OF[localized] or (P.CLASS_ROLES[localized:upper()] and localized:upper()) or nil
end
function L.personInfo(name)
	local p = L.people[name] or {}
	L.people[name] = p
	local l = (L.listings and L.listings[name]) or (L.nearby and L.nearby[name])
	if l then
		if l.class and l.class ~= "" then p.class = l.class end
		if (l.level or 0) > 0 then p.level = l.level end
	end
	local peer = L.peers and L.peers[name]
	if peer and (peer.level or 0) > 0 then p.level = peer.level end
	if p.class and p.level then return p end
	-- the party or raid
	if IsInGroup and IsInGroup() then
		local raid = IsInRaid and IsInRaid()
		for i = 1, raid and 40 or 4 do
			local unit = (raid and "raid" or "party") .. i
			if UnitExists and UnitExists(unit) and L.short(L.unitName(unit) or "") == name then
				p.class = p.class or select(2, UnitClass(unit))
				local lv = UnitLevel(unit)
				if lv and lv > 0 then p.level = lv end
			end
		end
	end
	-- friends
	if not p.level and C_FriendList and C_FriendList.GetFriendInfo then
		local ok, f = pcall(C_FriendList.GetFriendInfo, name)
		if ok and type(f) == "table" and readable2(f.level) and (f.level or 0) > 0 then
			p.level = f.level
			p.class = p.class or classToken(f.className)
		end
	end
	-- the guild roster
	if not p.level and IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
		local n = GetNumGuildMembers() or 0
		for i = 1, math.min(n, 1000) do
			local ok, gname, _, _, lv, _, _, _, _, _, _, cls = pcall(GetGuildRosterInfo, i)
			if ok and type(gname) == "string" and L.short(gname) == name then
				if (lv or 0) > 0 then p.level = lv end
				if type(cls) == "string" and cls ~= "" then p.class = p.class or cls end
				break
			end
		end
	end
	-- a /who result already on hand
	if not p.level and C_FriendList and C_FriendList.GetNumWhoResults and C_FriendList.GetWhoInfo then
		local n = select(1, C_FriendList.GetNumWhoResults()) or 0
		for i = 1, math.min(n, 50) do
			local ok, w = pcall(C_FriendList.GetWhoInfo, i)
			if ok and type(w) == "table" and type(w.fullName) == "string" and L.short(w.fullName) == name then
				if (w.level or 0) > 0 then p.level = w.level end
				p.class = p.class or w.filename
				break
			end
		end
	end
	return p
end

-- "Level 52 Warrior", "Warrior" or ""
function L.personLine(name)
	local p = L.personInfo(name)
	local cls = p.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[p.class]) or (p.class:sub(1, 1) .. p.class:sub(2):lower())) or nil
	if p.level and cls then return ("Level %d %s"):format(p.level, cls) end
	if p.level then return "Level " .. p.level end
	return cls or ""
end

function L.whisperUnread()
	local n = 0
	for _, c in pairs(L.whispers) do n = n + (c.unread or 0) end
	return n
end

-- is OpenGroup how we know them? (a listing, a whisper or ask from a row, an auto invite)
function L.whisperLinked(name)
	if L.whisperLinks[name] or (L.listings and L.listings[name]) or (L.nearby and L.nearby[name]) then return true end
	local AI = OpenGroup_AutoInvite
	return AI and (AI.pending[name] or AI.joined[name] or AI.asks[name]) and true or false
end

-- the conversations, OpenGroup's first, then the newest; ogOnly leaves the rest out
function L.whisperList(ogOnly)
	local out = {}
	for name, c in pairs(L.whispers) do
		c.linked = L.whisperLinked(name)
		if (c.linked or not ogOnly) and not L.ignored(name) then out[#out + 1] = c end
	end
	table.sort(out, function(a, b)
		if a.linked ~= b.linked then return a.linked end
		if a.last ~= b.last then return a.last > b.last end
		return a.name < b.name
	end)
	return out
end

if CreateFrame then
	local wf = CreateFrame("Frame")
	wf:RegisterEvent("CHAT_MSG_WHISPER")
	wf:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
	L.whisperEvent = function(_, ev, text, who, ...)
		local guid = select(10, ...)
		local ok = pcall(function()
			local out = ev == "CHAT_MSG_WHISPER_INFORM"
			local viewing = L.whisperViewing and readable(who) and type(who) == "string" and L.short(who) == L.whisperViewing
			local c = L.addWhisper(text, who, out, time(), viewing)
			if c then L.notePerson(c.name, guid) end
			-- a whisper that went out: Find players marks that person as asked
			if c and out and L.onWhisperSent then pcall(L.onWhisperSent, c.name) end
		end)
		if ok and L.onWhisper then pcall(L.onWhisper) end
	end
	wf:SetScript("OnEvent", L.whisperEvent)
end

-- --------------------------------------------------------------------------------------------
-- Your party's listing: when the leader lists, changes or unlists the group, their OpenGroup tells
-- the party (a hidden addon message to PARTY or RAID), so members who run OpenGroup see it too: a
-- line in chat, the minimap button's listed light and the listing on the List tab (read only).
-- Only the current leader's messages count. A member who logs in or reloads asks for it.

L.groupListing = nil   -- { l = listing, leader = name, got = time } while our leader has the group listed
local GROUP_KEEP = 300
local lastTold = 0

local function groupChannel()
	if not (IsInGroup and IsInGroup()) then return nil end
	return (IsInRaid and IsInRaid()) and "RAID" or "PARTY"
end
local function amLeader() return UnitIsGroupLeader and UnitIsGroupLeader("player") and true or false end

-- the party's leader, by name (nil when not in a group)
function L.groupLeader()
	if not (IsInGroup and IsInGroup()) then return nil end
	if amLeader() then return L.me() end
	local raid = IsInRaid and IsInRaid()
	for i = 1, raid and 40 or 4 do
		local unit = (raid and "raid" or "party") .. i
		if UnitExists and UnitExists(unit) and UnitIsGroupLeader(unit) then return L.unitName(unit) end
	end
	return nil
end

-- what went to and came from the party, for /og status
L.groupStats = { sent = 0, got = 0, ignored = 0 }
local function sendGroup(msg)
	local ch = groupChannel()
	if not ch or not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
	local ok, res = pcall(C_ChatInfo.SendAddonMessage, P.PREFIX, msg, ch)
	L.groupStats.sent = L.groupStats.sent + 1
	L.groupStats.lastSent = msg:sub(1, 2) .. " to " .. ch .. " (" .. (ok and tostring(res) or "error") .. ")"
	return true
end

-- the leader's side: tell the party what we're listed for (or that we're not). force = now,
-- otherwise at most once a minute (the regular re-announce)
function L.tellGroup(force)
	if not groupChannel() or not amLeader() then return end
	if not force and GetTime() - lastTold < 60 then return end
	lastTold = GetTime()
	local m = L.mine
	if m and GetNumGroupMembers() > 1 then sendGroup(P.groupListing(L.mineForSend()))
	else sendGroup(P.groupUnlisted(OpenGroupDB and OpenGroupDB.seq or 0)) end
end

local function clearGroup(say)
	if not L.groupListing then return end
	L.groupListing = nil
	if say then L.print("your group is no longer listed.") end
	if L.onGroupListing then pcall(L.onGroupListing) end
	if L.onChange then L.onChange() end
end
L.clearGroupListing = clearGroup

-- the member's side: a message from the party channel
function L.receiveGroup(msg, sender)
	if type(sender) ~= "string" or L.isMe(sender) then return end
	local kind, d = P.parse(msg)
	if kind == "GQ" then
		if amLeader() then L.tellGroup(true) end
		return
	end
	if kind ~= "G1" and kind ~= "G0" then return end
	-- only the current leader speaks for the group
	local leader = L.groupLeader()
	if not leader or L.short(leader) ~= L.short(sender) then
		L.groupStats.ignored = L.groupStats.ignored + 1
		L.groupStats.lastIgnored = ("%s from %s (leader is %s)"):format(kind, L.short(sender), tostring(leader))
		return
	end
	L.groupStats.got = L.groupStats.got + 1
	if kind == "G0" then clearGroup(true) return end
	local first = L.groupListing == nil or L.groupListing.leader ~= L.short(sender)
	d.got = now()
	L.groupListing = { l = d, leader = L.short(sender), got = now(), at = (not first and L.groupListing.at) or now() }
	if first then
		L.print(("your group is listed for %s."):format(L.titleOf(d)))
		if OpenGroup_Alert then
			pcall(OpenGroup_Alert.show, { head = "OpenGroup", small = "Your group", name = "Listed for " .. L.titleOf(d), icon = L.ICON, quiet = true })
		end
	end
	if L.onGroupListing then pcall(L.onGroupListing) end
	if L.onChange then L.onChange() end
end

-- send it when the leader lists, changes or unlists, and with the regular re-announce
do
	local post, setNeed, setSpots, delist, announce = L.post, L.setNeed, L.setSpots, L.delist, L.announce
	L.post = function(...) local ok = post(...) if ok then L.tellGroup(true) end return ok end
	L.setNeed = function(...) setNeed(...) L.tellGroup(true) end
	L.setSpots = function(...) setSpots(...) L.tellGroup(true) end
	L.delist = function(...) local had = L.mine ~= nil delist(...) if had then L.tellGroup(true) end end
	L.announce = function(...) announce(...) L.tellGroup(false) end
end

if CreateFrame then
	local gf = CreateFrame("Frame")
	local members, leaderNow = 0, nil
	gf:RegisterEvent("GROUP_ROSTER_UPDATE")
	gf:RegisterEvent("PARTY_LEADER_CHANGED")
	gf:RegisterEvent("PLAYER_ENTERING_WORLD")
	local expiry
	gf:SetScript("OnEvent", function(_, ev)
		-- no word from the leader for 5 minutes: it's gone (checked from login on)
		if ev == "PLAYER_ENTERING_WORLD" and not expiry and C_Timer and C_Timer.NewTicker then
			expiry = C_Timer.NewTicker(15, function()
				if L.groupListing and now() - L.groupListing.got > GROUP_KEEP then clearGroup(true) end
			end)
		end
		local n = (IsInGroup and IsInGroup()) and GetNumGroupMembers() or 0
		local leader = L.groupLeader()
		if n == 0 then
			clearGroup(L.groupListing ~= nil)
		elseif ev == "PLAYER_ENTERING_WORLD" then
			-- logged in or reloaded in a group: ask the leader what's listed
			if not amLeader() and C_Timer then C_Timer.After(5, function() sendGroup(P.groupAsk()) end) end
		else
			-- the leader changed: what members held is gone; a new leader with OpenGroup keeps it listed
			if leaderNow and leader and L.short(leader) ~= L.short(leaderNow) then
				local held = L.groupListing
				clearGroup(held ~= nil and not amLeader())
				if amLeader() and held and not L.mine then
					local l = held.l
					L.post(l.title, l.note, l.need, l.cat, l.acts, l.price, l.quest, l.spots)
					L.print("you lead the group now, so OpenGroup keeps it listed under your name.")
				elseif not amLeader() and L.mine and n > 1 then
					-- we handed the lead on: the new leader lists it now
					L.delist()
				end
			end
			-- someone joined while we're listed: tell them
			if amLeader() and n > members then L.tellGroup(true) end
		end
		members, leaderNow = n, leader
	end)
end

-- --------------------------------------------------------------------------------------------
-- Find players: the /who search for an open spot. Pure, for tests.

-- the classes that can fill a role (P.TANK / HEALER / DAMAGE; 0 = any) on a faction
function L.roleClasses(role, faction)
	local out = {}
	for _, cls in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
		local bits = P.CLASS_ROLES[cls] or 0
		local fits = role == 0 or role == nil or (bits % (role * 2) >= role)
		local onFaction = not ((cls == "PALADIN" and faction == "Horde") or (cls == "SHAMAN" and faction == "Alliance"))
		if fits and onFaction then out[#out + 1] = cls end
	end
	return out
end

-- q = { class (localized name or nil), min, max, zone, race, name } -> the /who text
function L.whoQuery(q)
	local parts = {}
	local function quoted(prefix, v)
		v = type(v) == "string" and v:gsub('"', ""):gsub("^%s+", ""):gsub("%s+$", "") or ""
		if v ~= "" then parts[#parts + 1] = ('%s-"%s"'):format(prefix, v) end
	end
	quoted("n", q.name)
	quoted("c", q.class)
	quoted("r", q.race)
	quoted("z", q.zone)
	local lo, hi = P.int(q.min, 1, 200), P.int(q.max, 1, 200)
	if lo and hi then
		if lo > hi then lo, hi = hi, lo end
		parts[#parts + 1] = lo == hi and tostring(lo) or (lo .. "-" .. hi)
	elseif lo or hi then
		parts[#parts + 1] = tostring(lo or hi)
	end
	return table.concat(parts, " ")
end

-- players around you (L.noteNearby, L.nearTick above)
if CreateFrame then
	local nf = CreateFrame("Frame")
	for _, ev in ipairs({ "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED" }) do pcall(nf.RegisterEvent, nf, ev) end
	nf:SetScript("OnEvent", function(_, ev, unit) pcall(L.noteNearby, ev == "UPDATE_MOUSEOVER_UNIT" and "mouseover" or unit) end)
end

