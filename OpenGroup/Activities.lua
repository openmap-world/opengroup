-- Dungeons and the rest, straight from the game's Group Finder data (C_LFGList), so names
-- come out in the player's own language and every client agrees on the ids. A built-in list of
-- classic dungeons stands in when the client has no Group Finder data.
local A = {}
OpenGroup_Activities = A

local FALLBACK = {
	{ id = -1, name = "Dungeons", acts = {
		"Ragefire Chasm", "Wailing Caverns", "The Deadmines", "Shadowfang Keep", "Blackfathom Deeps",
		"The Stockade", "Gnomeregan", "Razorfen Kraul", "Scarlet Monastery", "Razorfen Downs",
		"Uldaman", "Zul'Farrak", "Maraudon", "Sunken Temple", "Blackrock Depths",
		"Lower Blackrock Spire", "Upper Blackrock Spire", "Dire Maul", "Scholomance", "Stratholme" } },
	{ id = -3, name = "Custom", acts = {} },
}

A.categories = nil   -- { { id, name, acts = { activityID... } } }
A.info = {}          -- [activityID] = { id, name, short, min, max, cat }

local function api() return C_LFGList and C_LFGList.GetAvailableCategories and C_LFGList.GetAvailableActivities end

function A.load()
	if A.categories then return A.categories end
	local cats = {}
	if api() then
		local ok, ids = pcall(C_LFGList.GetAvailableCategories)
		for _, cid in ipairs(ok and type(ids) == "table" and ids or {}) do
			local okI, ci = pcall(C_LFGList.GetLfgCategoryInfo, cid)
			local okA, acts = pcall(C_LFGList.GetAvailableActivities, cid)
			if okI and type(ci) == "table" and okA and type(acts) == "table" then
				local c = { id = cid, name = ci.name or ("Category " .. cid), acts = {} }
				for _, aid in ipairs(acts) do
					local okT, t = pcall(C_LFGList.GetActivityInfoTable, aid)
					if okT and type(t) == "table" and type(t.fullName) == "string" then
						A.info[aid] = { id = aid, name = t.fullName, short = (t.shortName ~= "" and t.shortName) or t.fullName,
							min = t.minLevelSuggestion or t.minLevel or 0, max = t.maxLevelSuggestion or t.maxLevel or 0, cat = cid }
						c.acts[#c.acts + 1] = aid
					end
				end
				-- highest level first, as the game's own list orders them
				table.sort(c.acts, function(a, b)
					local x, y = A.info[a], A.info[b]
					if x.min ~= y.min then return x.min > y.min end
					if x.max ~= y.max then return x.max > y.max end
					return x.name < y.name
				end)
				-- a category with nothing in it yet (Forever has no raids open) is left out; Custom
				-- has no activities by design and stays
				if #c.acts > 0 or tostring(c.name):lower():find("custom") then cats[#cats + 1] = c end
			end
		end
	end
	if #cats == 0 then
		-- no Group Finder data: the built-in list, negative ids that never go on the wire
		local n = 0
		for _, fc in ipairs(FALLBACK) do
			local c = { id = fc.id, name = fc.name, acts = {}, fallback = true }
			for _, name in ipairs(fc.acts) do
				n = n - 1
				A.info[n] = { id = n, name = name, short = name, min = 0, max = 0, cat = fc.id }
				c.acts[#c.acts + 1] = n
			end
			cats[#cats + 1] = c
		end
	end
	-- warlock summons: our own category, no activities, always last
	cats[#cats + 1] = { id = OpenGroup_Proto.SUMMON_CAT, name = "Warlock Summons", acts = {}, summon = true }
	A.categories = cats
	return cats
end

function A.category(id)
	for _, c in ipairs(A.load()) do if c.id == id then return c end end
end

-- Places people pay to be summoned to (typed suggestions for the warlock form; any text works)
A.SUMMON_SPOTS = {
	"Blackrock Mountain", "Dire Maul", "Stratholme", "Scholomance", "Zul'Gurub", "Molten Core",
	"Onyxia's Lair", "Blackwing Lair", "Ahn'Qiraj", "Naxxramas", "Winterspring", "Silithus",
	"Felwood", "Un'Goro Crater", "Eastern Plaguelands", "Western Plaguelands", "Burning Steppes",
	"Searing Gorge", "Azshara", "Feralas", "Tanaris", "Stranglethorn Vale", "Badlands", "Desolace",
	"Orgrimmar", "Undercity", "Thunder Bluff", "Stormwind City", "Ironforge", "Darnassus",
	"Booty Bay", "Gadgetzan", "Everlook", "Cenarion Hold",
}
function A.spots(text)
	text = (text or ""):lower()
	local out = {}
	local here = GetZoneText and GetZoneText() or nil
	if here and here ~= "" and (text == "" or here:lower():find(text, 1, true)) then out[#out + 1] = here end
	for _, s in ipairs(A.SUMMON_SPOTS) do
		if #out >= 8 then break end
		if s ~= here and (text == "" or s:lower():sub(1, #text) == text or s:lower():find(text, 1, true)) then out[#out + 1] = s end
	end
	return out
end

function A.name(id) local i = A.info[id] return i and i.name end

-- "Blackrock Depths", "BRD", "black" all find Blackrock Depths. Initials count too.
local function initials(s)
	local out = ""
	for w in s:gmatch("[%w']+") do if w:lower() ~= "the" and w:lower() ~= "of" then out = out .. w:sub(1, 1) end end
	return out:lower()
end

-- Activities matching typed text, best first: prefix of the name, initials, then anywhere.
function A.search(text, catID, max)
	A.load()
	text = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local scored = {}
	for id, i in pairs(A.info) do
		if not catID or i.cat == catID then
			local name = i.name:lower()
			local score
			if text == "" then score = 3
			elseif name:sub(1, #text) == text or i.short:lower():sub(1, #text) == text then score = 0
			elseif initials(i.name) == text or initials(i.name):sub(1, #text) == text then score = 1
			elseif name:find(text, 1, true) then score = 2 end
			if score then scored[#scored + 1] = { id = id, s = score, min = i.min, name = i.name } end
		end
	end
	table.sort(scored, function(a, b)
		if a.s ~= b.s then return a.s < b.s end
		if a.min ~= b.min then return a.min < b.min end
		return a.name < b.name
	end)
	local out = {}
	for k = 1, math.min(max or 8, #scored) do out[k] = scored[k].id end
	return out
end

-- Is the activity right for this level? (the suggested range, when there is one)
function A.fits(id, level)
	local i = A.info[id]
	if not i then return true end
	return not ((i.min > 0 and level < i.min - 3) or (i.max > 0 and level > i.max + 3))
end

-- The Group Finder's colouring: by the activity's lowest suggested level against yours
-- (red / orange / yellow / green / grey), using the game's quest difficulty colours.
function A.levelColor(id, level)
	local i = A.info[id]
	if not i or (i.min or 0) <= 0 then return "|cffffd100" end
	local c = GetQuestDifficultyColor and GetQuestDifficultyColor(i.min)
	if c then return ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) end
	local d = i.min - (level or 1)
	if d >= 5 then return "|cffff1a1a" elseif d >= 3 then return "|cffff8040" elseif d >= -2 then return "|cffffff00"
	elseif d >= -8 then return "|cff40c040" end
	return "|cff808080"
end

function A.range(id)
	local i = A.info[id]
	if not i or (i.min or 0) <= 0 or (i.max or 0) <= 0 then return "" end
	return ("(%d - %d)"):format(i.min, i.max)
end

function A.label(id)
	local i = A.info[id]
	if not i then return "?" end
	if i.min > 0 and i.max > 0 and i.max ~= i.min then return ("%s  |cff8f8f8f%d-%d|r"):format(i.name, i.min, i.max) end
	return i.name
end
