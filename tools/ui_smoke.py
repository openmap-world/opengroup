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
for f in ["Proto.lua","Activities.lua","Quests.lua","Core.lua","Scan.lua","Nearby.lua","Widgets.lua","Alert.lua","UI.lua","Minimap.lua","GroupFinderTab.lua"]:
    lua.execute(open(os.path.join(D,f)).read())
lua.execute(r'''
OpenGroupDB={} 
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
assert(catTwice == 1, "an OpenGroup user who also posts in chat shows once")
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
print("smoke OK")
''')
