-- Quests: the player's quest log, quest links, and shift-clicking a quest into OpenGroup.
local Q = {}
OpenGroup_Quests = Q

-- { { id, title, level } } from the quest log (the Mainline API where the client has it, else the
-- classic one)
function Q.log()
	local out = {}
	if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
		local n = C_QuestLog.GetNumQuestLogEntries() or 0
		for i = 1, n do
			local ok, info = pcall(C_QuestLog.GetInfo, i)
			if ok and type(info) == "table" and not info.isHeader and info.questID and info.title then
				out[#out + 1] = { id = info.questID, title = info.title, level = info.level or 0 }
			end
		end
	elseif GetNumQuestLogEntries and GetQuestLogTitle then
		local n = GetNumQuestLogEntries() or 0
		for i = 1, n do
			local title, level, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
			if title and not isHeader and questID then out[#out + 1] = { id = questID, title = title, level = level or 0 } end
		end
	end
	return out
end

-- the quest's level when it's on our log; nil otherwise
function Q.level(id)
	for _, q in ipairs(Q.log()) do if q.id == id then return (q.level or 0) > 0 and q.level or nil end end
	return nil
end

function Q.onLog(id)
	if not id or id <= 0 then return false end
	if C_QuestLog and C_QuestLog.IsOnQuest then
		local ok, on = pcall(C_QuestLog.IsOnQuest, id)
		if ok then return on == true end
	end
	for _, q in ipairs(Q.log()) do if q.id == id then return true end end
	return false
end

-- the quest's name in this client's language when we can find it; nil otherwise
function Q.name(id)
	if C_QuestLog and C_QuestLog.GetTitleForQuestID then
		local ok, t = pcall(C_QuestLog.GetTitleForQuestID, id)
		if ok and type(t) == "string" and t ~= "" then return t end
	end
	for _, q in ipairs(Q.log()) do if q.id == id then return q.title end end
	return nil
end

-- the quest's objectives from the log: { { text = "0/1 Curled Mask", done = false } }
function Q.objectives(id)
	local out = {}
	if not id or id <= 0 then return out end
	if C_QuestLog and C_QuestLog.GetQuestObjectives then
		local ok, objs = pcall(C_QuestLog.GetQuestObjectives, id)
		if ok and type(objs) == "table" then
			for _, o in ipairs(objs) do
				if type(o) == "table" and type(o.text) == "string" and o.text ~= "" then out[#out + 1] = { text = o.text, done = o.finished == true } end
			end
		end
	end
	if #out == 0 and GetQuestLogIndexByID and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
		local okI, idx = pcall(GetQuestLogIndexByID, id)
		if okI and idx and idx > 0 then
			for i = 1, (GetNumQuestLeaderBoards(idx) or 0) do
				local text, _, done = GetQuestLogLeaderBoard(i, idx)
				if text then out[#out + 1] = { text = text, done = done and true or false } end
			end
		end
	end
	return out
end

-- "|cffffff00|Hquest:123:45|h[Name]|h|r" -> id, level, name
function Q.fromLink(link)
	if type(link) ~= "string" then return nil end
	local id, level, name = link:match("|Hquest:(%d+):?(%-?%d*)[^|]*|h%[(.-)%]|h")
	if not id then return nil end
	return tonumber(id), tonumber(level) or 0, name
end

-- Shift-clicks. The game hands a quest link to the chat box (when one is open) and toggles quest
-- tracking (when none is). Both are watched, never replaced; while the OpenGroup window is open the
-- quest goes to Q.onPick.
Q.onPick = nil
local function pick(id, title, level)
	if not Q.onPick or not id then return end
	if not (OpenGroupFrame and OpenGroupFrame:IsShown()) then return end
	title = title or Q.name(id)
	if not title then return end
	Q.onPick({ id = id, title = title, level = level or 0 })
end

local recent = 0
local function once(fn)
	-- one shift-click can fire more than one of the hooks; take the first
	if GetTime() - recent < 0.2 then return end
	recent = GetTime()
	fn()
end

if ChatEdit_InsertLink then
	hooksecurefunc("ChatEdit_InsertLink", function(link)
		local id, level, name = Q.fromLink(link)
		if id then once(function() pick(id, name, level) end) end
	end)
end
local function watchHook(arg)
	once(function()
		local id = arg
		if GetQuestLogTitle and type(arg) == "number" and arg < 1000 and not (C_QuestLog and C_QuestLog.GetInfo) then
			local _, _, _, _, _, _, _, questID = GetQuestLogTitle(arg)   -- classic passes the log index
			id = questID
		end
		if type(id) == "number" and id > 0 then pick(id) end
	end)
end
for _, fname in ipairs({ "AddQuestWatch", "RemoveQuestWatch" }) do
	if _G[fname] then hooksecurefunc(fname, watchHook) end
end
if C_QuestLog then
	for _, fname in ipairs({ "AddQuestWatch", "RemoveQuestWatch" }) do
		if C_QuestLog[fname] then hooksecurefunc(C_QuestLog, fname, watchHook) end
	end
end
