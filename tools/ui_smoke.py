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
assert(items["Other chat numbers"] and items["All levels"] and items["Compact rows"] and items["Chat number"], "filter menu items")
items["Other chat numbers"]() assert(OpenGroupDB.where == "other" and B.filtersActive(), "Where from the menu")
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
-- one click-only call per click: Refresh searches the Group Finder and skips /who; a tab click only /who
WHO, SEARCHES = 0, 0
C_FriendList.SendWho = function() WHO = WHO + 1 end
C_LFGList.Search = function() SEARCHES = SEARCHES + 1 end
OpenGroup_Nearby.noSearch = nil
CLOCK = CLOCK + 1000
OpenGroup.scan.last, OpenGroup.scan.inFlight = nil, nil
OpenGroup.scan.auto(true, true)
print("refresh click: searches", SEARCHES, "who", WHO)
assert(SEARCHES == 1 and WHO == 0, "one restricted call per click")
OpenGroup.scan.auto(false)
assert(SEARCHES == 1 and WHO == 1, "a tab click runs /who only")
-- an opening click with stale Group Finder results searches once (no /who); with fresh ones, /who
WHO, SEARCHES = 0, 0
CLOCK = CLOCK + 1000
OpenGroup.scan.last, OpenGroup.scan.inFlight = nil, nil
OpenGroup_Nearby.resultsAt = nil
OpenGroup.scan.auto(true)
assert(SEARCHES == 1 and WHO == 0, "stale: the opening click searches, no /who")
OpenGroup_Nearby.resultsAt = GetTime()
CLOCK = CLOCK + 10
OpenGroup.scan.auto(true)
assert(SEARCHES == 1 and WHO == 1, "fresh: no search, the /who instead")
-- after a refusal only a direct Search click may try again
OpenGroup_Nearby.noSearch = true
CLOCK = CLOCK + 10
OpenGroup.scan.last = CLOCK
OpenGroup.scan.auto(true, true)
assert(SEARCHES == 1, "background attempts stay off after a refusal")
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
-- the Group Finder path is off (the game's list is shared); with the flag on it still works
for _, m in ipairs(Pr.finderDigest(56, 1, { { leader = "Ignored I", act = 30, size = 3, need = 4, age = 20 } })) do OpenGroup.receive(m, "Rep R") end
assert(OpenGroup.remote["Ignored I"] == nil, "Group Finder digests are ignored while sharing is off")
N.SHARE_FINDER = true
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
N.SHARE_FINDER = false
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
INITS[#INITS](frow, F.results[4])
print("find row badge:", frow.badge:GetText())
ChatFrame_SendTell = nil ChatEdit_GetActiveWindow = nil
-- one LFG chat reporter per chat number: Trade 56 is another number, so it gets the digest
local Nb = OpenGroup_Nearby
OpenGroup.nearby = {}
OpenGroup.nearby["Near Two"] = { leader = "Near Two", src = "chat", size = 1, need = 1, acts = {}, got = CLOCK, level = 0, shard = 47, title = "LFM strat", note = "" }
OpenGroup.nearby["GF Two"] = { leader = "GF Two", src = "finder", size = 3, need = 6, acts = {30}, got = CLOCK, level = 0, shard = 47 }
for n in pairs(OpenGroup.peers) do OpenGroup.peers[n] = nil end
OpenGroup.peers["Mate M"] = { shard = 47, level = 60, seen = CLOCK }
Nb.resultsAt = GetTime() Nb.claims = {}
local h0, c0 = Nb.stats.harvested, Nb.stats.chatShared
assert(Nb.report() == false, "nobody on another number: nothing to report")
OpenGroup.peers["Other O"] = { shard = 56, level = 60, seen = CLOCK }
assert(Nb.report() == true and Nb.stats.chatShared == c0 + 1, "chat goes to another number")
assert(Nb.stats.harvested == h0, "no Group Finder digest")
OpenGroup.receive(Pr2.reporting(3), "Other O")
assert(Nb.claims["Other O"] == nil, "a reporter on another number doesn't make us stand by")
OpenGroup.receive(Pr2.reporting(3), "Mate M")
assert(Nb.claims["Mate M"], "one on our number does")
OpenGroupDB.shareChat = nil
assert(Nb.shareChat() == Nb.SHARE_CHAT_DEFAULT, "chat sharing default is one flag")
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
OpenGroup_Nearby.SHARE_FINDER = true
OpenGroup.receive(dm[1], "Rep R")
OpenGroup_Nearby.SHARE_FINDER = false
local rm = OpenGroup.remote["Multi M"]
assert(rm and #rm.acts == 3 and rm.acts[2] == 51, "other-server rows keep every activity")
print("multi-activity ok")
print("smoke OK")
''')
