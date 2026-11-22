import sys, os
from lupa.lua51 import LuaRuntime
D=sys.argv[1]
lua=LuaRuntime()
lua.execute(r'''
CLOCK=1000
function time() return CLOCK end
function GetTime() return CLOCK end
function UnitName() return "Ann A" end
function UnitLevel() return 58 end
function UnitClass() return "Warlock","WARLOCK" end
function UnitFactionGroup() return "Horde" end
function UnitIsPlayer() return true end
function GetNumGroupMembers() return 0 end
function GetChannelList() return 1, "Trade 47", false end
function strjoin(sep, ...) return table.concat({...}, sep) end
function tostringall(...) return ... end
DEFAULT_CHAT_FRAME={AddMessage=function(_,m) print("CHAT",m) end}
TICKERS={}
C_Timer={NewTicker=function(s,f) TICKERS[#TICKERS+1]=f end, After=function() end}
C_ChatInfo={RegisterAddonMessagePrefix=function() end, SendAddonMessage=function() return 0 end, SendChatMessage=function(...) print("WHISPER", ...) end}
C_Texture={GetAtlasInfo=function() return {} end}
C_AddOns={IsAddOnLoaded=function() return false end}
function GetChannelName() return 0 end
C_LFGList={GetAvailableCategories=function() return {2,4,6} end,
  GetLfgCategoryInfo=function(id) return {name= id==2 and "Dungeons" or id==4 and "PvP" or "Custom"} end,
  GetAvailableActivities=function(id) if id==2 then return {30,31,32} end if id==4 then return {40} end return {} end,
  GetActivityInfoTable=function(id) return ({[30]={fullName="Blackrock Depths",shortName="BRD",minLevelSuggestion=52,maxLevelSuggestion=60},[31]={fullName="Stratholme",shortName="",minLevelSuggestion=58,maxLevelSuggestion=60},[32]={fullName="Ragefire Chasm",shortName="RFC",minLevelSuggestion=13,maxLevelSuggestion=18},[40]={fullName="Warsong Gulch",shortName="WSG",minLevelSuggestion=10,maxLevelSuggestion=60}})[id] end}
C_FriendList={SendWho=function() end, SetWhoToUi=function() end, GetNumWhoResults=function() return 0,0 end}
RAID_CLASS_COLORS={WARRIOR={colorStr="ffc79c6e"}}
UISpecialFrames={} SlashCmdList={} SOUNDKIT={} function PlaySound() return true end function hooksecurefunc() end function GetZoneText() return 'Felwood' end function GetSubZoneText() return '' end C_QuestLog={GetNumQuestLogEntries=function() return 2 end, GetInfo=function(i) return ({{questID=1234,title='The Missing Diplomat',level=30},{isHeader=true,title='Zone'}})[i] end, IsOnQuest=function(id) return id==1234 end} function EnumerateFrames() return nil end function unpack2() end
function tinsert(t,v) table.insert(t,v) end
function ChatFrame_AddMessageEventFilter() end
function GameTooltip_Hide() end
UIErrorsFrame={AddMessage=function(_,m) print("ERR",m) end}
local mock
local function callable() return setmetatable({}, {__call=function() return mock() end, __index=function(t,k) local m=mock() rawset(t,k,m) return m end}) end
function mock(kind)
  local o = {scripts={}, shown=(kind~="win"), text=""}
  return setmetatable(o, {__call=function() return mock() end, __index=function(t,k)
    if k=="SetScript" then return function(self,n,f) self.scripts[n]=f end end
    if k=="HookScript" then return function(self,n,f) self.scripts[n]=f end end
    if k=="GetScript" then return function(self,n) return self.scripts[n] end end
    if k=="IsShown" then return function(self) return self.shown end end
    if k=="Show" then return function(self) self.shown=true if self.scripts.OnShow then self.scripts.OnShow(self) end end end
    if k=="Hide" then return function(self) self.shown=false end end
    if k=="SetShown" then return function(self,v) if v then self:Show() else self:Hide() end end end
    if k=="GetText" then return function(self) return self.text end end
    if k=="SetText" then return function(self,v) self.text=v end end
    if k=="GetChecked" then return function() return false end end
    if k=="GetHeight" or k=="GetWidth" or k=="GetFrameLevel" or k=="GetStringWidth" then return function() return 400 end end
    if k=="HasFocus" then return function() return false end end
    if k=="GetCenter" then return function() return 100,100 end end
    local c = mock() rawset(t,k,c) return c
  end})
end
GameTooltip=mock()
local wins=0
function CreateFrame(t,name,parent,tmpl) local m=mock(name=="OpenGroupFrame" and "win" or nil) if name then _G[name]=m end return m end
UIParent=mock() Minimap=mock() function GetCursorPosition() return 0,0 end function InCombatLockdown() return false end function IsInGuild() return false end
PROVIDED={}
function CreateDataProvider(l) PROVIDED=l return l end
ScrollBoxConstants={RetainScrollPosition=1}
INIT=nil
function CreateScrollBoxListLinearView() local v=mock() v.SetElementInitializer=function(self,t,f) INITS=INITS or {} INITS[#INITS+1]=f INIT=INITS[1] end return v end
ScrollUtil={InitScrollBoxListWithScrollBar=function() end}
''')
for f in ["Proto.lua","Activities.lua","Quests.lua","Core.lua","Scan.lua","Nearby.lua","Widgets.lua","Alert.lua","UI.lua","AutoInvite.lua","Minimap.lua","GroupFinderTab.lua"]:
    lua.execute(open(os.path.join(D,f)).read())
