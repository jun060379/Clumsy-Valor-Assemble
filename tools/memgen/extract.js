const fs=require('fs');
const L=fs.readFileSync('/tmp/claude-0/-home-claude/b000d2e7-994a-582b-b399-4134c76aec32/scratchpad/hd/game/estelle-prototype.html','utf8').split('\n');
const grab=(a,b)=>L.slice(a-1,b).join('\n');
// constants block of cx v2: lines 5663..5763 (THEME..NIDS)
let src=grab(5663,5763)+'\n'+grab(5940,5941)+'\n'+grab(5947,5948)+'\n'+grab(5207,5208)+'\n'+grab(3640,3673)+'\n'+grab(5464,5464);
src=src.replace(/^const /gm,'var ');
const out=(new Function(src+'\nreturn {SHORT,TABS,LINES,PROF,LVCUM,MAXLV,BR,TIERREQ,TIERN,TIERLV,XLV,XREQ,NODES,BRKC,LVOPEN,MATN,SHEET,LVCURVE,THEME};'))();
const ren=o=>{ if(o&&typeof o==='object'&&!Array.isArray(o)&&'shovel' in o){ const n={}; for(const k in o) n[k==='shovel'?'aida':k]=o[k]; return n; } return o; };
for(const k in out) out[k]=ren(out[k]);
for(const c in out.SHEET){ out.SHEET[c]={moves:out.SHEET[c].moves,passive:out.SHEET[c].passive}; }
fs.writeFileSync(process.argv[2],JSON.stringify(out,null,1));
console.log(Object.keys(out).join(' '));
