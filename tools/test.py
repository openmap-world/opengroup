import sys, os
from lupa.lua51 import LuaRuntime
D = sys.argv[1]
src = {f: open(os.path.join(D, f)).read() for f in ["Proto.lua","Activities.lua","Quests.lua","Core.lua","Scan.lua","Nearby.lua","Widgets.lua","Alert.lua","UI.lua","Minimap.lua","GroupFinderTab.lua"]}

# 1. syntax
lua = LuaRuntime()
for f, s in src.items():
    ok = lua.eval("function(s, n) local f, e = loadstring(s, n) return e or 'ok' end")(s, f)
    print("syntax", f, ok); assert ok == "ok"

# 2. proto
lua.execute(src["Proto.lua"])
t = lua.execute(r'''
local P = OpenGroup_Proto
local out = {}
local function check(name, cond) out[#out+1] = (cond and "PASS " or "FAIL ") .. name end
local m = P.listing{leader="Ji Unit", seq=3, shard=47, level=55, size=2, age=12, hops=0, class="warrior", need=5, cat=2, acts={30, 0, -4, 31}, title="BRD; need|heal", note="x"}
local k, l = P.parse(m)
check("listing roundtrip", k=="L1" and l.leader=="Ji Unit" and l.shard==47 and l.title=="BRD  need heal" and l.age==12 and l.class=="WARRIOR" and l.need==5 and l.cat==2 and #l.acts==2 and l.acts[2]==31)
check("reject nan", P.parse("L1;A;1;nan;1;1;1;0;MAGE;0;0;;0;0;t;n") == nil)
check("reject inf", P.parse("H1;inf;3") == nil)
check("reject old", P.parse("L1;A;1;4;1;1;999;0;MAGE;0;0;;0;0;t;n") == nil)
check("reject empty title", P.parse("L1;A;1;4;1;1;9;0;MAGE;0;0;;0;0;;n") == nil)
check("reject junk", P.parse("zzz") == nil and P.parse(nil) == nil and P.parse(string.rep("a",300)) == nil)
check("hello", select(2, P.parse(P.hello(55, 60))).shard == 55)
check("shard Trade 47", P.shardFromChannel("Trade 47") == 47)
check("shard LFG", P.shardFromChannel("LookingForGroup 47") == 47)
check("shard none", P.shardFromChannel("Trade - City") == nil)
local long = P.listing{leader=string.rep("n",80), seq=2^31, shard=99999, level=60, size=40, age=300, hops=2, title=string.rep("t",80), note=string.rep("z",80)}
check("length cap", #long <= 250)
check("acts only ok", select(2, P.parse("L1;A;1;4;1;2;9;0;MAGE;1;2;30,31;0;0;;")) ~= nil)
local sm = P.listing{leader="Lock L", seq=1, shard=55, level=60, size=1, age=0, hops=0, class="WARLOCK", need=0, cat=P.SUMMON_CAT, acts={}, price=25000, title="Dire Maul", note="have clickers"}
local k2, l2 = P.parse(sm)
check("summon roundtrip", k2=="L1" and l2.price==25000 and l2.title=="Dire Maul" and l2.cat==P.SUMMON_CAT)
check("summon needs warlock", P.parse((sm:gsub("WARLOCK", "MAGE"))) == nil)
local qm = P.listing{leader="Q Q", seq=1, shard=55, level=30, size=2, age=0, hops=0, class="ROGUE", need=1, cat=3, acts={}, quest=1234, title="The Missing Diplomat", note=""}
local k3, l3 = P.parse(qm)
check("quest roundtrip", k3=="L1" and l3.quest==1234 and l3.title=="The Missing Diplomat")
check("reject price overflow", P.parse("L1;A;1;4;1;1;9;0;MAGE;0;0;;999999999999;0;t;n") == nil)
check("reject bad need", P.parse("L1;A;1;4;1;1;9;0;MAGE;9;0;;0;0;t;n") == nil)
local tg = P.relayTargets({a={shard=47}, b={shard=55}, c={shard=56}, s={shard=56}}, {leader="L", shard=47}, "s", 2)
local px = P.peerList({ {"Bob B", 55}, {"Cat:C,x", 56}, {"", 3} })
local kx, dx = P.parse(px)
check("peer exchange roundtrip", kx == "X1" and #dx.peers == 2 and dx.peers[1].name == "Bob B" and dx.peers[2].shard == 56 and dx.peers[2].name == "CatCx")
check("peer exchange rejects junk", P.parse("X1;") == nil and P.parse("X1;a:nan") == nil)
check("hello carries version", select(2, P.parse(P.hello(1, 2))).version == P.VERSION)
check("old hello still parses", select(2, P.parse("H1;47;55")).version == "")
check("version number", P.versionNumber("0.6.0-test") == 600 and P.versionNumber("1.2.10") == 10210 and P.versionNumber("x") == nil)
check("refresh rule", P.isRefresh({seq=1, got=1000}, {seq=1, age=0}, 1100) and not P.isRefresh({seq=1, got=1000}, {seq=1, age=0}, 1020) and not P.isRefresh(nil, {seq=1}, 5))
local bq = P.listing{leader="Pvp P", seq=1, shard=61, level=60, size=1, age=0, hops=0, class="WARRIOR", need=0, cat=P.BGQ_OFFER, acts={40}, title="", note=""}
local kb, lb = P.parse(bq)
check("bg queue roundtrip", kb == "L1" and lb.cat == P.BGQ_OFFER and lb.acts[1] == 40 and P.isBGQ(lb.cat) and not P.isBGQ(2))
check("relay prefers other shards, skips sender", #tg==2 and tg[1]=="b" and tg[2]=="c")
return table.concat(out, "\n")
''')
print(t); assert "FAIL" not in t

