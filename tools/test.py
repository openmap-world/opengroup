import sys, os
from lupa.lua51 import LuaRuntime
D = sys.argv[1]
src = {f: open(os.path.join(D, f)).read() for f in ["Proto.lua","Activities.lua","Quests.lua","Core.lua","Scan.lua","Nearby.lua","Widgets.lua","Alert.lua","UI.lua","AutoInvite.lua","Minimap.lua","GroupFinderTab.lua"]}

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
local gk, gl = P.parse(P.groupListing{leader="Lead L", seq=2, shard=47, level=55, size=3, age=0, hops=0, class="PRIEST", need=4, cat=2, acts={30}, title="", note="x", spots={ P.spot(4) }})
check("group listing roundtrip", gk == "G1" and gl.leader == "Lead L" and gl.acts[1] == 30 and #gl.spots == 1)
check("group unlisted and ask", P.parse(P.groupUnlisted(5)) == "G0" and select(2, P.parse(P.groupUnlisted(5))).seq == 5 and P.parse(P.groupAsk()) == "GQ")
-- other shards' Group Finder digests: spaced names, split into parts under the limit, all back
local many = {}
for i = 1, 60 do many[i] = { leader = "Leader Number" .. i, act = 30 + i, size = 3, need = 6, age = i } end
local msgs = P.finderDigest(56, 7, many)
local back, okLen = {}, true
for _, m in ipairs(msgs) do
  if #m > 250 then okLen = false end
  local k, d = P.parse(m)
  if k == "F1" and d.shard == 56 and d.digest == 7 and d.parts == #msgs then for _, it in ipairs(d.items) do back[#back+1] = it end end
end
check("digest parts under the limit", okLen and #msgs > 1)
check("digest round trip with spaced names", #back == 60 and back[1].leader == "Leader Number1" and back[60].act == 90 and back[60].age == 60)
check("digest caps at 60", (function() local big = {} for i = 1, 80 do big[i] = { leader = "L" .. i, act = 1, size = 1, need = 1, age = 0 } end
  local n = 0 for _, m in ipairs(P.finderDigest(1, 1, big)) do n = n + #select(2, P.parse(m)).items end return n == 60 end)())
local posts = {}
for i = 1, 30 do posts[i] = { leader = "Poster Name" .. i, age = i, act = (i % 2 == 0) and 30 or 0, need = 2, size = 1, text = "LF tank~healer ^ for BRD run number " .. i } end
local cm, cback, cLen = P.chatDigest(56, 3, posts), {}, true
for _, m in ipairs(cm) do if #m > 250 then cLen = false end local k, d = P.parse(m) if k == "C1" then for _, it in ipairs(d.items) do cback[#cback+1] = it end end end
check("chat digest round trip, separators stripped", cLen and #cback == 30 and cback[1].leader == "Poster Name1" and not cback[1].text:find("[~%^]") and cback[2].act == 30)
check("reporting claim", P.parse(P.reporting(12)) == "R1" and select(2, P.parse(P.reporting(12))).groups == 12)
check("bg queue roundtrip", kb == "L1" and lb.cat == P.BGQ_OFFER and lb.acts[1] == 40 and P.isBGQ(lb.cat) and not P.isBGQ(2))
-- open spots
local spots = { P.spot(P.TANK, "warrior"), P.spot(P.DAMAGE, "HUNTER", 54, 52), P.spot(0) }
local sp = P.listing{leader="Spot S", seq=1, shard=47, level=55, size=2, age=0, hops=0, class="PRIEST", need=P.needOfSpots(spots), cat=2, acts={30}, title="", note="lava run", spots=spots}
local ks, ls = P.parse(sp)
check("spots roundtrip", ks == "L1" and #ls.spots == 3 and ls.spots[1].role == P.TANK and ls.spots[1].class == "WARRIOR"
  and ls.spots[2].class == "HUNTER" and ls.spots[2].min == 52 and ls.spots[2].max == 54 and ls.spots[3].role == 0 and ls.spots[3].class == nil and ls.note == "lava run")
check("spots text", P.spotsText(spots) == "T/WARRIOR//,D/HUNTER/52/54,A///")
check("need from spots", P.needOfSpots(spots) == 7 and P.needOfSpots({ P.spot(P.HEALER), P.spot(P.DAMAGE) }) == 6)
check("old format has no spots", #select(2, P.parse("L1;A;1;4;1;2;9;0;MAGE;1;2;30,31;0;0;;")).spots == 0)
-- an older client splits on ";" and reads fields 1 to 16; the spots field after the note changes none of them
local f = {} for field in (sp .. ";"):gmatch("([^;]*);") do f[#f+1] = field end
check("old clients read the same fields", #f == 17 and f[16] == "lava run" and f[10] == "7")
check("junk spots ignored", #P.spotsParse("X/ROGUE//,D/NOTACLASS/1/2,D///,zz") == 2 and P.spotsParse("D/NOTACLASS/1/2,D///")[1].class == nil)
local fat = P.listing{leader=string.rep("n",48), seq=1, shard=47, level=55, size=2, age=0, hops=0, class="PRIEST", need=7, cat=2, acts={30,31,32,33,34,35,36,37}, title="", note=string.rep("z",60),
  spots={ P.spot(1,"WARRIOR",10,60), P.spot(2,"PALADIN",10,60), P.spot(4,"WARLOCK",10,60), P.spot(4,"HUNTER",10,60) }}
check("long listing keeps its spots", #fat <= 250 and #select(2, P.parse(fat)).spots == 4)
-- matching
local hunt = P.spot(P.DAMAGE, "HUNTER", 52, 54)
check("hunter 53 fits", P.spotFits(hunt, "HUNTER", 53, 4) == P.DAMAGE)
check("mage doesn't fit", P.spotFits(hunt, "MAGE", 53, 4) == nil)
check("hunter 58 doesn't fit", P.spotFits(hunt, "HUNTER", 58, 4) == nil)
check("unknown roles: class decides", P.spotFits(P.spot(P.TANK), "WARRIOR", 50, 0) == P.TANK and P.spotFits(P.spot(P.TANK), "MAGE", 50, 0) == nil)
check("any spot takes a role they play", P.spotFits(P.spot(0), "PRIEST", 50, 2) == P.HEALER)
local list = { P.spot(P.DAMAGE), P.spot(P.DAMAGE, "HUNTER"), P.spot(0) }
local bi = P.bestSpot(list, "HUNTER", 53, 4)
check("most specific first", bi == 2)
check("skip taken spots", P.bestSpot(list, "HUNTER", 53, 4, { [2] = true }) == 1)
check("spots from need", P.spotsText(P.spotsFromNeed(3, 3)) == "T///,H///,A///" and P.spotsText(P.spotsFromNeed(0, 3)) == "T///,H///,D///")
local kj, dj = P.parse(P.join("hunter", 53, 4))
check("join request roundtrip", kj == "J1" and dj.class == "HUNTER" and dj.level == 53 and dj.need == 4)
check("join request rejects junk", P.parse("J1;MAGE;nan;4") == nil and P.parse("J1;MAGE;50;9") == nil)
local ki, di = P.parse(P.invited("Blackrock Depths"))
check("invited roundtrip", ki == "I1" and di.title == "Blackrock Depths")
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
-- like Forever: the second part of a name comes back separately
function UnitName() local f, l = NAME:match("^(%S+) (.+)$") if f then return f, l end return NAME end
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
# Dan heard it passed on (2 hops): he asked Ann, she answered with her own listing, so it's confirmed
dan_conf = clients["Dan D"].eval("function() local x = OpenGroup.listings['Ann A'] return x and not x.unconfirmed end")()
print("Dan's copy confirmed by Ann:", dan_conf)
assert dan_conf

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

# two-part names: every client knows itself by its full name, and a relayed listing carries it
for c in ["Ann A","Dan D"]: assert clients[c].eval("function() return OpenGroup.me() end")() == c
print("names from units:", clients["Ann A"].eval("function() return OpenGroup.me() end")())

# guards: a passed-on listing for a leader who never answers is dropped after a minute
d = clients["Dan D"]
d.globals().FIRE("CHAT_MSG_ADDON", "OpenGroup", "L1;Nobody N;5;61;60;3;0;1;MAGE;4;2;30;0;0;;fake", "WHISPER", "Cat C")
was = d.eval("function() local x = OpenGroup.listings['Nobody N'] return x and x.unconfirmed end")()
d.execute("CLOCK = CLOCK + 65"); d.globals().TICKERS[2]()
gone = d.eval("function() return OpenGroup.listings['Nobody N'] == nil end")()
print("fake relayed listing: unconfirmed", was, "| dropped", gone)
assert was and gone
# a flood from one sender: past the burst, messages are dropped
before = d.eval("function() return OpenGroup.stats.dropped or 0 end")()
for i in range(40): d.globals().FIRE("CHAT_MSG_ADDON", "OpenGroup", "P1;tok%d" % i, "WHISPER", "Spam S")
after = d.eval("function() return OpenGroup.stats.dropped or 0 end")()
print("flood dropped:", after - before)
assert after - before >= 15
# your ignore list: nothing from them is kept
d.execute("C_FriendList = C_FriendList or {} C_FriendList.IsIgnored = function(n) return n == 'Bad B' end")
d.globals().FIRE("CHAT_MSG_ADDON", "OpenGroup", "L1;Bad B;1;61;60;3;0;0;MAGE;4;2;30;0;0;;x", "WHISPER", "Bad B")
d.globals().FIRE("CHAT_MSG_ADDON", "OpenGroup", "L1;Bad B;1;61;60;3;0;1;MAGE;4;2;30;0;0;;x", "WHISPER", "Cat C")
print("ignored player's listing kept:", d.eval("function() return OpenGroup.listings['Bad B'] ~= nil end")())
assert d.eval("function() return OpenGroup.listings['Bad B'] == nil end")()

# your-shard rows: chat parsing and the game's Group Finder results, with secret values skipped
nb = LuaRuntime()
nb.execute(r"""
function time() return 5000 end
function GetTime() return 5000 end
function UnitLevel() return 58 end
function GetChannelList() return 1, "General - Orgrimmar", false, 4, "LookingForGroup 47", false end
NB_HANDLERS = {}
function CreateFrame() return { RegisterEvent = function() end, SetScript = function(_, _, fn) NB_HANDLERS[#NB_HANDLERS+1] = fn end } end
function GetTime() return NB_T or 0 end
PRINTED = {}
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
-- a blocked action right after our search is the search: searches stop; another addon's block is ignored
OpenGroup.print = function(...) PRINTED[#PRINTED+1] = table.concat({...}, " ") end
local onEvent = N.onEvent or NB_HANDLERS[#NB_HANDLERS]
onEvent(nil, "ADDON_ACTION_BLOCKED", "SomeOtherAddon", "UNKNOWN()")
check("other addons' blocks ignored", N.blocked == nil and not N.noSearch)
N.searchAt, NB_T = 100, 100.2
onEvent(nil, "ADDON_ACTION_BLOCKED", "OpenGroup", "UNKNOWN()")
check("block right after a search pauses searches", N.noSearch == true and N.blocked == "C_LFGList.Search" and #PRINTED == 1)
onEvent(nil, "ADDON_ACTION_BLOCKED", "OpenGroup", "UNKNOWN()")
check("said once", #PRINTED == 1)
return table.concat(out, "\n")
""")
print(t); assert "FAIL" not in t

# Browse rows: level band, fit, sorting, grouping, the Where migration, columns
br = rt   # Core is loaded there already
br.execute(r"""
local A = OpenGroup_Activities
A.info[30] = { id = 30, name = "Blackrock Depths", short = "BRD", min = 52, max = 60, cat = 2 }
A.info[32] = { id = 32, name = "Ragefire Chasm", short = "RFC", min = 13, max = 18, cat = 2 }
""")
t = br.execute(r"""
local L, P = OpenGroup, OpenGroup_Proto
local out = {}
local function check(name, cond) out[#out+1] = (cond and "PASS " or "FAIL ") .. name end
local function row(t) local r = L.rowOf(t, 47) r.dist = L.levelDistance(r, 58) return r end
local brd = row{ leader = "A", level = 56, size = 3, need = 4, acts = {30}, shard = 55, got = 900, title = "", note = "" }
local rfc = row{ leader = "B", level = 15, size = 2, need = 4, acts = {32}, shard = 47, got = 990, title = "", note = "" }
local free = row{ leader = "C", level = 55, size = 1, need = 2, acts = {}, shard = 47, got = 950, title = "Strat", note = "", src = "chat" }
local far = row{ leader = "D", level = 40, size = 1, need = 2, acts = {}, shard = 47, got = 950, title = "Mara", note = "", src = "finder" }
check("brd in band at 58", L.inBand(brd, 58))
check("band slack: 63 still in", L.inBand(brd, 63) and not L.inBand(brd, 64) and L.inBand(brd, 49) and not L.inBand(brd, 48))
check("rfc out of band", not L.inBand(rfc, 58))
check("no range: leader within 5", L.inBand(free, 58) and not L.inBand(far, 58))
check("where", brd.where == "other" and rfc.where == "mine" and free.where == "chat" and far.where == "finder"
  and L.whereOK(brd, "og") and not L.whereOK(free, "og") and L.whereOK(free, "all") and L.whereOK(far, "finder"))
local me = { class = "MAGE", level = 58, roles = 0, grouped = false, need = 0 }
brd.fit, brd.dim = L.rowFit(brd, me)
local tankOnly = row{ leader = "E", level = 58, size = 4, need = 1, acts = {30}, shard = 55, got = 999, title = "", note = "" }
tankOnly.fit, tankOnly.dim = L.rowFit(tankOnly, me)
local full = row{ leader = "F", level = 58, size = 5, need = 0, acts = {30}, shard = 55, got = 999, title = "", note = "" }
full.fit, full.dim = L.rowFit(full, me)
local spotGroup = row{ leader = "G", level = 58, size = 3, need = 4, acts = {30}, shard = 55, got = 800, title = "", note = "", spots = { P.spot(4, "HUNTER") } }
spotGroup.fit, spotGroup.dim = L.rowFit(spotGroup, me)
check("fit: a mage fits a damage group", brd.fit and not brd.dim)
check("dim: tank only, full, hunter spot", tankOnly.dim and full.dim and spotGroup.dim and not spotGroup.fit)
local rows = { full, tankOnly, rfc, brd }
L.sortRows(rows)
check("relevance: fit first, dimmed last", rows[1] == brd and (rows[4] == full or rows[4] == tankOnly) and (rows[3] == full or rows[3] == tankOnly))
L.sortRows(rows, "leader", false)
check("sort by leader", rows[1].leader == "A" and rows[4].leader == "F")
L.sortRows(rows, "leader", true)
check("sort by leader reversed", rows[1].leader == "F")
L.sortRows(rows, "age", false)
check("sort by age: newest first", rows[1].got == 999)
local groups = L.groupRows({ brd, rfc, tankOnly, free }, "act")
check("group by activity: nearest first, counts", groups[1].text == "Blackrock Depths" and #groups[1].rows == 2 and groups[#groups].text == "Ragefire Chasm")
local shards = L.groupRows({ free, rfc, brd, far }, "shard")
check("group by shard: other shards, yours, finder, chat", shards[1].text == "Chat 55" and shards[2].text == "Your server" and shards[3].text == "Group Finder" and shards[4].text == "LFG chat")
check("no grouping", L.groupRows({ brd }, "off") == nil)
check("migrate other shards only", L.migrateBrowse({ otherOnly = true }).where == "other")
check("migrate group finder off", L.migrateBrowse({ nearby = false }).where == "og")
local m = L.migrateBrowse({})
check("migrate defaults", m.where == "all" and m.groupBy == "act" and m.otherOnly == nil)
check("migrate keeps a choice", L.migrateBrowse({ where = "finder", otherOnly = true }).where == "finder")
local narrow, wide = L.columns(380), L.columns(1000)
check("narrow: activity still readable, extras dropped", narrow.at.act.w >= 96 and narrow.hidden.size and narrow.at.leader and narrow.at.needs)
check("wide: every column, activity takes the rest", not next(wide.hidden) and wide.at.act.w > 400)
local last = wide.order[#wide.order]
check("wide: columns fill the width", math.abs(last.x + last.w - 1000) < 1)
-- whispers: unreadable values are counted, never stored; unread counts; OpenGroup people first
local SECRETV = setmetatable({}, { __tostring = function() return "secret" end })
canaccessvalue = function(v) return v ~= SECRETV end
L.whispers, L.whisperLinks, L.whisperHidden = {}, {}, 0
L.listings = L.listings or {}
L.addWhisper("hi, still need a healer?", "Ann A", false, 100, false)
L.addWhisper("yes, inv", "Ann A", true, 101, false)
L.addWhisper(SECRETV, "Ann A", false, 102, false)
L.addWhisper("hello", SECRETV, false, 103, false)
L.addWhisper("lf tank?", "Bob B-Realm", false, 104, false)
local ann = L.whispers["Ann A"]
check("whispers stored, secret text hidden", ann and #ann.msgs == 3 and ann.msgs[3].hidden and ann.msgs[3].text == nil and ann.msgs[2].out)
check("secret sender skipped, both counted", L.whisperHidden == 2)
check("unread counts incoming only", ann.unread == 2 and L.whispers["Bob B"].unread == 1 and L.whisperUnread() == 3)
L.addWhisper("ok", "Bob B", false, 105, true)
check("viewing: no unread", L.whispers["Bob B"].unread == 1)
L.whisperLinks["Ann A"] = true
local wl = L.whisperList(false)
check("OpenGroup people first", wl[1].name == "Ann A" and wl[2].name == "Bob B")
check("OpenGroup only", #L.whisperList(true) == 1)
canaccessvalue = nil
local mid = L.columns(470)
local lm = mid.order[#mid.order]
check("default width fills too", math.abs(lm.x + lm.w - 470) < 1 and mid.at.where ~= nil)
return table.concat(out, string.char(10))
""")
print(t); assert "FAIL" not in t
print("ALL OK")
