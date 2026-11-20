-- OpenGroup core: who we know, what's listed, and the hidden-whisper traffic between OpenGroup users.
local P = OpenGroup_Proto
local L = {}
OpenGroup = L

L.VERSION = P.VERSION
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
local PX_SEND = 8                 -- names to share in a peer exchange
local PX_PROBE = 8                -- hellos to send per peer exchange we receive

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

function L.me() return (UnitName("player")) end

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
	return #acts > 0 and (#acts .. " activities") or "?"
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
	for name, p in pairs(src) do list[#list + 1] = { name, p.seen or 0 } end
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

local function sharePeers(to, toShard)
	local msg = P.peerList(shareList(to, toShard, PX_SEND))
	if msg then L.send(to, msg) end
end

local function notePeerVersion(v)
	local n = P.versionNumber(v)
	if not n then return end
	local mine = P.versionNumber(L.VERSION) or 0
	if n > mine and n > (P.versionNumber(L.newest) or 0) then
		L.newest = v
		if not L.toldNewer then
			L.toldNewer = true
			L.print(("a newer OpenGroup (%s) is out; you have %s. Update when you can."):format(v, L.VERSION))
		end
	end
end

local function store(l, via)
	local fresh = L.listings[l.leader] == nil
	l.got = now() - (l.age or 0)
	l.via = via
	L.listings[l.leader] = l
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

function L.receive(msg, sender)
	if L.isMe(sender) then return end
	local kind, d = P.parse(msg)
	if not kind then L.stats.bad = L.stats.bad + 1 return end
	L.stats.got = L.stats.got + 1
	if kind == "H1" then
		local isNew = L.peers[sender] == nil
		L.addPeer(sender, d.shard, d.level, d.version)
		notePeerVersion(d.version)
		L.send(sender, P.answer(L.shard(), UnitLevel("player")))
		if L.mine then L.send(sender, P.listing(L.mineForSend())) end
		sendKnown(sender, 5)
		sharePeers(sender, d.shard)
		if isNew and L.onPeer then L.onPeer(sender) end
	elseif kind == "A1" then
		local isNew = L.peers[sender] == nil
		L.addPeer(sender, d.shard, d.level, d.version)
		notePeerVersion(d.version)
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
			L.print(("ping to %s came back from shard %d in %.1fs: hidden whispers reach them."):format(
				L.short(sender), d.shard, GetTime() - p.at))
			L.pings[d.token] = nil
		end
		L.addPeer(sender, d.shard)
	elseif kind == "L1" then
		L.peers[sender] = L.peers[sender] or { shard = 0, level = 0 }
		L.peers[sender].seen = now()
		if L.isMe(d.leader) then return end
		-- the leader's own message: whisper the name the game gave us, it's the reliable spelling
		if d.hops == 0 then d.leader = sender end
		local held = L.listings[d.leader]
		if P.isNewer(held, d) or P.isRefresh(held, d, now()) then
			store(d, sender)
			relay(d, sender)
		end
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
		title = m.title, note = m.note }
end

local announceAt = 1
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
function L.post(title, note, need, cat, acts, price, quest)
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
	L.mine = { title = title, note = P.clean(note or "", P.NOTE_LEN), need = P.int(need, 0, 7) or 0,
		cat = P.int(cat, 0, 99999) or 0, acts = ids, price = P.int(price, 0, P.MAX_PRICE) or 0, quest = quest,
		seq = OpenGroupDB.seq, at = first and now() or L.mine.at }
	if L.onListed then L.onListed(first) end
	L.announce()
	if first then
		L.print(("listed \"%s\" to %d OpenGroup users (shard %d)."):format(L.titleOf(L.mine), math.min(ANNOUNCE_PEERS, L.count(L.peers)), L.shard()))
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
		if L.short(peer) == short then p.off = now() end
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
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
f:SetScript("OnEvent", function(_, ev, a1, a2, a3, a4, ...)
	if ev == "CHAT_MSG_CHANNEL" or ev == "CHAT_MSG_CHANNEL_NOTICE" then
		-- arg4 is the channel's full name ("2. Trade 47"), arg9 its base name: a trailing number from either
		local a9 = select(5, ...)
		for _, name in ipairs({ a4, a9 }) do
			if isShardChannel(name) then
				local n = P.shardFromChannel(name)
				if n then L.shardSeen, L.shardSeenFrom = n, tostring(name) return end
			end
		end
		return
	end
	if ev == "GROUP_ROSTER_UPDATE" then
		L.seedGroup()
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
		-- only hellos travel on these; the answer goes back as a whisper like any other
		if type(a2) == "string" and a2:sub(1, 3) == "H1;" then
			local ok, err = pcall(L.receive, a2, a4)
			if not ok then L.stats.bad = L.stats.bad + 1 L.lastError = err end
		end
	end
end)