# 3. mesh simulation: 4 clients on 3 shards, chain of acquaintances A-B-C-D
bus = []
STUB = r'''
local NAME, SHARD, BUS = ...
CLOCK = 1000
function time() return CLOCK end
function GetTime() return CLOCK end
function UnitName() return NAME end
function UnitLevel() return 58 end
function UnitClass() return "Warrior", "WARRIOR" end
function UnitFactionGroup() return "Horde" end
function GetNumGroupMembers() return 0 end
function GetChannelList() return 1, "General - Orgrimmar", false, 2, "Trade", false end
function GetChannelName(i) if i == 2 then return 2, "Trade", SHARD end return 0 end
function strjoin(sep, ...) return table.concat({...}, sep) end
function tostringall(...) local t = {...} for i=1,select("#",...) do t[i]=tostring(t[i]) end return unpack(t) end
PRINTED = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) PRINTED[#PRINTED+1] = m end }
TICKERS = {}
C_Timer = { NewTicker = function(s, fn) TICKERS[#TICKERS+1] = fn end, After = function() end }
C_ChatInfo = { RegisterAddonMessagePrefix = function() end,
  SendAddonMessage = function(p, msg, kind, target) BUS(NAME, target, msg) return 0 end }
function ChatFrame_AddMessageEventFilter() end
local handlers = {}
function CreateFrame() return { RegisterEvent=function() end, SetScript=function(self, _, fn) handlers[#handlers+1]=fn end } end
function FIRE(...) for _, h in ipairs(handlers) do h(nil, ...) end end
math.random = function(n) return n and 1 or 0.5 end
'''
clients = {}
def mk(name, shard):
    rt = LuaRuntime()
    rt.execute("STUB_ARGS = nil")
    rt.eval("function(s, ...) return loadstring(s)(...) end")(STUB, name, shard, lambda frm, to, msg: bus.append((frm, to, msg)))
    rt.execute("function hooksecurefunc() end"); rt.execute(src["Proto.lua"]); rt.execute(src["Activities.lua"]); rt.execute(src["Quests.lua"]); rt.execute(src["Core.lua"])
    rt.globals().FIRE("ADDON_LOADED", "OpenGroup")
    rt.globals().FIRE("PLAYER_LOGIN")
    clients[name] = rt
for n, s in [("Ann A",47),("Bob B",55),("Cat C",56),("Dan D",57)]: mk(n, s)
def know(a, b, shard): clients[a].eval("function(n,s) OpenGroup.addPeer(n, s, 58) end")(b, shard)
know("Ann A","Bob B",55); know("Bob B","Ann A",47); know("Bob B","Cat C",56); know("Cat C","Bob B",55); know("Cat C","Dan D",57); know("Dan D","Cat C",56)

def run(rounds=60):
    for _ in range(rounds):
        for rt in clients.values():
            for fn in list(rt.globals().TICKERS.values()): pass
            rt.globals().TICKERS[1]()   # pump
        while bus:
            frm, to, msg = bus.pop(0)
            if to in clients: clients[to].globals().FIRE("CHAT_MSG_ADDON", "OpenGroup", msg, "WHISPER", frm)

