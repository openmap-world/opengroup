import sys, os
from lupa.lua51 import LuaRuntime
# usage: python tools/feed_bench.py OpenGroup
# How many World chat lines fit in a message: the corpus lines worth passing on (plus some
# typical trade ads with item links), packed plainly vs compressed (P.feedPack).
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
D = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
lua = LuaRuntime()
lua.execute(r"""
function time() return 5000 end
function GetTime() return 5000 end
function UnitLevel() return 58 end
function GetChannelList() return 1, "Trade 47", false end
function CreateFrame() return { RegisterEvent = function() end, SetScript = function() end } end
C_Timer = { After = function() end, NewTicker = function() end }
OpenGroup = { shard = function() return 47 end, isMe = function() return false end, probe = function() end, short = function(n) return n end }
""")
for f in ["Proto.lua", "Activities.lua", "Nearby.lua"]: lua.execute(open(os.path.join(D, f), encoding="utf-8").read())
lines = []
for raw in open(os.path.join(here, "chat_corpus.txt"), encoding="utf-8"):
    if raw.startswith("#") or "|" not in raw: continue
    lines.append(raw.split("|", 1)[1].strip())
ads = [
    "WTS |cff1eff00|Hitem:12360::::::::60:::::::|h[Arcanite Bar]|h|r 4g each, whisper me",
    "WTS |cff0070dd|Hitem:12640::::::::60:::::::|h[Lionheart Helm]|h|r 120g pst",
    "WTB |cffffffff|Hitem:14047::::::::60:::::::|h[Runecloth]|h|r x200, paying 30s each",
    "LF enchanter for |cffffd000|Henchant:20034|h[Enchant Weapon - Crusader]|h|r, my mats + tips",
    "WTS |cff1eff00|Hitem:13444::::::::60:::::::|h[Major Mana Potion]|h|r 1g each, x20",
    "WTS |cffa335ee|Hitem:12590::::::::60:::::::|h[Felstriker]|h|r 600g",
    "Selling |cff1eff00|Hitem:12359::::::::60:::::::|h[Thorium Bar]|h|r 50s each, cod",
    "WTB |cffffffff|Hitem:12808::::::::60:::::::|h[Essence of Undeath]|h|r 2g each",
]
lines += ads * 3
bench = lua.eval(r"""
function(list)
  local N, P = OpenGroup_Nearby, OpenGroup_Proto
  local items = {}
  for i = 1, #list do
    local t = list[i]
    if N.feedKeep(t) then items[#items + 1] = { leader = "Player Name" .. (#items % 40), age = 30, kind = "t", chan = 47, text = N.packLinks(t) } end
  end
  -- plain: one entry after another, as many as fit in a 250-byte message
  local head = #("T1;Player Name;47;123456789;1;1;0;")
  local msgs, len = 1, 0
  for _, it in ipairs(items) do
    local e = #(("%s^%d^%s^%d^%s"):format(it.leader, it.age, it.kind, it.chan, it.text)) + 1
    if len + e > 250 - head then msgs = msgs + 1 len = 0 end
    len = len + e
  end
  local packed = #P.feedPack("Player Name", 47, 123456789, items)
  -- the same with the links left as they come from chat (no ID packing), plain
  local raw, rlen = 1, 0
  for i = 1, #list do
    local t = list[i]
    if N.feedKeep(t) then
      local e = #t + 25
      if rlen + e > 250 - head then raw = raw + 1 rlen = 0 end
      rlen = rlen + e
    end
  end
  return #items, raw, msgs, packed
end
""")
lst = lua.table_from(lines)
n, raw, plain, packed = bench(lst)
print(f"{n} lines worth passing on")
print(f"  as typed (full links):        {raw} messages, {n/raw:.1f} lines per message")
print(f"  links as IDs, plain:          {plain} messages, {n/plain:.1f} lines per message")
print(f"  links as IDs, compressed:     {packed} messages, {n/packed:.1f} lines per message")
