-- Finding other OpenGroup users: /who reaches every shard, 50 names per search. The game only answers
-- an addon's /who from a click, so each click of Scan asks one level band, then the names it got
-- that we don't know yet get a hidden hello. Only OpenGroup users answer.
local L = OpenGroup
local S = {}
L.scan = S

-- bands around the player's level first, then the rest
local function bands()
	local lvl = UnitLevel("player") or 60
	local out, seen = {}, {}
	local function add(lo, hi)
		lo, hi = math.max(1, lo), math.min(60, hi)
		if lo > hi then return end
		local key = lo .. "-" .. hi
		if not seen[key] then seen[key] = true out[#out + 1] = key end
	end
	add(lvl - 2, lvl + 2)
	add(lvl - 5, lvl - 3); add(lvl + 3, lvl + 5)
	for lo = 1, 60, 5 do add(lo, lo + 4) end
	return out
end

S.band = 0
S.inFlight = nil
S.muted = {}

-- The game's own who lists pop their window on any answer; keep them out of it while ours is out,
-- unless the player has one open. (Same approach as LayerSwap.)
local LISTS = { "LFGWhoListFrame", "FriendsFrame" }
local function hush()
	for _, name in ipairs(LISTS) do
		local fr = _G[name]
		if type(fr) == "table" and fr.IsEventRegistered and not S.muted[name] then
			local okR, reg = pcall(fr.IsEventRegistered, fr, "WHO_LIST_UPDATE")
			local okV, vis = pcall(fr.IsVisible, fr)
			if okR and reg and okV and not vis and pcall(fr.UnregisterEvent, fr, "WHO_LIST_UPDATE") then S.muted[name] = fr end
		end
	end
end

local function release()
	S.inFlight = nil
	for name, fr in pairs(S.muted) do pcall(fr.RegisterEvent, fr, "WHO_LIST_UPDATE") S.muted[name] = nil end
	if C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, false) end
end

-- call from a button click only
function S.click()
	if S.inFlight then return end
	if InCombatLockdown and InCombatLockdown() then UIErrorsFrame:AddMessage("OpenGroup searches after combat.", 1, .82, 0) return end
	S.last = GetTime()
	local list = bands()
	S.band = S.band % #list + 1
	S.total = #list
	local query = list[S.band]
	hush()
	if C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, true) end
	local origin = (Enum and Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Social) or 1
	-- called directly and once: through pcall the game can't name it if it's refused, and a
	-- second try in the same click would be refused anyway
	S.whoAt = GetTime()
	C_FriendList.SendWho(query, origin)
	S.inFlight = { query = query, at = GetTime() }
	S.status = ("Searching levels %s..."):format(query)
	C_Timer.After(8, function() if S.inFlight then release() S.status = "No answer from the game, click again" if L.onChange then L.onChange() end end end)
	if L.onChange then L.onChange() end
end

-- Any click in OpenGroup (Refresh, a tab, List Group, the minimap button) may run the next search
-- quietly, at most every 45 seconds, so the network grows while people simply use the window.
-- The Group Finder search and /who are both allowed only inside a click, and the game refuses a
-- second one in the same click, so a click runs one of them at most. fromClick: the Group Finder
-- search may run (Refresh and the minimap button only); force: Refresh's shorter wait.
-- explicit: the player clicked Search (may retry after a refusal); catID: the category to search.
-- Without force, the Group Finder is only searched when its results are stale (2 minutes).
-- (0.6.3: no more searches piggybacked on other clicks. The game's taint log named the /who run
-- from a tab click; /who now only runs from Settings' Search now and Find players' Search, and the
-- Group Finder search only from Browse's Search Group Finder button.)
function S.auto(fromClick, force, explicit, catID)
	if InCombatLockdown and InCombatLockdown() then return false end
	if not explicit then return false end
	local N = OpenGroup_Nearby
	return (fromClick and N and N.search(force, explicit, catID)) and true or false
end

-- the player's own /who searches: the names in them are worth a hello too (a few per search)
local function harvest()
	local n = select(1, C_FriendList.GetNumWhoResults()) or 0
	local probed = 0
	for i = 1, math.min(n, 50) do
		if probed >= 15 then break end
		local ok, info = pcall(C_FriendList.GetWhoInfo, i)
		local name = ok and type(info) == "table" and info.fullName
		if type(name) == "string" and name ~= "" and L.probe(name, "who") then probed = probed + 1 end
	end
end

-- Find players: one /who of the player's own (from a click), its results handed back instead of
-- probed. The game's /who window is kept shut the same way as for the background search.
function S.find(query, onResults)
	if S.inFlight then return false end
	if InCombatLockdown and InCombatLockdown() then return false end
	S.last = GetTime()
	hush()
	if C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, true) end
	local origin = (Enum and Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Social) or 1
	local mine = { query = query, at = GetTime(), find = onResults }
	S.inFlight = mine
	S.whoAt = GetTime()
	C_FriendList.SendWho(query, origin)
	C_Timer.After(8, function() if S.inFlight == mine then release() pcall(onResults, nil) end end)
	return true
end

local function results()
	if not S.inFlight then harvest() return end
	if S.inFlight.find then
		local cb = S.inFlight.find
		-- shown (at most 50) and how many matched in all
		local shown, total = C_FriendList.GetNumWhoResults()
		local n = shown or 0
		local list = {}
		for i = 1, math.min(n, 50) do
			local ok, info = pcall(C_FriendList.GetWhoInfo, i)
			if ok and type(info) == "table" and type(info.fullName) == "string" and info.fullName ~= "" then list[#list + 1] = info end
		end
		release()
		pcall(cb, list, math.max(n, total or 0))
		return
	end
	local q = S.inFlight
	local n = select(1, C_FriendList.GetNumWhoResults()) or 0
	local probed = 0
	for i = 1, math.min(n, 50) do
		local ok, info = pcall(C_FriendList.GetWhoInfo, i)
		local name = ok and type(info) == "table" and info.fullName
		if type(name) == "string" and name ~= "" and L.probe(name, "search") then probed = probed + 1 end
	end
	release()
	S.found = (S.found or 0) + n
	S.status = ("Levels %s: %d players, %d new hellos"):format(q.query, n, probed)
	if L.onChange then L.onChange() end
end

local f = CreateFrame("Frame")
f:RegisterEvent("WHO_LIST_UPDATE")
f:SetScript("OnEvent", results)
S.onWhoList = results   -- for tests