clients["Ann A"].execute('OpenGroupDB.seq = 0; OpenGroup.post("", "lvl 52+", 2, 2, {30, 31})')
run()
def listing(c, leader): return clients[c].eval("function(l) local x = OpenGroup.listings[l] return x and (OpenGroup.titleOf(x)..' acts '..table.concat(x.acts, ',')..' shard '..x.shard..' hops '..x.hops..' '..x.class..' need '..x.need) end")(leader)
for c in ["Bob B","Cat C","Dan D"]: print(c, "sees:", listing(c, "Ann A"))
assert listing("Bob B","Ann A") and listing("Cat C","Ann A") and listing("Dan D","Ann A")

# a listing stays alive past five minutes while its leader keeps re-announcing (it used to expire)
def advance(sec):
    for _ in range(sec // 5):
        for rt in clients.values():
            rt.execute("CLOCK = CLOCK + 5")
            rt.globals().TICKERS[2]()   # tick: expiry + re-announce
        run(25)
advance(420)
for c in ["Bob B","Cat C","Dan D"]: print(c, "after 7 min:", listing(c, "Ann A"))
assert listing("Bob B","Ann A") and listing("Cat C","Ann A") and listing("Dan D","Ann A")

# peer exchange: a newcomer who knows only Ann ends up knowing the rest
mk("Fay F", 59)
for rt in clients.values(): rt.execute("CLOCK = %d" % clients["Ann A"].eval("CLOCK"))
clients["Fay F"].eval("function(n) OpenGroup.probe(n) end")("Ann A")
run(80)
fay = clients["Fay F"].eval("function() local t = {} for n in pairs(OpenGroup.peers) do t[#t+1] = n end table.sort(t) return table.concat(t, ', ') end")()
print("Fay F knows:", fay)
assert "Bob B" in fay

# an offline peer: the miss line is hidden and the peer is skipped for a while
ann = clients["Ann A"]
ann.execute('OpenGroup.addPeer("Ghost G", 60, 58) OpenGroup.send("Ghost G", "H1;1;1") ')
ann.globals().TICKERS[1]()
hidden = ann.eval('function() return OpenGroup.hideOurMisses(nil, nil, "No player named \'Ghost G\' is currently playing.") end')()
live = ann.eval('function() return OpenGroup.live()["Ghost G"] ~= nil end')()
other = ann.eval('function() return OpenGroup.hideOurMisses(nil, nil, "No player named \'Zed Z\' is currently playing.") end')()
print("miss hidden:", hidden, "| ghost still live:", live, "| unrelated miss hidden:", other)
assert hidden and not live and not other
bus.clear()

# hello from a stranger gets the known listings back
mk("Eve E", 58)
clients["Eve E"].eval("function(n) OpenGroup.probe(n) end")("Dan D")
run()
print("Eve E sees:", listing("Eve E","Ann A"), "| Dan knows Eve:", clients["Dan D"].eval("function() return OpenGroup.peers['Eve E'] ~= nil end")())
assert listing("Eve E","Ann A")

# delist reaches the far end
clients["Ann A"].execute('OpenGroup.delist()')
run()
for c in ["Bob B","Cat C","Dan D"]: print(c, "after delist:", listing(c, "Ann A"))
assert not listing("Bob B","Ann A")
# ping
clients["Ann A"].eval("function(n) OpenGroup.ping(n) end")("Bob B"); run()
print("ping:", [m for m in clients["Ann A"].globals().PRINTED.values() if "ping" in m][-1])

# your-shard rows: chat parsing and the game's Group Finder results, with secret values skipped
nb = LuaRuntime()
nb.execute(r"""
function time() return 5000 end
function GetTime() return 5000 end
function UnitLevel() return 58 end
function GetChannelList() return 1, "General - Orgrimmar", false, 4, "LookingForGroup 47", false end
function CreateFrame() return { RegisterEvent = function() end, SetScript = function() end } end
C_Timer = { After = function(_, fn) fn() end, NewTicker = function() end }
SECRET = setmetatable({}, { __tostring = function() return "secret" end })
function canaccessvalue(v) return v ~= SECRET end
PROBED = {}
OpenGroup = { shard = function() return 47 end, isMe = function(n) return n == "Me Me" end,
  probe = function(n, why) PROBED[#PROBED+1] = n .. ":" .. why return true end, onChange = function() end }
""")
nb.execute(src["Proto.lua"]); nb.execute(src["Activities.lua"]); nb.execute(src["Nearby.lua"])
t = nb.execute(r"""
local N, A = OpenGroup_Nearby, OpenGroup_Activities
local out = {}
local function check(name, cond) out[#out+1] = (cond and "PASS " or "FAIL ") .. name end
local function nameOf(p) return p and p.acts[1] and A.name(p.acts[1]) end
local p = N.parse("LFM BRD need heals and dps, 3/5")
check("lfm brd", p and p.kind == "group" and nameOf(p) == "Blackrock Depths" and p.need == 6 and p.size == 3)
p = N.parse("LF2M strat, tank + healer")
check("lf2m strat", p and p.kind == "group" and nameOf(p) == "Stratholme" and p.need == 3 and p.size == 3)
p = N.parse("LFG |cffffffff|Hitem:1|h[Dire Maul]|h|r east as tank")
check("lfg player dme", p and p.kind == "player" and nameOf(p) == "Dire Maul" and p.need == 1 and p.size == 1)
p = N.parse("lfm dm")
check("dm alone is deadmines", p and nameOf(p) == "The Deadmines")
p = N.parse("LFM DM east need tank")
check("dm east is dire maul", p and nameOf(p) == "Dire Maul")
check("wts skipped", N.parse("WTS [Lionheart Helm] LFM buyers") == nil)
check("guild skipped", N.parse("<Pumpers> recruiting, LFM raiders") == nil)
check("need help skipped", N.parse("need help with a quest pls") == nil)
check("chatter skipped", N.parse("anyone know where the AH is") == nil)
p = N.parse("LF2M Hogger quest")
check("strong lfm without dungeon", p and p.kind == "group" and #p.acts == 0)
N.onChat("LFM ZF need tank", "Ann A", "4. LookingForGroup 47", "LookingForGroup 47", nil)
N.onChat("LFM ZF need tank", "Me Me", "4. LookingForGroup 47", "LookingForGroup 47", nil)
N.onChat("LFM ZF need tank", "Bob B", "5. Guild", "SomeCustom", nil)
N.onChat(SECRET, "Cat C", "4. LookingForGroup 47", "LookingForGroup 47", nil)
local a = OpenGroup.nearby["Ann A"]
check("chat row stored", a and a.src == "chat" and a.chan == "LookingForGroup" and a.shard == 47 and a.need == 1 and a.size > 1)
check("own, other-channel and secret lines ignored", OpenGroup.nearby["Me Me"] == nil and OpenGroup.nearby["Bob B"] == nil and OpenGroup.nearby["Cat C"] == nil)
check("chat poster gets a hello", PROBED[1] == "Ann A:chat")
-- Group Finder
RESULTS = {
  [1] = { leaderName = "Dan D", numMembers = 1, activityIDs = { -15 }, comment = "first time" },
  [2] = { leaderName = "Eve E", numMembers = 3, activityIDs = { -15 }, comment = "" },
  [3] = { leaderName = SECRET, numMembers = 1, activityIDs = { -15 } },
  [4] = { leaderName = "Gone G", numMembers = 1, activityIDs = { -15 }, isDelisted = true },
}
C_LFGList = {
  Search = function() SEARCHED = (SEARCHED or 0) + 1 end,
  GetFilteredSearchResults = function() return 4, { 1, 2, 3, 4 } end,
  GetSearchResultInfo = function(id) return RESULTS[id] end,
  GetSearchResultPlayerInfo = function(id, i) return { classFilename = "PRIEST", level = 52, lfgRoles = { tank = false, healer = true, dps = SECRET } } end,
  GetSearchResultLeaderInfo = function(id) return { classFilename = "WARRIOR", level = 55 } end,
  GetSearchResultMemberCounts = function() return { TANK = 1, HEALER = 0, DAMAGER = 2 } end,
}
N.readFinder()
local d, e = OpenGroup.nearby["Dan D"], OpenGroup.nearby["Eve E"]
check("finder solo", d and d.src == "finder" and d.class == "PRIEST" and d.level == 52 and d.need == 2 and d.note == "first time")
check("finder group needs healer + dps", e and e.size == 3 and e.need == 6 and e.class == "WARRIOR")
check("secret and delisted skipped", OpenGroup.nearby["Gone G"] == nil and N.count("finder") == 2)
check("lfg channel found", N.lfgChannel() == 4)
OpenGroupDB = { nearby = false }
N.expire()
check("switching off clears", next(OpenGroup.nearby) == nil)
return table.concat(out, "\n")
""")
print(t); assert "FAIL" not in t
print("ALL OK")
