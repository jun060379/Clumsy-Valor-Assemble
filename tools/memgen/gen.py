import json, sys
d = json.load(open(sys.argv[1]))
def lit(v):
    if isinstance(v, bool): return 'true' if v else 'false'
    if v is None: return 'null'
    if isinstance(v, (int, float)):
        if isinstance(v, float) and v.is_integer(): return str(int(v)) + '.0' if False else repr(v)
        return repr(v)
    if isinstance(v, str): return json.dumps(v, ensure_ascii=False)
    if isinstance(v, list): return '[' + ', '.join(lit(x) for x in v) + ']'
    if isinstance(v, dict):
        items = []
        for k, x in v.items():
            ks = k if not k.isdigit() else k
            items.append((str(k) if k.isdigit() else json.dumps(k, ensure_ascii=False)) + ': ' + lit(x))
        return '{' + ', '.join(items) + '}'
    raise Exception(type(v))
o = []
w = o.append
w('extends RefCounted')
w('## Data of the character levels and the memory tree (prototype CHARACTER SCREEN v2: LVCURVE / LVCUM / BR / TIERREQ / TIERN / TIERLV /')
w('## XLV / XREQ / NODES / BRKC / LVOPEN / MATN / LINES / PROF, SHEET.moves). Generated from the prototype by tools (memgen); keep the text as is.')
w('## The prototype calls Aida "shovel"; here she is "aida".')
w('')
w('## level growth: Lv1 = ×1 … Lv12 = ×4 (base HP and attack, and the heals that scale with it)')
w('const LVCURVE := ' + lit(d['LVCURVE']))
w('## cumulative 기억석 to stand at each level (Lv1 0, Lv2 12 … Lv12 594)')
w('const LVCUM := ' + lit(d['LVCUM']))
w('const MAXLV := %d' % d['MAXLV'])
w('## branch names (A, B, C) per member')
w('const BR := ' + lit(d['BR']))
w('## per node index in a branch: points needed in that branch, tier name, level it opens at; the four cross nodes (X) open at XLV')
w('const TIERREQ := ' + lit(d['TIERREQ']))
w('const TIERN := ' + lit(d['TIERN']))
w('const TIERLV := ' + lit(d['TIERLV']))
w('const XLV := %d' % d['XLV'])
w('## cross nodes: points needed in branches [A, B, C]')
w('const XREQ := ' + lit(d['XREQ']))
w('## nodes: n name, d text, fx effects, key = the branch\'s key node')
w('const NODES := {')
for c, br in d['NODES'].items():
    w('\t"%s": {' % c)
    for b, L in br.items():
        w('\t\t"%s": [' % b)
        for n in L:
            w('\t\t\t' + lit(n) + ',')
        w('\t\t],')
    w('\t},')
w('}')
w('## 돌파: at these levels the next level needs a material instead of 기억석')
w('const BRKC := ' + lit(d['BRKC']))
w('## what each level opens (shown one level ahead)')
w('const LVOPEN := ' + lit(d['LVOPEN']))
w('## breakthrough materials (the cave\'s lamp is in runes.MATN too)')
w('const MATN := ' + lit(d['MATN']))
w('## 대사집: [분류, 대사, 표정, 메모리얼 전용]')
w('const LINES := {')
for c, L in d['LINES'].items():
    w('\t"%s": [' % c)
    for l in L: w('\t\t' + lit(l) + ',')
    w('\t],')
w('}')
w('const PROF := ' + lit(d['PROF']))
w('const SHORT := ' + lit(d['SHORT']))
w('## the skill tab: SHEET.moves (상단 / 하단 and 공중 are left out of the list, as in the prototype)')
w('const MOVES := {')
for c, s in d['SHEET'].items():
    w('\t"%s": [' % c)
    for m in s['moves']: w('\t\t' + lit(m) + ',')
    w('\t],')
w('}')
open(sys.argv[2], 'w').write('\n'.join(o) + '\n')