lua.execute(r'''
OpenGroupDB={ allLevels = true } 
OpenGroup.peers={["Bob B"]={shard=55,seen=1000}}
OpenGroup.listings["Bob B"]={leader="Bob B",seq=1,shard=55,level=56,size=2,hops=0,class="MAGE",need=3,cat=2,acts={30},title="",note="lava run",got=990,via="Bob B"}
OpenGroup.listings["Lock L"]={leader="Lock L",seq=1,shard=55,level=60,size=1,hops=0,class="WARLOCK",need=0,cat=90001,acts={},price=25000,quest=0,title="Dire Maul",note="have clickers",got=999,via="Lock L"}
OpenGroup.listings["Q Q"]={leader="Q Q",seq=1,shard=56,level=30,size=2,hops=1,class="ROGUE",need=1,cat=3,acts={},price=0,quest=1234,title="The Missing Diplomat",note="",got=995,via="Bob B"}
OpenGroup.listings["Cat C"]={leader="Cat C",seq=1,shard=47,level=50,size=1,hops=1,class="",need=4,cat=0,acts={},title="Strat",note="",got=900,via="Bob B"}
-- your shard, from chat and the game's Group Finder (one of them is also an OpenGroup user: shown once)
OpenGroup_Nearby.onChat("LFM ZF need tank 3/5", "Zed Z", "4. LookingForGroup 47", "LookingForGroup 47", nil)
OpenGroup_Nearby.onChat("LFG strat as healer", "Cat C", "4. LookingForGroup 47", "LookingForGroup 47", nil)
OpenGroup.nearby["Fin F"]={leader="Fin F",src="finder",seq=0,shard=47,level=44,size=1,hops=0,class="PRIEST",need=2,cat=0,acts={},price=0,quest=0,title="Free text",note="first time",got=995}
SlashCmdList.OPENGROUP("")
local items = PROVIDED
print("items", #items)
for i, d in ipairs(items) do
  local row = CreateFrame("Button") row.built=false row.data=false row.roles=false
  INIT(row, d)
  if d.l then row.scripts.OnClick(row) row.scripts.OnEnter(row) row.scripts.OnDoubleClick(row) print("row", d.l.leader, OpenGroup.titleOf(d.l), d.l.src or "") else print("header", d.text, d.count) end
end
local nearbyRows, catTwice = 0, 0
for _, d in ipairs(items) do
  if d.l and d.l.src then nearbyRows = nearbyRows + 1 end
  if d.l and d.l.leader == "Cat C" then catTwice = catTwice + 1 end
end
assert(nearbyRows == 2, "chat + Group Finder rows should show: " .. nearbyRows)
-- your level band (58): BRD 52-60 and the summons stay; Fin F (44, no range) and the level 30 quest go
OpenGroupDB.allLevels = false
SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
local inBand = {}
for _, d in ipairs(PROVIDED) do if d.l then inBand[d.l.leader] = true end end
print("in band:", tostring(inBand["Bob B"]), tostring(inBand["Lock L"]), tostring(inBand["Fin F"]), tostring(inBand["Q Q"]))
assert(inBand["Bob B"] and inBand["Lock L"] and not inBand["Fin F"] and not inBand["Q Q"], "level band")
-- grouped by shard, then off; sorted by leader both ways
OpenGroupDB.allLevels = true
OpenGroupDB.groupBy = "shard" SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
local heads = {} for _, d in ipairs(PROVIDED) do if d.header then heads[#heads+1] = d.text end end
print("shard headers:", table.concat(heads, " | "))
OpenGroupDB.groupBy = "off" OpenGroupDB.sortKey = "leader" OpenGroupDB.sortDesc = true
SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
local firstName for _, d in ipairs(PROVIDED) do if d.l and not d.match then firstName = d.l.leader break end end
print("first by leader, reversed:", firstName)
assert(firstName == "Zed Z", "sort by leader, reversed")
for _, d in ipairs(PROVIDED) do assert(not d.header or d.header == "matches", "no group headers when grouping is off") end
OpenGroupDB.groupBy = "act" OpenGroupDB.sortKey = nil OpenGroupDB.sortDesc = nil
-- the search box filters live: only Zed's post matches "zf"
local B = OpenGroup_UI.browse
B.search = "zf" SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
local found = {} for _, d in ipairs(PROVIDED) do if d.l then found[#found+1] = d.l.leader end end
print("search zf:", table.concat(found, ", "))
assert(#found == 1 and found[1] == "Zed Z", "search filters rows")
B.search = ""
-- the Filter menu builds, and its items set the filters
local items = {}
local fake = {}
function fake:CreateRadio(text, isSel, onSel) items[text] = onSel end
function fake:CreateCheckbox(text, isSel, onSel) items[text] = onSel end
function fake:CreateTitle() end
function fake:CreateDivider() end
B.buildFilter(fake)
assert(items["Other servers"] and items["All levels"] and items["Compact rows"] and items["Server"], "filter menu items")
items["Other servers"]() assert(OpenGroupDB.where == "other" and B.filtersActive(), "Where from the menu")
items["All levels"]() assert(OpenGroupDB.allLevels == false, "All levels toggles")
B.resetFilters() assert(OpenGroupDB.where == "all" and not B.filtersActive(), "reset clears filters")
OpenGroupDB.allLevels = true
-- the right-click menu: Ask to Join only for a group with room
local function keys(list) local k = {} for _, it in ipairs(list) do k[#k+1] = it.key end return table.concat(k, ",") end
local grp = keys(OpenGroup_UI.personItems("Bob B", OpenGroup.listings["Bob B"]))
local solo = keys(OpenGroup_UI.personItems("Cat C", OpenGroup.listings["Cat C"]))
local summ = keys(OpenGroup_UI.personItems("Lock L", OpenGroup.listings["Lock L"]))
print("menus:", grp, "|", solo, "|", summ)
assert(grp == "whisper,invite,ask,open,friend,ignore" and solo == "whisper,invite,open,friend,ignore" and summ == solo, "menu items per row")
assert(#OpenGroup_UI.personItems("Ann A", nil) == 0, "no menu for yourself")
assert(catTwice == 1, "an OpenGroup user who also posts in chat shows once")
-- compact rows draw too, and switching back restores the roomy layout
OpenGroupDB.compact = true SlashCmdList.OPENGROUP("")  SlashCmdList.OPENGROUP("")
for _, d in ipairs(PROVIDED) do local row = CreateFrame("Button") row.built=false row.data=false row.roles=false INIT(row, d) if d.l then OpenGroupDB.compact = false INIT(row, d) OpenGroupDB.compact = true end end
SlashCmdList.OPENGROUP("compact")
print("compact after toggle:", tostring(OpenGroupDB.compact))
-- list tab
OpenGroupDB.tab = "list"
local A = OpenGroup_Activities
print("search brd:", A.name(A.search("brd")[1]), "| strat:", A.name(A.search("strat")[1]), "| black:", A.name(A.search("black")[1]))
for _, id in ipairs({30,31,32}) do local r = CreateFrame("Button") r.built=false INITS[2](r, id) r.scripts.OnClick(r) end
OpenGroup.post("", "note", 1, 2, {30})
print("mine title", OpenGroup.titleOf(OpenGroup.mine))
OpenGroupDB.tab = "browse" SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
local hasMatch = false
for _, d in ipairs(PROVIDED) do if d.header == "matches" then hasMatch = true print("match header", d.text, d.count) end end
assert(hasMatch, "solo listing for BRD should show the BRD group as a match")
OpenGroup.onNewListing({leader="New N",seq=1,shard=60,level=55,size=2,hops=0,class="PRIEST",need=4,cat=2,acts={30},title="",note="",got=1000})
OpenGroupDB.tab = "list"
-- summons + quest flows
OpenGroup_Quests.onPick({id=1234, title="The Missing Diplomat", level=30})
print("quest filter set; tab", OpenGroupDB.tab)
OpenGroupDB.tab = "list"
OpenGroup_Quests.onPick({id=1234, title="The Missing Diplomat", level=30})
OpenGroup.post("Dire Maul", "have clickers", 0, 90001, {}, 25000)
GetNumGroupMembers = function() return 3 end
OpenGroup.post("", "", 2, 2, {30})
OpenGroup.announceToGroup()
GetNumGroupMembers = function() return 0 end
print("summon mine:", OpenGroup.titleOf(OpenGroup.mine), OpenGroup.mine.price)
OpenGroup.post("The Missing Diplomat", "", 1, 3, {}, 0, 1234)
print("quest mine:", OpenGroup.titleOf(OpenGroup.mine), OpenGroup.mine.quest)
-- battleground queues: an offer on another shard matches my request
OpenGroup.listings["Pvp P"]={leader="Pvp P",seq=1,shard=61,level=60,size=1,hops=0,class="WARRIOR",need=0,cat=90002,acts={40},price=0,quest=0,title="",note="at the Orgrimmar battlemaster",got=1000,via="Pvp P"}
OpenGroup.post("", "", 0, 90003, {40})
OpenGroupDB.tab = "browse" SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
local bgMatch = false
for _, d in ipairs(PROVIDED) do if d.header == "matches" then bgMatch = true print("bg match header", d.text, d.count) end end
assert(bgMatch, "queue request should match the queue offer")
for _, d in ipairs(PROVIDED) do if d.l then local row = CreateFrame("Button") row.built=false INIT(row, d) row.scripts.OnClick(row) end end
OpenGroupDB.tab = "list"
OpenGroup.delist()
for _, tab in ipairs({"list","network","browse"}) do
  OpenGroupDB.tab = tab
  SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
  for _,t in ipairs(TICKERS) do t() end
  print("tab ok", tab)
end
SlashCmdList.OPENGROUP("shard")
for _,t in ipairs(TICKERS) do t() end

-- auto invite: a group for BRD wants 1 healer (any class) and 1 hunter level 52-54
INVITED = {} PARTY = {}
C_PartyInfo = { InviteUnit = function(n) INVITED[#INVITED+1] = n end }
function UnitInParty(n) return PARTY[n] == true end
function UnitInRaid() return nil end
function IsInGroup() return true end
function UnitIsGroupLeader() return true end
GetNumGroupMembers = function() local n = 3 for _ in pairs(PARTY) do n = n + 1 end return n end
OpenGroup.listings = {}
OpenGroup.nearby = {}
-- the List tab as a group of 3: two spot chips, the auto invite box and its options popup
OpenGroupDB.tab = "list" SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
for _,t in ipairs(TICKERS) do t() end
OpenGroup_AutoInvite.options(UIParent)
print("list tab as a group ok")
-- whispers: a conversation, the tab opened on it from Browse's Send Message path
OpenGroup.addWhisper("hi, room for a mage?", "Bob B", false, CLOCK, false)
OpenGroup.addWhisper("sure", "Bob B", true, CLOCK, false)
OpenGroup.onWhisper()
OpenGroup_UI.whisper("Bob B")
for _,t in ipairs(TICKERS) do t() end
print("whispers tab:", OpenGroupDB.tab, "unread", OpenGroup.whisperUnread())
assert(OpenGroupDB.tab == "whispers" and OpenGroup.whisperUnread() == 0, "opening the conversation reads it")
-- Browse, solo again: a group with spots shows them, and a hunter 58 fits the "Damage Hunter" spot
local saveN = GetNumGroupMembers
GetNumGroupMembers = function() return 0 end
UnitClass = function() return "Hunter", "HUNTER" end
OpenGroup.listings["Spot S"] = {leader="Spot S",seq=1,shard=60,level=58,size=3,hops=0,class="PRIEST",need=5,cat=2,acts={30},price=0,quest=0,title="",note="",got=CLOCK,via="Spot S",
  spots={ OpenGroup_Proto.spot(1, "WARRIOR"), OpenGroup_Proto.spot(4, "HUNTER", 55, 60) }}
OpenGroupDB.tab = "browse" SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
local shownSpots = false
for _, d in ipairs(PROVIDED) do if d.l and d.l.leader == "Spot S" then
  local row = CreateFrame("Button") row.built=false INIT(row, d) row.scripts.OnEnter(row) shownSpots = true
  print("spot row fit check shown:", tostring(row.fit.shown))
  assert(row.fit.shown == true, "a level 58 hunter fits Damage Hunter 55-60")
end end
assert(shownSpots, "the group with spots is listed")
OpenGroup.listings["Spot S"] = nil
UnitClass = function() return "Warlock","WARLOCK" end
GetNumGroupMembers = saveN
OpenGroup.post("", "", 0, 2, {30}, nil, nil, { { role = 2 }, { role = 4, class = "HUNTER", min = 52, max = 54 } })
print("spots sent:", OpenGroup_Proto.spotsText(OpenGroup.mine.spots), "need", OpenGroup.mine.need)
assert(OpenGroup.mine.need == 6)
local AI = OpenGroup_AutoInvite
local c = AI.cfg()
c.extra = false
OpenGroup.listings["Mage M"] = {leader="Mage M",seq=1,shard=55,level=53,size=1,hops=0,class="MAGE",need=4,cat=2,acts={30},price=0,quest=0,title="",note="",got=1000}
OpenGroup.listings["Hunt H"] = {leader="Hunt H",seq=1,shard=55,level=53,size=1,hops=0,class="HUNTER",need=4,cat=2,acts={30},price=0,quest=0,title="",note="",got=1000}
OpenGroup.listings["Old H"] = {leader="Old H",seq=1,shard=55,level=58,size=1,hops=0,class="HUNTER",need=4,cat=2,acts={30},price=0,quest=0,title="",note="",got=1000}
OpenGroup.listings["Strat P"] = {leader="Strat P",seq=1,shard=55,level=53,size=1,hops=0,class="PRIEST",need=2,cat=2,acts={31},price=0,quest=0,title="",note="",got=1000}
OpenGroup.nearby["Heal F"] = {leader="Heal F",src="finder",seq=0,shard=47,level=52,size=1,hops=0,class="PRIEST",need=2,cat=2,acts={30},price=0,quest=0,title="",note="",got=1000}
AI.start()
CLOCK = CLOCK + 3 AI.tick()
CLOCK = CLOCK + 3 AI.tick()
CLOCK = CLOCK + 3 AI.tick()
print("auto invited:", table.concat(INVITED, ", "))
assert(#INVITED == 2, "a hunter and a healer, nobody else")
local got = {} for _, n in ipairs(INVITED) do got[n] = true end
assert(got["Hunt H"] and got["Heal F"] and not got["Mage M"] and not got["Old H"] and not got["Strat P"], "filters: class, level, activity")
-- the hunter joins, the healer never answers: their slot opens again after a minute
PARTY["Hunt H"] = true
CLOCK = CLOCK + 70 AI.tick()
print("joined:", AI.joined["Hunt H"], "| healer declined:", AI.declined["Heal F"] ~= nil, "| need now:", OpenGroup.mine.need)
assert(AI.joined["Hunt H"] == 4 and AI.declined["Heal F"] and OpenGroup.mine.need == 2)
-- someone asks to join with the J1 message: a healer, invited at once
OpenGroup.receive("J1;PRIEST;53;2", "Ask A")
print("after ask:", INVITED[#INVITED])
assert(INVITED[#INVITED] == "Ask A")
PARTY["Ask A"] = true
CLOCK = CLOCK + 3 AI.tick()
print("auto on after full:", tostring(AI.on), "| listed:", tostring(OpenGroup.mine ~= nil))
assert(AI.on == false and OpenGroup.mine == nil, "filled group stops and delists")
-- invite extras: two open DPS spots, four eligible damage dealers queued: all four invited
INVITED = {} PARTY = {}
OpenGroup.listings = {} OpenGroup.nearby = {}
OpenGroup.post("", "", 4, 2, {30}, nil, nil, { { role = 4 }, { role = 4 } })
c.extra = true
for i = 1, 5 do OpenGroup.listings["Dps " .. i] = {leader="Dps " .. i,seq=1,shard=55,level=55,size=1,hops=0,class="ROGUE",need=4,cat=2,acts={30},price=0,quest=0,title="",note="",got=CLOCK} end
AI.declined = {} AI.asks = {}
AI.start()
for i = 1, 6 do CLOCK = CLOCK + 3 AI.tick() end
print("extras invited:", #INVITED)
assert(#INVITED == 4, "2 open spots x 2")
-- searches only from their own buttons, never piggybacked on other clicks, never in combat
WHO, SEARCHES = 0, 0
C_FriendList.SendWho = function() WHO = WHO + 1 end
C_LFGList.Search = function() SEARCHES = SEARCHES + 1 end
OpenGroup_Nearby.noSearch = nil
CLOCK = CLOCK + 1000
OpenGroup.scan.last, OpenGroup.scan.inFlight = nil, nil
OpenGroup.scan.auto(false) OpenGroup.scan.auto(true)
assert(SEARCHES == 0 and WHO == 0, "a tab, the minimap button or opening the window searches nothing")
OpenGroup_UI.browse.searchClick()
assert(SEARCHES == 1 and WHO == 0, "Search Group Finder: one Group Finder search, no /who")
InCombatLockdown = function() return true end
CLOCK = CLOCK + 100
OpenGroup_UI.browse.searchClick()
OpenGroup.scan.inFlight = nil
OpenGroup.scan.click()
assert(SEARCHES == 1 and WHO == 0, "nothing in combat")
assert(not OpenGroup_Nearby.gameList({ 30 }, 4, true), "no game listing in combat")
assert(select(2, OpenGroup_Nearby.post("LFM BRD")) ~= nil, "no LFG post in combat")
InCombatLockdown = function() return false end
OpenGroup.scan.inFlight = nil
-- after a refusal only a direct Search click may try again
OpenGroup_Nearby.noSearch = true
CLOCK = CLOCK + 10
OpenGroup_UI.browse.searchClick()
print("explicit search after a refusal:", SEARCHES)
assert(SEARCHES == 2, "a direct click on Search tries again")
-- an empty list with stale results offers Search
OpenGroup.listings, OpenGroup.nearby = {}, {}
OpenGroup_Nearby.resultsAt = nil
OpenGroupDB.tab = "browse" SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
print("empty list search button:", tostring(OpenGroup_UI.browse.emptySearch.shown))
assert(OpenGroup_UI.browse.emptySearch.shown == true, "empty state shows Search")
-- the List tab: category tiles, then quick picks (recent listings, dungeons for your level)
local LI = OpenGroup_UI.list
OpenGroupDB.recent = nil
OpenGroup.delist()
OpenGroup.post("", "lava run", 4, 2, {30})
OpenGroup.delist()
OpenGroupDB.tab = "list" SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
LI.layoutBanners()
local titles = {}
for _, t in ipairs(LI.picks.titles) do if t.shown ~= false then titles[#titles+1] = t.text end end
print("tiles:", #LI.tiles, "| picks:", table.concat(titles, " / "), "| recent:", #(OpenGroupDB.recent or {}))
assert(#LI.tiles >= 4, "a tile per category")
local t1 = LI.tiles[1]
assert(t1.art and t1.window and t1.atlas, "a tile has its picture, its window and an atlas")
if t1.cardArt then assert(t1.card and t1.mask, "with the card art: the frame behind, the picture masked to its shape") end
assert(#(OpenGroupDB.recent or {}) == 1 and OpenGroup.titleOf(OpenGroupDB.recent[1]) == "Blackrock Depths", "the listing is remembered")
assert(titles[1] == "Your recent listings" and titles[2] == "Good for your level", "both quick pick sections")
LI.relist(OpenGroupDB.recent[1])
assert(OpenGroup.mine and OpenGroup.titleOf(OpenGroup.mine) == "Blackrock Depths", "listing again from a recent pick")
OpenGroup.delist()
-- another shard's Group Finder: a digest from an OpenGroup player on shard 56 shows in Browse
local N = OpenGroup_Nearby
local Pr = OpenGroup_Proto
OpenGroup.listings, OpenGroup.nearby, OpenGroup.remote = {}, {}, {}
OpenGroup.peers["Rep R"] = { shard = 56, level = 60, seen = CLOCK }
local dg = Pr.finderDigest(56, 1, { { leader = "Far Away", act = 30, size = 3, need = 4, age = 20 }, { leader = "Other Group", act = 31, size = 2, need = 6, age = 5 } })
local dropped0 = OpenGroup.stats.dropped or 0
for _, m in ipairs(dg) do OpenGroup.receive(m, "Rep R") end
assert(OpenGroup.remote["Far Away"] and OpenGroup.remote["Far Away"].shard == 56 and OpenGroup.remote["Far Away"].reporter == "Rep R", "a remote group is kept with its shard and reporter")
OpenGroupDB.allLevels = true OpenGroupDB.where = "all"
OpenGroupDB.tab = "browse" SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
local seenRemote = false
for _, d in ipairs(PROVIDED) do if d.l and d.l.leader == "Far Away" then seenRemote = d.r.remote and d.r.where == "other"
  local row = CreateFrame("Button") row.built=false INIT(row, d) row.scripts.OnEnter(row) end end
assert(seenRemote, "the remote group is in Browse, as another shard's")
OpenGroupDB.where = "og" SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
for _, d in ipairs(PROVIDED) do assert(not (d.l and d.l.src == "remote"), "OpenGroup players filter leaves them out") end
OpenGroupDB.where = "all"
-- the reporter's next digest leaves one out: it goes
for _, m in ipairs(Pr.finderDigest(56, 2, { { leader = "Far Away", act = 30, size = 4, need = 4, age = 1 } })) do OpenGroup.receive(m, "Rep R") end
assert(OpenGroup.remote["Far Away"] and OpenGroup.remote["Far Away"].size == 4 and OpenGroup.remote["Other Group"] == nil, "a digest replaces the last one")
-- a passed-on group we already have in our own results stays ours, and counts as overlap
OpenGroup.nearby["Seen Here"] = { leader = "Seen Here", src = "finder", size = 2, need = 4, acts = {30}, got = CLOCK, level = 0, shard = 47 }
local ov0 = N.stats.overlapSeen
for _, m in ipairs(Pr.finderDigest(56, 9, { { leader = "Seen Here", act = 30, size = 2, need = 4, age = 1 }, { leader = "Far Away", act = 30, size = 4, need = 4, age = 1 } })) do OpenGroup.receive(m, "Rep R") end
assert(OpenGroup.remote["Seen Here"] == nil and N.stats.overlapSeen == ov0 + 1, "local results win, overlap counted")
print("overlap by shard:", N.overlapText())
assert(N.overlapText() == "Chat 56 50% (2 groups)", "overlap per shard, from the latest digest")
OpenGroup.nearby["Seen Here"] = nil
-- our own shard's digest is ignored; 5 minutes on, the rest expire
for _, m in ipairs(Pr.finderDigest(47, 3, { { leader = "Home Group", act = 30, size = 2, need = 4, age = 1 } })) do OpenGroup.receive(m, "Rep R") end
assert(OpenGroup.remote["Home Group"] == nil, "our own shard's digest is ignored")
CLOCK = CLOCK + 400 N.expireRemote()
assert(next(OpenGroup.remote) == nil, "remote groups expire")
assert((OpenGroup.stats.dropped or 0) == dropped0, "a digest doesn't trip the message budget")
-- one reporter per shard: the name that sorts first reports, the other stands by
assert(N.shouldReport("Bob B", {}, 1000, true) and not N.shouldReport("Bob B", { ["Ann A"] = 990 }, 1000, true), "election")
assert(N.shouldReport("Ann A", { ["Bob B"] = 990 }, 1000, true) and not N.shouldReport("Ann A", {}, 1000, false), "election: earlier name, and only with fresh results")
assert(N.shouldReport("Bob B", { ["Ann A"] = 800 }, 1000, true), "a reporter gone quiet is replaced")
-- the sending side: our shard's Group Finder rows go to the other-shard peer, and a claim to ours
OpenGroup.nearby = {}
OpenGroup.nearby["Near One"] = { leader = "Near One", src = "finder", size = 3, need = 6, acts = {30}, got = CLOCK, level = 0, shard = 47 }
OpenGroup.peers["Rep R"].seen = CLOCK OpenGroup.peers["Mate M"] = { shard = 47, level = 60, seen = CLOCK }
N.resultsAt = GetTime() N.claims = {}
local q0 = OpenGroup.queued()
assert(N.report() == true, "we report our shard")
print("report queued:", OpenGroup.queued() - q0, "| harvested:", N.stats.harvested)
assert(OpenGroup.queued() - q0 >= 2 and N.stats.harvested == 1, "a digest to the other shard and a claim to ours")
-- another shard's LFG chat: rows "LFG 56", repeats collapse, the next digest and time clear them
OpenGroup.remote = {}
local c1 = Pr.chatDigest(56, 4, { { leader = "Chat Poster", age = 10, act = 0, need = 1, size = 1, text = "LFM ZF need tank" },
  { leader = "Chat Poster", age = 5, act = 0, need = 1, size = 1, text = "LFM ZF need tank, 4/5" }, { leader = "Other Poster", age = 3, act = 30, need = 4, size = 3, text = "BRD lava run need dps" } })
local d0 = OpenGroup.stats.dropped or 0
for _, m in ipairs(c1) do OpenGroup.receive(m, "Rep R") end
local cp = OpenGroup.remote["Chat Poster"]
assert(cp and cp.src == "remotechat" and cp.shard == 56 and OpenGroup.remote["Other Poster"].acts[1] == 30, "chat posts kept, matched ones with their dungeon")
local n = 0 for _, r in pairs(OpenGroup.remote) do if r.leader == "Chat Poster" then n = n + 1 end end
assert(n == 1, "repeats collapse into one row")
OpenGroupDB.where = "chat" OpenGroupDB.allLevels = true SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
local inChat = false
for _, d in ipairs(PROVIDED) do if d.l and d.l.leader == "Chat Poster" then inChat = d.r.chatPost
  local row = CreateFrame("Button") row.built=false INIT(row, d) row.scripts.OnEnter(row) end end
assert(inChat, "the LFG chat filter takes in other shards' posts")
OpenGroupDB.where = "all"
for _, m in ipairs(Pr.chatDigest(56, 5, { { leader = "Other Poster", age = 1, act = 30, need = 4, size = 3, text = "BRD lava run need dps" } })) do OpenGroup.receive(m, "Rep R") end
assert(OpenGroup.remote["Chat Poster"] == nil and OpenGroup.remote["Other Poster"], "the next digest replaces the last")
CLOCK = CLOCK + 700 N.expireRemote()
assert(next(OpenGroup.remote) == nil, "chat posts expire after 10 minutes")
assert((OpenGroup.stats.dropped or 0) == d0, "chat digests don't trip the message budget")
-- sending: our shard's chat rows go out unless the setting is off
OpenGroup.nearby = {}
OpenGroup.nearby["Here Poster"] = { leader = "Here Poster", src = "chat", size = 1, need = 1, acts = {}, got = CLOCK, level = 0, shard = 47, title = "LFG strat as healer", note = "" }
OpenGroup.peers["Rep R"].seen = CLOCK N.resultsAt = nil N.claims = {}
local s0 = N.stats.chatShared
assert(N.report() == true and N.stats.chatShared == s0 + 1, "our LFG posts are passed on")
OpenGroupDB.shareChat = false
assert(N.report() == false and N.stats.chatShared == s0 + 1, "the setting turns it off")
OpenGroupDB.shareChat = nil
print("other shards' LFG chat ok")
print("other shards' Group Finder ok")
-- pinging yourself sends nothing
OpenGroup.pings = {}
OpenGroup.ping("Ann A")
assert(next(OpenGroup.pings) == nil, "no ping to yourself")
-- your party's listing: the leader's message lights up a member's OpenGroup; others' are ignored
local P = OpenGroup_Proto
OpenGroup.delist()
IsInGroup = function() return true end
GetNumGroupMembers = function() return 2 end
UnitIsGroupLeader = function(u) return u == "party1" end
UnitExists = function(u) return u == "party1" end
local saveUnitName = UnitName
UnitName = function(u) if u == "party1" then return "Lead L" end return "Ann A" end
local msg = P.groupListing({ leader = "Lead L", seq = 3, shard = 47, level = 55, size = 2, age = 0, hops = 0, class = "PRIEST", need = 4, cat = 2, acts = {30}, title = "", note = "lava", spots = { P.spot(4, "MAGE") } })
OpenGroup.receiveGroup(msg, "Other O")
assert(OpenGroup.groupListing == nil, "only the leader's message counts")
OpenGroup.receiveGroup(msg, "Lead L")
print("member sees:", OpenGroup.groupListing and OpenGroup.titleOf(OpenGroup.groupListing.l), "minimap lit:", tostring(OpenGroup_Minimap.isLit()), "bar:", tostring(OpenGroup_UI.qbar.shown))
assert(OpenGroup.groupListing and OpenGroup.groupListing.leader == "Lead L" and OpenGroup_Minimap.isLit() and OpenGroup_UI.qbar.shown, "member gets the listed state")
OpenGroupDB.tab = "list" SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
OpenGroup.receiveGroup(P.groupUnlisted(4), "Other O")
assert(OpenGroup.groupListing ~= nil, "a non-leader can't unlist")
OpenGroup.receiveGroup(P.groupUnlisted(4), "Lead L")
assert(OpenGroup.groupListing == nil and not OpenGroup_Minimap.isLit(), "unlist clears")
UnitName = saveUnitName
IsInGroup = function() return false end
GetNumGroupMembers = function() return 0 end
-- whispers: a known peer's class and level
RAID_CLASS_COLORS.MAGE = { colorStr = "ff3fc7eb" }
function GetPlayerInfoByGUID() return "Mage", "MAGE" end
OpenGroup.peers["Mia M"] = { shard = 55, level = 52, seen = CLOCK }
local c = OpenGroup.addWhisper("hi", "Mia M", false, CLOCK, false)
OpenGroup.notePerson(c.name, "Player-1-ABC")
print("whisper person:", OpenGroup.personLine("Mia M"))
assert(OpenGroup.personLine("Mia M") == "Level 52 MAGE" or OpenGroup.personLine("Mia M") == "Level 52 Mage", "class and level")
OpenGroup_UI.whisper("Mia M")
-- Find players: a spot opens the page with the classes that fill it; one /who per Search click
local F = OpenGroup_UI.find
local Pr2 = OpenGroup_Proto
WHO, SEARCHES = 0, 0
local lastWho
C_FriendList.SendWho = function(q) WHO = WHO + 1 lastWho = q end
C_LFGList.Search = function() SEARCHES = SEARCHES + 1 end
OpenGroup.scan.inFlight = nil
F.open(Pr2.spot(1))
print("find query:", F.query(), "classes:", #F.classes)
assert(OpenGroupDB.tab == "find" and #F.classes == 2 and F.classes[1] == "WARRIOR" and F.classes[2] == "DRUID", "a Horde tank spot: Warrior and Druid")
assert(F.query():match('^c%-"Warrior" %d+%-%d+$'), "query: class and levels")
assert(F.msg:GetText():find("tank"), "message names the role")
local q1 = F.query()
F.searchClick()
assert(WHO == 1 and SEARCHES == 0 and lastWho == q1, "one /who per Search click, no Group Finder search")
assert(F.query():match('^c%-"Druid"'), "the next click takes the next class")
F.searchClick()
assert(WHO == 1, "no second /who while one is running")
-- 120 matches, 50 shown: me, an ignored player and an OpenGroup player are skipped
C_FriendList.GetNumWhoResults = function() return 50, 120 end
C_FriendList.GetWhoInfo = function(i)
  local name = i == 1 and "Ann A" or ("Who " .. i)
  return { fullName = name, level = 56, classStr = "Warrior", filename = "WARRIOR", area = "Felwood", fullGuildName = "" }
end
C_FriendList.IsIgnored = function(n) return n == "Who 2" end
OpenGroup.peers["Who 3"] = { shard = 47, level = 56, seen = CLOCK }
OpenGroup.scan.onWhoList()
print("find results:", #F.results, F.total, F.notice:GetText())
assert(#F.results == 50 and F.total == 120 and F.notice:GetText():find("50 shown"), "the 50 cap is called out")
assert(F.nextTarget().fullName == "Who 4", "whisper next skips you, ignored and OpenGroup players")
local told, typed
ChatFrame_SendTell = function(n) told = n end
ChatEdit_GetActiveWindow = function() return { Insert = function(_, t) typed = t end } end
F.whisper(F.nextTarget())
assert(told == "Who 4" and typed == F.msg:GetText(), "the chat box opens on them with the message")
assert(F.asked["Who 4"] == nil and F.nextTarget().fullName == "Who 4", "not asked until the whisper goes out")
OpenGroup.whisperEvent(nil, "CHAT_MSG_WHISPER_INFORM", typed, "Who 4")
assert(F.asked["Who 4"] and F.nextTarget().fullName == "Who 5", "asked once it went out; next moves on")
date = date or function() return "12:00" end
local frow = CreateFrame("Button") frow.built = false
INITS[#INITS - 3](frow, F.results[4])
print("find row badge:", frow.badge:GetText())
ChatFrame_SendTell = nil ChatEdit_GetActiveWindow = nil
-- servers: a Trade number whose Group Finder we nearly all had is our server
local Nb = OpenGroup_Nearby
Nb.stats.overlapBy = { [56] = { seen = 19, total = 20 }, [61] = { seen = 0, total = 12 }, [70] = { seen = 1, total = 2 } }
print("server:", Nb.serverName(), "|", Nb.whereText(56), "|", Nb.whereText(61), "|", Nb.whereText(70), "|", Nb.whereTip(56))
assert(Nb.serverName() == "Chat 47 + 56", "our server as its Trade numbers")
assert(Nb.whereText(56) == "Your server" and Nb.whereText(61) == "Other server" and Nb.whereText(70) == "Chat 70", "row labels")
assert(Nb.whereTip(70):find("server unknown"), "unknown says so")
-- one reporter per server: a player on Trade 56 (our server) stands by and gets no digest
OpenGroup.nearby = {}
OpenGroup.nearby["Near Two"] = { leader = "Near Two", src = "finder", size = 3, need = 6, acts = {30}, got = CLOCK, level = 0, shard = 47 }
for n in pairs(OpenGroup.peers) do OpenGroup.peers[n] = nil end
OpenGroup.peers["Same S"] = { shard = 56, level = 60, seen = CLOCK }
Nb.resultsAt = GetTime() Nb.claims = {}
local q2 = OpenGroup.queued()
assert(Nb.report() == false, "only our own server's players: nobody to report to")
OpenGroup.peers["Far F"] = { shard = 61, level = 60, seen = CLOCK }
assert(Nb.report() == true, "another server gets the digest")
OpenGroup.receive(Pr2.reporting(3), "Same S")
assert(Nb.claims["Same S"], "a claim from our server's other Trade number counts")
-- LFG chat is per chat number: Trade 56 shares our server (no Group Finder digest) but still gets
-- our chat, and its own chat reporter doesn't make us stand by
Nb.stats.overlapBy = { [56] = { seen = 19, total = 20 } }
for n in pairs(OpenGroup.peers) do OpenGroup.peers[n] = nil end
OpenGroup.peers["Same S"] = { shard = 56, level = 60, seen = CLOCK }
OpenGroup.peers["Mate M"] = { shard = 47, level = 60, seen = CLOCK }
OpenGroup.nearby = {}
OpenGroup.nearby["GF Three"] = { leader = "GF Three", src = "finder", size = 3, need = 6, acts = {30}, got = CLOCK, level = 0, shard = 47 }
OpenGroup.nearby["Chat Three"] = { leader = "Chat Three", src = "chat", size = 1, need = 1, acts = {}, got = CLOCK, level = 0, shard = 47, title = "LFM strat", note = "" }
Nb.resultsAt = GetTime() Nb.claims = {} Nb.chatClaims = {}
local sentTo, saveSend = {}, OpenGroup.send
OpenGroup.send = function(to, m, ...) sentTo[#sentTo + 1] = to .. " " .. m:sub(1, 2) .. (m:sub(1, 2) == "R1" and (" " .. m) or "") return saveSend(to, m, ...) end
OpenGroupDB.shareChat = nil
assert(Nb.report() == true, "chat goes out to the other number on our server")
local got = table.concat(sentTo, " | ")
print("sent:", got)
assert(got:find("Same S C1") and not got:find("Same S F1"), "same server: chat, no Group Finder digest")
assert(got:find("Mate M R1 R1;%d+;fc"), "our number's player hears we report both")
OpenGroup.send = saveSend
OpenGroup.receive(Pr2.reporting(2, "c"), "Same S")
assert(Nb.chatClaims["Same S"] == nil, "another number's chat reporter doesn't count for ours")
OpenGroup.receive(Pr2.reporting(2, "f"), "Same S")
assert(Nb.claims["Same S"], "but its Group Finder claim does (same server)")
OpenGroup.receive("R1;3", "Mate M")
assert(Nb.claims["Mate M"] and Nb.chatClaims["Mate M"], "an older claim (no kind) counts for both")
assert(select(2, Pr2.parse(Pr2.reporting(1, "c"))).what == "c" and select(2, Pr2.parse("R1;1")).what == "fc", "claim kinds parse")
Nb.stats.overlapBy = {} Nb.claims = {} Nb.chatClaims = {}
print("find players ok")
-- queued for several: search finds the second one, a filter files it there, no filter lists it under all
local Ac = OpenGroup_Activities
Ac.info[50] = { id = 50, name = "Upper Blackrock Spire", short = "UBRS", min = 55, max = 60, cat = 2 }
Ac.info[51] = { id = 51, name = "Scholomance", short = "Scholomance", min = 58, max = 60, cat = 2 }
OpenGroup.listings = {} OpenGroup.remote = {}
OpenGroup.nearby = { ["Multi M"] = { leader = "Multi M", src = "finder", seq = 0, shard = 47, level = 60, size = 1, hops = 0, class = "MAGE", need = 4, cat = 2, acts = {50, 51, 31}, price = 0, quest = 0, title = "", note = "", got = CLOCK } }
OpenGroupDB.groupBy = "act" OpenGroupDB.allLevels = true OpenGroupDB.where = "all"
local B2 = OpenGroup_UI.browse
B2.search = "scholo" SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
local heads, hits = {}, 0
for _, d in ipairs(PROVIDED) do if d.header then heads[#heads + 1] = d.text end if d.l and d.l.leader == "Multi M" then hits = hits + 1 end end
print("search scholo:", hits, table.concat(heads, " | "))
assert(hits == 1 and heads[1]:find("Scholomance"), "search 'scholo' finds the second activity and files it there")
B2.search = "ubrs" SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
hits = 0 for _, d in ipairs(PROVIDED) do if d.l and d.l.leader == "Multi M" then hits = hits + 1 end end
assert(hits == 1, "aliases: ubrs")
B2.search = ""
local wantSch = function(id) return id == 51 end
local rr = OpenGroup.rowOf(OpenGroup.nearby["Multi M"], 47, wantSch)
local g1 = OpenGroup.groupRows({ rr }, "act")
assert(#g1 == 1 and g1[1].text == "Scholomance" and g1[1].rows[1].act == 51, "filter Scholomance: under Scholomance, not UBRS")
local g3 = OpenGroup.groupRows({ OpenGroup.rowOf(OpenGroup.nearby["Multi M"], 47) }, "act")
print("unfiltered groups:", #g3)
assert(#g3 == 3, "unfiltered: under all three")
-- the other activities travel in other servers' Group Finder digests, and old senders still parse
local Pd = OpenGroup_Proto
local dm = Pd.finderDigest(56, 3, { { leader = "Multi M", act = 50, more = { 51, 31 }, size = 1, need = 4, age = 2 } })
local kd, dd = Pd.parse(dm[1])
assert(kd == "F1" and dd.items[1].act == 50 and dd.items[1].more[1] == 51 and dd.items[1].more[2] == 31, "digest carries the other activities")
local kd2, dd2 = Pd.parse("F1;56;3;1;1;Old O/50/1/4/2")
assert(kd2 == "F1" and #dd2.items[1].more == 0, "older digests still parse")
OpenGroup.nearby = {}
OpenGroup.receive(dm[1], "Rep R")
local rm = OpenGroup.remote["Multi M"]
assert(rm and #rm.acts == 3 and rm.acts[2] == 51, "other-server rows keep every activity")
print("multi-activity ok")
-- languages: All languages sends every offered one; picked ones send those and yours; never saved to the game
local Nl = OpenGroup_Nearby
C_LFGList.GetAvailableLanguageSearchFilter = function() return { "enUS", "deDE", "frFR" } end
C_LFGList.GetDefaultLanguageSearchFilter = function() return { enUS = true } end
local savedGame = false
C_LFGList.SaveLanguageSearchFilter = function() savedGame = true end
local langArg
C_LFGList.Search = function(cat, f, pf, langs) langArg = langs end
Nl.noSearch = nil
OpenGroupDB.langAll, OpenGroupDB.langs = nil, nil
CLOCK = CLOCK + 100
assert(Nl.search(true, true), "search runs")
assert(langArg and langArg.enUS and langArg.deDE and langArg.frFR, "All languages: every offered language")
OpenGroupDB.langAll, OpenGroupDB.langs = false, { frFR = true }
CLOCK = CLOCK + 100
Nl.search(true, true)
assert(langArg and langArg.enUS and langArg.frFR and not langArg.deDE, "picked: those and yours")
OpenGroupDB.langs = {}
CLOCK = CLOCK + 100
Nl.search(true, true)
assert(langArg == nil, "only yours: the game's default")
assert(not savedGame, "the game's own language filter is left alone")
local lmenu = {}
local lfake = {}
function lfake:CreateRadio() end function lfake:CreateTitle() end function lfake:CreateDivider() end
function lfake:CreateCheckbox(text, isSel, onSel) lmenu[text] = { isSel, onSel } end
OpenGroupDB.langAll = nil
OpenGroup_UI.browse.buildFilter(lfake)
assert(lmenu["All languages"] and lmenu["All languages"][1]() and lmenu["deDE"], "Language menu")
lmenu["deDE"][2]()
assert(OpenGroupDB.langAll == false and OpenGroupDB.langs.frFR and not OpenGroupDB.langs.deDE, "unticking one from All keeps the rest")
OpenGroupDB.langAll, OpenGroupDB.langs = nil, nil
print("languages ok")
-- the chat number changes (joined a group elsewhere, zone change): peers get a hello with the new one
OpenGroup.checkShard()
assert(OpenGroup.lastShard == 47, "first read")
OpenGroup.peers["Pal P"] = { shard = 47, level = 60, seen = CLOCK }
local hellos = {}
local saveSend2 = OpenGroup.send
OpenGroup.send = function(to, m, ...) if m:sub(1, 2) == "H1" then hellos[#hellos + 1] = to .. " " .. m end return saveSend2(to, m, ...) end
GetChannelList = function() return 1, "Trade 55", false end
assert(OpenGroup.checkShard() == true and OpenGroup.lastShard == 55, "a new number is noticed")
print("hellos after the change:", table.concat(hellos, " | "))
assert(#hellos > 0 and hellos[1]:find("H1;55;"), "peers hear the new number")
local n0 = #hellos
assert(OpenGroup.checkShard() == false and #hellos == n0, "no change, no hellos")
GetChannelList = function() return 1, "Trade 47", false end
OpenGroup.checkShard()
assert(#hellos == n0, "a second change within 30 seconds: no new round of hellos")
OpenGroup.send = saveSend2
print("chat number refresh ok")
-- the game's own Group Finder: List creates (or updates) it from the click, Leave removes ours only
local Ng = OpenGroup_Nearby
local calls = {}
local active = false
C_LFGList.HasActiveEntryInfo = function() return active end
C_LFGList.CreateListing = function(d) calls[#calls + 1] = "create " .. table.concat(d.activityIDs, ",") active = true end
C_LFGList.UpdateListing = function(d) calls[#calls + 1] = "update " .. table.concat(d.activityIDs, ",") end
C_LFGList.RemoveListing = function() calls[#calls + 1] = "remove" active = false end
local rolesSet
C_LFGListRoles = { SetRoles = function(r) rolesSet = r end }
IsInGroup = function() return false end
GetNumGroupMembers = function() return 0 end
OpenGroupDB.gameList = nil
assert(Ng.gameList({ 30, 31 }, 4, true) and calls[1] == "create 30,31", "List creates the game listing with the activities")
assert(rolesSet and rolesSet.dps and not rolesSet.tank, "solo roles saved for the game")
local pr = {}
local savePrint = OpenGroup.print
OpenGroup.print = function(m) pr[#pr + 1] = m end
Ng.onGameEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
assert(Ng.game.listed and pr[1] and pr[1]:find("also listed"), "confirmed on the game's event")
assert(Ng.gameList({ 30 }, 4, true) and calls[2] == "update 30", "already listed: update")
assert(Ng.gameList({ 999 }, 4, true) == false or calls[3] == nil, "unknown activities aren't sent")
assert(Ng.gameUnlist() and calls[#calls] == "remove", "Leave removes ours")
active = true Ng.game.ours = nil
local nCalls = #calls
assert(Ng.gameUnlist() == false and #calls == nCalls, "a listing the player made in the game's window is left alone")
active = false
OpenGroupDB.gameList = false
assert(Ng.gameList({ 30 }, 4, true) == false, "the setting turns it off")
OpenGroupDB.gameList = nil
GetNumGroupMembers = function() return 3 end
UnitIsGroupLeader = function() return false end
assert(Ng.gameList({ 30 }, 4, false) == false, "a group member can't list the group")
GetNumGroupMembers = function() return 0 end
C_LFGList.CreateListing = function() end
Ng.gameList({ 30 }, 4, true)
pr = {}
Ng.onGameEvent("ADDON_ACTION_BLOCKED", "OpenGroup")
assert(Ng.game.refused and pr[1] and pr[1]:find("refused"), "a refusal is said")
local nsBefore = Ng.noSearch
Ng.onEvent(nil, "ADDON_ACTION_BLOCKED", "OpenGroup", "UNKNOWN()")
assert(Ng.noSearch == nsBefore, "a refused listing doesn't pause Group Finder searches")
OpenGroup.print = savePrint
print("game listing ok")
-- people around you: same faction, real players, a queue of 30, one hello per tick, never twice a session
local units = {}
local saveUN, saveUFG, saveUIP = UnitName, UnitFactionGroup, UnitIsPlayer
UnitIsPlayer = function(u) return units[u] ~= nil and units[u].player end
UnitIsUnit = function(a, b) return a == b end
UnitFactionGroup = function(u) if u == "player" then return "Horde" end return units[u] and units[u].faction end
UnitName = function(u) if u == "player" then return "Ann", "A" end local x = units[u] if x then return x.first, x.last end end
IsInInstance = function() return false end
InCombatLockdown = function() return false end
units.np1 = { player = true, faction = "Horde", first = "Near", last = "One" }
units.np2 = { player = true, faction = "Alliance", first = "Ally", last = "Two" }
units.np3 = { player = false, faction = "Horde", first = "Npc", last = "Three" }
OpenGroup.nearQueue, OpenGroup.nearAsked = {}, {}
assert(OpenGroup.noteNearby("np1") and not OpenGroup.noteNearby("np2") and not OpenGroup.noteNearby("np3"), "same faction, real players only")
assert(not OpenGroup.noteNearby("np1"), "once in the queue")
for i = 1, 40 do units["x" .. i] = { player = true, faction = "Horde", first = "Walker", last = "N" .. i } OpenGroup.noteNearby("x" .. i) end
assert(#OpenGroup.nearQueue == 30, "queue capped at 30, oldest dropped")
local p0 = OpenGroup.stats.probes or 0
OpenGroup.probed = {}
assert(OpenGroup.nearTick() and (OpenGroup.stats.probes or 0) == p0 + 1, "one hello per tick")
assert((OpenGroup.probeWhy or {}).nearby and OpenGroup.probeWhy.nearby >= 1, "counted as nearby")
local asked = OpenGroup.nearQueue[1]
OpenGroup.nearTick()
OpenGroup.probed = {}
units.again = { player = true, faction = "Horde", first = "Walker", last = "N11" }
assert(not OpenGroup.noteNearby("again"), "asked this session: not again, even after 30 minutes")
IsInInstance = function() return true, "party" end
assert(not OpenGroup.noteNearby("x40") or true, "instances")
units.inst = { player = true, faction = "Horde", first = "Inst", last = "I" }
assert(not OpenGroup.noteNearby("inst"), "not in instances")
IsInInstance = function() return false end
UnitName, UnitFactionGroup, UnitIsPlayer = saveUN, saveUFG, saveUIP
-- word of mouth: up to 20 names, in messages older versions read (10 each)
for n in pairs(OpenGroup.peers) do OpenGroup.peers[n] = nil end
for i = 1, 25 do OpenGroup.peers["Peer P" .. i] = { shard = (i % 2 == 0) and 47 or 55, level = 60, seen = CLOCK - i } end
local xs = {}
local saveSend3 = OpenGroup.send
OpenGroup.send = function(to, m, ...) if m:sub(1, 2) == "X1" then xs[#xs + 1] = m end end
OpenGroup.sharePeers("Newbie N", 47)
OpenGroup.send = saveSend3
local total = 0
for _, m in ipairs(xs) do local k, d = OpenGroup_Proto.parse(m) assert(k == "X1" and #d.peers <= 10, "each message within the old limit") total = total + #d.peers end
print("word of mouth:", #xs, "messages,", total, "names; first:", xs[1]:sub(1, 40))
assert(total == 20 and #xs == 2, "20 names in two messages")
assert(xs[1]:find(":55"), "other chat numbers first")
print("discovery ok")
-- World chat: what's worth passing on, links as IDs, compression, the relay tree, repeats, budget
local Nw, Pw = OpenGroup_Nearby, OpenGroup_Proto
assert(Nw.feedKeep("WTS [Arcanite Bar] 4g each") and Nw.feedKeep("LFM BRD need heals") and Nw.feedKeep("LF enchanter for crusader, tips"), "ads, groups, crafters kept")
assert(not Nw.feedKeep("lol anyone seen my dog") and not Nw.feedKeep("cheap gold at www.goldsite.com") and not Nw.feedKeep("WTS BRD boost 10g") and not Nw.feedKeep("WTS strat carry"), "chatter, gold sellers, boosts dropped")
local linked = "WTS |cff1eff00|Hitem:12360::::::::60:::::::|h[Arcanite Bar]|h|r 4g"
assert(Nw.packLinks(linked) == "WTS {i12360=Arcanite Bar#2} 4g", "item links travel as IDs, with name and quality")
assert(Nw.packLinks("LF |cffffd000|Henchant:20034|h[Enchant Weapon - Crusader]|h|r") == "LF {e20034=Enchant Weapon - Crusader}", "enchant links too")
assert(Nw.packLinks("WTS |cff1eff00|Hitem:10282:0:0:0:0:0:1199:0|h[Ebon Bracers of the Eagle]|h|r") == "WTS {i10282:0:1199=Ebon Bracers of the Eagle#2}", "item suffixes kept")
-- the newer named colour codes (|cnIQ3:) the game uses now
local named = "WTS |cnIQ3:|Hitem:16712::::::::60:::::::|h[Shadowcraft Gloves]|h|r"
assert(Nw.packLinks(named) == "WTS {i16712=Shadowcraft Gloves#3}", "named colours: no stray cnIQ3, quality kept")
assert(Nw.packLinks("WTS |cnIQ3:[Shadowcraft Gloves]|r") == "WTS [Shadowcraft Gloves]", "a named colour on plain text goes too")
assert(Nw.parse("LFM BRD |cnIQ3:need heals|r") and Nw.parse("LFM BRD |cnIQ3:need heals|r").need == 2, "the chat parser strips them too")
-- links never vanish: odd payloads, icons in the name, a link with no colour at all
assert(Nw.packLinks("WTS |cnIQ3:|Hitem:16712::::::::60:::::::::Player-1-0ABC|h[Shadowcraft Gloves]|h|r 30g") == "WTS {i16712=Shadowcraft Gloves#3} 30g", "a link with extra payload fields keeps its item")
assert(Nw.packLinks("WTS |cnIQ2:|Hitem:12360::::::::60:::::::|h[|A:Professions-ChatIcon-Quality-Tier1:17:15::1|aArcanite Bar]|h|r") == "WTS {i12360=Arcanite Bar#2}", "icons in a link's name go, the name stays")
assert(Nw.packLinks("WTS |Hitem:7969::::::::60:::::::|h[Mithril Spurs]|h 1.5g") == "WTS {i7969=Mithril Spurs} 1.5g", "an uncoloured link keeps its item")
local shown = Nw.unpackLinks("WTS {i16712=Shadowcraft Gloves#3}")
assert(shown:find("[Shadowcraft Gloves]", 1, true) and shown:find("|cff0070dd", 1, true) and shown:find("|Hitem:16712:", 1, true), "an item the game hasn't loaded still shows its name, a real link and its colour")
GetItemInfo = function(id) if id == 12360 or tostring(id):find("^item:12360:") then return "Arcanite Bar", "|cff1eff00|Hitem:12360|h[Arcanite Bar]|h|r" end end
GetSpellInfo = function(id) if id == 20034 then return "Enchant Weapon - Crusader" end end
assert(Nw.unpackLinks("WTS {i12360} 4g"):find("Arcanite Bar", 1, true) and Nw.unpackLinks("{i999}"):find("[item 999]", 1, true), "rebuilt on arrival")
-- compression: a batch packs and unpacks to the same lines
local batch = {}
for i = 1, 30 do batch[i] = { leader = "Seller S" .. i, age = i, kind = i % 3 == 0 and "l" or "t", chan = 47, text = (i % 3 == 0) and "LFM BRD need heals" or ("WTS {i" .. (12000 + i) .. "} " .. i .. "g each, whisper me") } end
local packedMsgs = Pw.feedPack("Rep R", 47, 5, batch)
local pieces = {}
for _, m in ipairs(packedMsgs) do local k, d = Pw.parse(m) assert(k == "T1" and #m <= 255, "parts parse, within size") pieces[d.part] = d.piece end
local back = Pw.feedUnpack(table.concat(pieces))
assert(back and #back == 30 and back[30].text == batch[30].text and back[1].leader == "Seller S1" and back[3].kind == "l", "round trip")
-- our number 47 (in Trade); other numbers 55 (three users) and 56 (one); one older user on 56; one on ours
for n in pairs(OpenGroup.peers) do OpenGroup.peers[n] = nil end
GetChannelList = function() return 1, "Trade 47", false, 4, "LookingForGroup 47", false end
OpenGroup.peers["Abe A"] = { shard = 55, level = 60, seen = CLOCK, v = "0.6.3-test" }
OpenGroup.peers["Bea B"] = { shard = 55, level = 60, seen = CLOCK, v = "0.6.3-test" }
OpenGroup.peers["Cid C"] = { shard = 55, level = 60, seen = CLOCK, v = "0.6.3-test" }
OpenGroup.peers["Dot D"] = { shard = 56, level = 60, seen = CLOCK, v = "0.6.3-test" }
OpenGroup.peers["Old O"] = { shard = 56, level = 60, seen = CLOCK, v = "0.6.2-beta" }
OpenGroup.peers["Hom H"] = { shard = 47, level = 60, seen = CLOCK, v = "0.6.3-test" }
Nw.chatClaims, Nw.tradeClaims = {}, {} Nw.feedTokensReset()
OpenGroupDB.shareTrade, OpenGroupDB.shareChat = nil, nil
assert(Nw.inTrade(), "in Trade (a city)")
local sends = {}
local saveSend4 = OpenGroup.send
OpenGroup.send = function(to, m, ...) sends[#sends + 1] = { to = to, m = m } end
Nw.feedReport() Nw.feedFlush() sends = {} Nw.feedTokensReset()
Nw.onChat(linked, "Sel S", "2. Trade 47", "Trade 47", nil)
Nw.onChat("lol", "Chat C", "2. Trade 47", "Trade 47", nil)
Nw.onChat("LFM BRD need heals", "Lead L", "4. LookingForGroup 47", "LookingForGroup 47", nil)
assert(Nw.feedReport(), "the reporter sends")
-- the tree root is the 0.6.3 user whose name sorts first: Abe. Our lines go there and come back down
Nw.feedFlush()
local function linesTo(name)
  local ps = {}
  for _, x in ipairs(sends) do if x.to == name and x.m:sub(1, 2) == "T1" then local _, d = Pw.parse(x.m) ps[d.part] = d.piece end end
  if not ps[1] then return nil end
  return Pw.feedUnpack(table.concat(ps))
end
local toRoot = linesTo("Abe A")
print("World chat root gets:", toRoot and #toRoot)
assert(toRoot and #toRoot == 2 and toRoot[1].kind == "l" and toRoot[2].text:find("{i12360=Arcanite Bar", 1, true), "LFG first, then Trade with item IDs; chatter left out")
assert(not linesTo("Bea B") and not linesTo("Old O") and not linesTo("Hom H"), "only to the root")
local claim
for _, x in ipairs(sends) do if x.to == "Hom H" and x.m:sub(1, 2) == "R1" then claim = x.m end end
assert(claim and claim:find(";ct$"), "we claim LFG and Trade on our number")
sends = {}
Nw.onChat(linked, "Sel S", "2. Trade 47", "Trade 47", nil)
assert(not Nw.feedReport() and #sends == 0, "the same line within 10 minutes isn't sent again")
-- out of the city: Trade isn't reported
GetChannelList = function() return 4, "LookingForGroup 47", false end
Nw.onChat("WTS [Thorium Bar] 1g", "Ore O", "2. Trade 47", "Trade 47", nil)
sends = {}
Nw.feedReport() Nw.feedFlush()
assert(not linesTo("Abe A"), "only a player in Trade reports Trade")
-- receiving on 55 as Ann A, for the names after ours: Bea, Cid, Eve, Fay, Rep split in two: Bea and Fay pass it on
GetChannelList = function() return 1, "Trade 55", false end
for n in pairs(OpenGroup.peers) do OpenGroup.peers[n] = nil end
for _, n in ipairs({ "Abe A", "Bea B", "Cid C", "Eve E", "Fay F", "Rep R" }) do OpenGroup.peers[n] = { shard = 55, level = 60, seen = CLOCK, v = "0.6.3-test" } end
OpenGroup.peers["Rep R"].shard = 47
sends = {}
for i = #Nw.feed, 1, -1 do Nw.feed[i] = nil end
OpenGroup.nearby = {} OpenGroup.remote = {}
Nw.resetFeedIndex()
local inMsgs = Pw.feedPack("Rep R", 47, 777, { { leader = "Sel S", age = 3, kind = "t", chan = 47, text = "WTS {i12360} 4g" }, { leader = "Lfm L", age = 2, kind = "l", chan = 47, text = "LFM BRD need heals" } }, "Ann A", nil)
for _, m in ipairs(inMsgs) do OpenGroup.receive(m, "Rep R") end
-- a second chat number's batch in the same round: passed on merged with the first
for _, m in ipairs(Pw.feedPack("Far F", 61, 900, { { leader = "Sixty S", age = 1, kind = "t", chan = 61, text = "WTS {i12360} 3g" } }, "Ann A", nil)) do OpenGroup.receive(m, "Far F") end
Nw.feedFlush()
local merged = linesTo("Bea B")
assert(merged and #merged == 3, "lines from two chat numbers go on as one batch")
local fw = {}
for _, x in ipairs(sends) do if x.m:sub(1, 2) == "T1" then fw[x.to] = true end end
assert(#Nw.feed == 3 and fw["Bea B"] and fw["Fay F"] and not fw["Abe A"] and not fw["Cid C"], "kept, and passed down the tree to our two children")
local _, d1 = Pw.parse((function() for _, x in ipairs(sends) do if x.to == "Bea B" then return x.m end end end)())
assert(d1.lo == "Bea B" and d1.hi == "Fay F", "each child gets its half of the names")
-- Bea logs off: the game says so, and what went to her goes to the halves of her range (Cid, Eve)
sends = {}
Nw.feedTokensReset()
OpenGroup.onPeerGone("Bea B")
local after = {}
for _, x in ipairs(sends) do if x.m:sub(1, 2) == "T1" then after[x.to] = true end end
assert(after["Cid C"] and after["Eve E"] and not after["Bea B"] and not after["Fay F"], "lines to a player who left go to whoever takes their place")
local saveP = OpenGroup.peers["Bea B"]
OpenGroup.peers["Bea B"] = nil
-- the periodic repair: a random OpenGroup user, asked for the lines of the last 21 minutes
sends = {}
Nw.REPAIR_EVERY = 600
for i = 1, 3 do CLOCK = CLOCK + 700 Nw.feedRepairTick() end
local ask
for _, x in ipairs(sends) do if x.m:sub(1, 2) == "B1" then ask = x.m end end
local _, da = Pw.parse(ask or "")
assert(da and da.since and da.since >= CLOCK - 1260 and da.since <= CLOCK - 1200, "repair asks for what's newer than 21 minutes ago")
OpenGroup.peers["Bea B"] = saveP
assert(OpenGroup.remote["Lfm L"] and OpenGroup.remote["Lfm L"].src == "remotechat", "its group posts still feed Browse")
sends = {}
for _, m in ipairs(inMsgs) do OpenGroup.receive(m, "Bea B") end
Nw.feedFlush()
assert(#sends == 0 and #Nw.feed == 3, "a message reaches us once")
C_FriendList.IsIgnored = function(n) return n == "Spam S" end
for _, m in ipairs(Pw.feedPack("Rep R", 47, 778, { { leader = "Spam S", age = 1, kind = "t", chan = 47, text = "WTS stuff" } })) do OpenGroup.receive(m, "Rep R") end
for _, e in ipairs(Nw.feed) do assert(e.leader ~= "Spam S", "ignored players' lines are dropped") end
C_FriendList.IsIgnored = function() return false end
-- history: saved with the settings, searchable by item name
assert(OpenGroupDB.feedHist == Nw.feed, "the history is saved")
Nw.addFeedLine({ key = "Ench E\31LF {e20034}", chan = 56, kind = "t", leader = "Ench E", text = "LF {e20034}", got = CLOCK })
-- a backlog: someone who just logged in asks; we answer once, not passed on
sends = {}
Nw.feedTokensReset()
OpenGroup.receive(Pw.backlogAsk(100), "Abe A")
local bl = linesTo("Abe A")
assert(bl and #bl == 4, "the last hour, to the one who asked")
for _, x in ipairs(sends) do assert(select(2, Pw.parse(x.m)).hop == Pw.FEED_HOPS, "a backlog isn't passed on") end
sends = {}
OpenGroup.receive(Pw.backlogAsk(100), "Bea B")
assert(#sends == 0, "at most one backlog every 2 minutes")
-- the budget: about 24 a minute; a flood past it is dropped, not queued
Nw.feedTokensReset()
local spent = 0
for i = 1, 40 do if Nw.feedSpend() then spent = spent + 1 end end
assert(spent == 12, "a burst of 12, then the budget")
OpenGroup.send = saveSend4
-- the tab
OpenGroupDB.tab = "chat" SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
OpenGroup_UI.showPage("chat")
local chatRows = OpenGroup_UI.chat.rows()
assert(#chatRows == 4, "the lines in the World chat tab")
OpenGroup_UI.chat.search = "arcanite"
assert(#OpenGroup_UI.chat.rows() == 2, "search finds item names")
OpenGroup_UI.chat.search = "crusader"
assert(#OpenGroup_UI.chat.rows() == 1, "and enchant names")
OpenGroup_UI.chat.search = ""
OpenGroupDB.chatShowTrade = false
assert(#OpenGroup_UI.chat.rows() == 1 and OpenGroup_UI.chat.rows()[1].kind == "l", "the Trade filter")
OpenGroupDB.chatShowTrade = nil
local crow = CreateFrame("Button") crow.built = false
INITS[#INITS - 2](crow, chatRows[1])
crow.scripts.OnEnter(crow)
GetChannelList = function() return 1, "Trade 47", false end
print("world chat ok")
-- Report a problem: a link to the issue form with version and details, and no names in it
OpenGroup.lastError = "Interface/AddOns/OpenGroup/Core.lua:12: oops"
local url = OpenGroup.reportURL("bug")
print("report link length:", #url)
assert(url:find("template=from-game.yml", 1, true) and url:find("version=0.6.3", 1, true) and url:find("status=", 1, true), "the form, the version and the details")
local details = OpenGroup.reportDetails()
assert(details:find("Settings: share LFG chat", 1, true) and details:find("Last error: Interface/AddOns/OpenGroup/Core.lua:12: oops", 1, true), "details: settings and the last error")
assert(not url:find("Ann", 1, true) and not details:find("Ann A", 1, true), "no character names")
for n in pairs(OpenGroup.peers) do assert(not details:find(n, 1, true), "no player names") end
assert(#url < 4000, "short enough for a browser")
assert(OpenGroup.reportURL("idea"):find("template=feature.yml", 1, true), "the idea form")
SlashCmdList.OPENGROUP("bug")
print("report ok")
-- "a newer version is out": released versions only, and from two different players
local said = {}
local savePrint2 = OpenGroup.print
OpenGroup.print = function(m) said[#said + 1] = m end
OpenGroup.newest, OpenGroup.toldNewer, OpenGroup.newerFrom = nil, nil, {}
OpenGroup.notePeerVersion("0.9.0-test", "Tess T") OpenGroup.notePeerVersion("0.9.0-test", "Tim T")
assert(#said == 0 and OpenGroup.newest == nil, "a test build never counts as out")
OpenGroup.notePeerVersion("0.7.0", "Rel R")
assert(#said == 0, "one player isn't enough")
OpenGroup.notePeerVersion("0.7.0", "Rel R")
assert(#said == 0, "the same player twice isn't either")
OpenGroup.notePeerVersion("0.7.0", "Two T")
assert(#said == 1 and OpenGroup.newest == "0.7.0", "two players running it: it's out")
OpenGroup.print = savePrint2
OpenGroup.newest, OpenGroup.toldNewer = nil, nil
print("version notice ok")
-- the Group column's slots
local Bs = OpenGroup_UI.browse
local function kinds(sl) local k = {} for i, x in ipairs(sl) do k[i] = x.kind .. (x.role and x.role > 0 and x.role or "") end return table.concat(k, ",") .. (sl.text and ("|" .. sl.text) or "") end
local g3 = { size = 3, need = 2, class = "PRIEST", members = { { class = "PRIEST", role = 4 }, { class = "WARRIOR", role = 1 }, { class = "MAGE", role = 4 } } }
print("slots:", kinds(Bs.slotsOf(g3, { kind = "group" })))
assert(kinds(Bs.slotsOf(g3, { kind = "group" })) == "member4,member1,member4,open2,open4", "members, then exactly what's missing: a healer and one more DPS")
assert(Bs.slotsOf(g3, { kind = "group" }).needs == "Needs Heal, DPS", "in words")
local g2 = { size = 2, need = 6, class = "WARRIOR", members = { { class = "WARRIOR", role = 1 }, { class = "MAGE", role = 4 } } }
assert(kinds(Bs.slotsOf(g2, { kind = "group" })) == "member1,member4,open2,open4,open4" and Bs.slotsOf(g2, { kind = "group" }).needs == "Needs Heal, 2 DPS", "two DPS missing: two DPS slots")
assert(kinds(Bs.slotsOf({ size = 1, need = 6, class = "DRUID" }, { kind = "player" })) == "play2,play4|LFG", "solo: LFG and the roles they play")
print("raid:", kinds(Bs.slotsOf({ size = 12, need = 2 }, { kind = "group" }))) assert(kinds(Bs.slotsOf({ size = 12, need = 2 }, { kind = "group" })) == "|12/20", "a raid: a count")
assert(kinds(Bs.slotsOf({ size = 2, need = 1, class = "ROGUE" }, { kind = "group" })) == "member,unknown,open1,any,any", "a chat post: the poster, ? for the rest")
print("group slots ok")
-- cards: the same items, two to a line, headers on their own
local Bc = OpenGroup_UI.browse
local cl = Bc.cardLines({ { header = "h1", text = "A", count = 3 }, { l = 1 }, { l = 2 }, { l = 3 }, { header = "h2", text = "B", count = 1 }, { l = 4 } })
assert(#cl == 5 and cl[1].header and #cl[2].pair == 2 and #cl[3].pair == 1 and cl[4].header and #cl[5].pair == 1, "two cards a line, a header alone")
OpenGroup.listings["Card C"] = { leader = "Card C", seq = 1, shard = 55, level = 58, size = 3, hops = 0, class = "PRIEST", need = 2, cat = 2, acts = {30}, price = 0, quest = 0, title = "", note = "lava run", got = CLOCK,
  members = { { class = "PRIEST", role = 2 }, { class = "WARRIOR", role = 1 }, { class = "MAGE", role = 4 } } }
OpenGroupDB.tab = "browse" OpenGroupDB.allLevels = true OpenGroupDB.where = "all"
Bc.setCards(true)
SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
local lineWithCard
for _, e in ipairs(PROVIDED) do if e.pair then for _, d in ipairs(e.pair) do if d.l and d.l.leader == "Card C" then lineWithCard = e end end end end
assert(lineWithCard, "the cards view lists the groups in pairs")
local line = CreateFrame("Frame") line.built = false
INITS[#INITS - 1](line, lineWithCard)
for _, c in ipairs(line.cards) do if c.d and c.d.l.leader == "Card C" then
  c.scripts.OnEnter(c)
  assert(c.words[1].text == "Heal" and c.words[2].text == "Tank" and c.words[4].text:find("need dps", 1, true) and c.ask.text == "Ask to join", "slots spelled out, Ask to join")
end end
local hline = CreateFrame("Frame") hline.built = false
INITS[#INITS - 1](hline, { header = "x", text = "Blackrock Depths", count = 2 })
Bc.setCards(false)
assert(OpenGroupDB.browseView == nil, "back to rows, remembered")
OpenGroup.listings["Card C"] = nil
print("cards ok")
-- a quest just accepted: offered, the list doesn't change; shown only when asked
local Qs = OpenGroup_Quests
C_QuestLog.GetQuestObjectives = function(id) if id == 1234 then return { { text = "0/8 Winterfall Pathfinder", type = "monster", finished = false } } end return { { text = "0/1 Stone Circle", type = "event", finished = false } } end
OpenGroupDB.tab = "browse" OpenGroupDB.questPrompt = nil
OpenGroup_UI.browse.setQuest(nil)
OpenGroup.listings["Any A"] = { leader = "Any A", seq = 1, shard = 55, level = 58, size = 3, hops = 0, class = "MAGE", need = 2, cat = 2, acts = {30}, price = 0, quest = 0, title = "", note = "", got = CLOCK }
assert(Qs.worthGrouping(1234) and not Qs.worthGrouping(77), "kill quests are worth a group, talk/explore ones aren't")
Qs.onAccept({ id = 77, title = "The Stone Circle", level = 0 })
assert(OpenGroup_UI.browse.questPrompt == nil, "no offer for a talk/explore quest")
Qs.onAccept({ id = 1234, title = "The Missing Diplomat", level = 0 })
assert(OpenGroup_UI.browse.questPrompt and OpenGroup_UI.browse.questPrompt.id == 1234, "offered")
SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
local seenAny = false
for _, d in ipairs(PROVIDED) do if d.l and d.l.leader == "Any A" then seenAny = true end end
assert(seenAny, "the list still shows groups for the usual filters")
OpenGroupDB.questPrompt = false
OpenGroup_UI.browse.questPrompt = nil
Qs.onAccept({ id = 1234, title = "The Missing Diplomat", level = 0 })
assert(OpenGroup_UI.browse.questPrompt == nil, "the setting turns the offer off")
OpenGroupDB.questPrompt = nil
OpenGroup.listings["Any A"] = nil
print("quest offer ok")
-- Show: groups / players; a header click picks its activity, shift adds, again clears
local Bh = OpenGroup_UI.browse
OpenGroup.listings["Grp G"] = { leader = "Grp G", seq = 1, shard = 55, level = 58, size = 3, hops = 0, class = "MAGE", need = 2, cat = 2, acts = {30}, price = 0, quest = 0, title = "", note = "", got = CLOCK }
OpenGroup.listings["Solo S"] = { leader = "Solo S", seq = 1, shard = 55, level = 58, size = 1, hops = 0, class = "MAGE", need = 4, cat = 2, acts = {30}, price = 0, quest = 0, title = "", note = "", got = CLOCK }
OpenGroupDB.tab = "browse" OpenGroupDB.allLevels = true OpenGroupDB.where = "all" OpenGroupDB.groupBy = "act"
local function shownNames() local t = {} for _, d in ipairs(PROVIDED) do if d.l then t[d.l.leader] = true end end return t end
local function subs() local t = {} for _, d in ipairs(PROVIDED) do if d.sub then t[#t + 1] = d.sub end end return table.concat(t, "/") end
SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
assert(subs():find("Groups/Looking for a group", 1, true), "groups and players under their own labels")
Bh.setShow("groups") SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
assert(shownNames()["Grp G"] and not shownNames()["Solo S"], "groups only")
Bh.setShow("players") SlashCmdList.OPENGROUP("") SlashCmdList.OPENGROUP("")
assert(shownNames()["Solo S"] and not shownNames()["Grp G"], "players only")
Bh.setShow(nil)
Bh.pickActivity(30, false)
assert(#Bh.pickedActivities() == 1 and Bh.pickedActivities()[1] == 30, "a header click: only that activity")
Bh.pickActivity(31, true)
assert(#Bh.pickedActivities() == 2, "shift-click adds")
Bh.pickActivity(31, true) Bh.pickActivity(30, false)
assert(#Bh.pickedActivities() == 0, "clicking the only one again shows everything")
OpenGroup.listings["Grp G"], OpenGroup.listings["Solo S"] = nil, nil
print("show and pick ok")
-- World chat: garbled old lines kept out, the class travels, group posts link to Browse
local Nx, Px = OpenGroup_Nearby, OpenGroup_Proto
for _, bad in ipairs({ "WTS cnIQ3:[item 16712] 30g", "WTS cnIQ3:[item 16712]\\", "300BS WTS cnIQ2:[item 7969] 1.5g", "WTS [item 16712] 30g", "LF [spell 13637]" }) do
  assert(Nx.garbled(bad), "garbled: " .. bad)
  local _, isNew = Nx.addFeedLine({ key = "Bad B\31" .. bad, chan = 56, kind = "t", leader = "Bad B", text = bad, got = CLOCK })
  assert(not isNew, "kept out: " .. bad)
end
assert(not Nx.garbled("WTS {i16712=Shadowcraft Gloves#3} 30g"), "a good line isn't")
local pk = Px.feedPack("Rep R", 47, 4242, { { leader = "Cls C", age = 1, kind = "t", chan = 47, class = "PALADIN", text = "WTS {i12360=Arcanite Bar#2} 4g" } })
local pcs = {} for _, m in ipairs(pk) do local _, d = Px.parse(m) pcs[d.part] = d.piece end
local un = Px.feedUnpack(table.concat(pcs))
assert(un[1].class == "PALADIN", "the poster's class travels with the line")
ChatTypeInfo = { CHANNEL2 = { r = 1, g = 0.7, b = 0.6 } }
GetChannelList = function() return 2, "Trade 47", false end
local cr, cg = Nx.channelColour("t")
assert(cr == 1 and cg == 0.7, "Trade lines in the player's Trade colour")
GetChannelList = function() return 1, "Trade 47", false end
local _, gnew = Nx.addFeedLine({ key = "Lfm Q\31LFM BRD need heals", chan = 56, kind = "l", leader = "Lfm Q", text = "LFM BRD need heals", got = CLOCK })
local gl
for _, e in ipairs(Nx.feed) do if e.leader == "Lfm Q" then gl = e end end
assert(gl and gl.group == true, "a group post is marked")
OpenGroup.remote["Lfm Q"] = { leader = "Lfm Q", src = "remotechat", shard = 56, size = 2, need = 2, acts = {30}, level = 0, got = CLOCK, seq = 0, hops = 0, price = 0, quest = 0, title = "", note = "" }
assert(OpenGroup_UI.browse.focus("Lfm Q") and OpenGroupDB.tab == "browse", "clicking it shows that group in Browse")
assert(not OpenGroup_UI.browse.focus("Nobody N"), "no listing: no switch")
OpenGroup.remote["Lfm Q"] = nil
print("world chat fixes ok")
-- the activity picker: press a box and drag, the same state paints the others
local Bp = OpenGroup_UI.browse
Bp.clearActivities()
Bp.openActivityPicker()
local pinit = INITS[#INITS]
local rows = {}
for i, id in ipairs({ 30, 31, 32 }) do local r = CreateFrame("Button") r.built = false pinit(r, { id = id }) rows[i] = r end
IsMouseButtonDown = function() return true end
rows[1].scripts.OnMouseDown(rows[1], "LeftButton")
rows[2].scripts.OnEnter(rows[2]) rows[3].scripts.OnEnter(rows[3])
assert(#Bp.pickedActivities() == 3, "press and drag ticks them all")
rows[3].scripts.OnMouseUp(rows[3])
rows[2].scripts.OnMouseDown(rows[2], "LeftButton")
rows[3].scripts.OnEnter(rows[3])
assert(#Bp.pickedActivities() == 1 and Bp.pickedActivities()[1] == 30, "pressing a ticked one unticks, and drags that")
IsMouseButtonDown = function() return false end
local trow = CreateFrame("Button") trow.built = false pinit(trow, { title = "Dungeons" })
Bp.clearActivities()
print("picker ok")
-- Find players: several classes, one per click, the players add up
local Ff = OpenGroup_UI.find
Ff.clear()
Ff.classes = { "WARRIOR", "DRUID" } Ff.turn = 0
OpenGroup.scan.inFlight = nil
Ff.paint()
Ff.searchClick()
local cb1 = OpenGroup.scan.inFlight and OpenGroup.scan.inFlight.find
assert(cb1, "a /who went out")
OpenGroup.scan.inFlight = nil
cb1({ { fullName = "War A", level = 58, classStr = "Warrior", filename = "WARRIOR" }, { fullName = "War B", level = 58, classStr = "Warrior", filename = "WARRIOR" } }, 60)
Ff.searchClick()
local cb2 = OpenGroup.scan.inFlight and OpenGroup.scan.inFlight.find
OpenGroup.scan.inFlight = nil
cb2({ { fullName = "Dru A", level = 58, classStr = "Druid", filename = "DRUID" }, { fullName = "War A", level = 58, classStr = "Warrior", filename = "WARRIOR" } }, 2)
print("find notice:", Ff.notice:GetText())
assert(#Ff.results == 3 and #Ff.covered == 2, "both classes in one list, no repeats")
assert(Ff.notice:GetText():find("Warrior", 1, true) and Ff.notice:GetText():find("50+", 1, true) and Ff.notice:GetText():find("Druid 2", 1, true), "a summary per class")
Ff.min:SetText("40")
OpenGroup.scan.inFlight = nil
Ff.searchClick()
OpenGroup.scan.inFlight = nil
assert(#Ff.results == 0, "new levels: a new list")
Ff.clear()
print("find several ok")
-- matches while listed: once per person, one popup per 15 seconds, several at once batched, not in combat
local Bm = OpenGroup_UI.browse
local pops = {}
local saveShow = OpenGroup_Alert.show
OpenGroup_Alert.show = function(o) pops[#pops + 1] = o end
GetNumGroupMembers = function() return 0 end
OpenGroup.listings, OpenGroup.nearby, OpenGroup.remote = {}, {}, {}
OpenGroup.mine = { leader = "Ann A", seq = 1, cat = 2, acts = {30}, need = 4, title = "", note = "", size = 1 }
Bm.resetMatches()
CLOCK = CLOCK + 100
OpenGroup.listings["Grp One"] = { leader = "Grp One", seq = 1, shard = 55, level = 58, size = 3, hops = 0, class = "WARRIOR", need = 4, cat = 2, acts = {30}, price = 0, quest = 0, title = "", note = "", got = CLOCK }
OpenGroup.listings["Grp Heal"] = { leader = "Grp Heal", seq = 1, shard = 55, level = 58, size = 3, hops = 0, class = "WARRIOR", need = 2, cat = 2, acts = {30}, price = 0, quest = 0, title = "", note = "", got = CLOCK }
OpenGroup.listings["Grp Other"] = { leader = "Grp Other", seq = 1, shard = 55, level = 58, size = 3, hops = 0, class = "WARRIOR", need = 4, cat = 2, acts = {31}, price = 0, quest = 0, title = "", note = "", got = CLOCK }
assert(Bm.checkMatches() == 1 and #pops == 1 and pops[1].small:find("wants you", 1, true), "a group for my dungeon that needs my role: one popup")
assert(Bm.checkMatches() == 0 and #pops == 1, "once per person")
OpenGroup.nearby["Grp Two"] = { leader = "Grp Two", src = "finder", size = 2, need = 4, acts = {30}, got = CLOCK, level = 0, shard = 47, cat = 2 }
OpenGroup.nearby["Grp Three"] = { leader = "Grp Three", src = "chat", size = 2, need = 0, acts = {30}, got = CLOCK, level = 0, shard = 47, cat = 2 }
assert(Bm.checkMatches() == 0, "within 15 seconds: waits")
CLOCK = CLOCK + 16
InCombatLockdown = function() return true end
assert(Bm.checkMatches() == 0, "in combat: waits")
InCombatLockdown = function() return false end
assert(Bm.checkMatches() == 2 and pops[2].small:find("2 new", 1, true), "then the two together")
OpenGroupDB.matchAlerts = false
OpenGroup.listings["Grp Four"] = { leader = "Grp Four", seq = 1, shard = 55, level = 58, size = 3, hops = 0, class = "MAGE", need = 4, cat = 2, acts = {30}, price = 0, quest = 0, title = "", note = "", got = CLOCK }
CLOCK = CLOCK + 16
assert(Bm.checkMatches() == 0, "the setting turns them off")
OpenGroupDB.matchAlerts = nil
OpenGroup_Alert.show = saveShow
OpenGroup.mine = nil
OpenGroup.listings, OpenGroup.nearby, OpenGroup.remote = {}, {}, {}
print("match alerts ok")
print("smoke OK")
''')
