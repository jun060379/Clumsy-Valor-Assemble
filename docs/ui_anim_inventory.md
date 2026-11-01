# UI animation inventory

Source: game/estelle-prototype.html (169 `@keyframes`, 123 `.animate(` calls inside the page plus the gpt/*.js modules, ~90 distinct CSS transitions).
Status: **ported earlier** (already in the port before this branch, checked against frames), **ported here** (this branch, `uianim`), **partial**, **not ported** (reason given), **superseded** (overridden by later CSS in the prototype itself).

Motion helpers live in `scripts/ui_anim.gd` (named cubic-beziers, keyframe lists with per-segment easing, CSS-transition store, springs, a group "pen" that gives immediate-mode drawing element-level transform/opacity, and web hooks `cvaTS` / `cvaT` / `cvaX` / `cvaBook` for slow-motion screenshots).

## @keyframes (unique names)

- `csdrift` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.cs-stars => animation:csdrift 90s linear infinite`
- `csspin` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.cs-ring i => animation:csspin 44s linear infinite`
- `cschg` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.cs-sprw.chg => animation:cschg .5s var(--ez)`
- `csbob` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.cs-node .fl => animation:csbob 3.2s ease-in-out var(--b) infinite`
- `cspop` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.cs-node .dia.pop => animation:cspop .5s var(--ez)`
- `cssweep` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.cs-sweep.go => animation:cssweep .65s cubic-bezier(.45,0,.2,1)`
- `csbgin` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.csv.op .cs-bg => animation:csbgin .6s var(--ez) both`
- `csl` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.csv.op .cs-menu button => animation:csl .5s var(--ez) both`
- `csrt` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.csv.op .cs-wcard => animation:csrt .55s var(--ez) .4s both`
- `cstp` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.csv.op .cs-sw button => animation:cstp .5s var(--ez) both`
- `csup` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.csv.op .cs-stage => animation:csup .75s var(--ez) .12s both`
- `csfd` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.csv.op .cs-ind => animation:csfd .4s ease-out .32s both`
- `csain` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.cs-artw.in => animation:csain .6s var(--ez) both`
- `csaout` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.cs-artw.out => animation:csaout .26s cubic-bezier(.5,0,.9,.5) both`
- `csbreath` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.cs-artb => animation:csbreath 4.4s ease-in-out infinite`
- `cshop` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.cs-artj.hop => animation:cshop .55s cubic-bezier(.2,1.4,.4,1)`
- `csshake` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.cs-artj.shake => animation:csshake .45s linear`
- `csemo` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.cs-emo.go => animation:csemo 1.1s cubic-bezier(.2,1.6,.4,1) forwards`
- `csstamp` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.cs-hd h2.stamp => animation:csstamp .55s cubic-bezier(.2,1.5,.4,1) .08s both`
- `csblink` — Character screen v1 (status / memory nodes) — **not ported** — ui_char.gd is being rebuilt on the cva-mem branch; left alone to keep merges clean  
  selector: `.cs-sk.play .pl => animation:csblink .5s steps(2) infinite`
- `qte` — HUD bench QTE — **partial** — face grows + glow ring + timer arc; no striped call-out card  
  selector: `#chr.qte => #chr.qte{animation:qte .18s infinite alternate`
- `drift` — Title — **ported earlier** — backdrop drift, 탭하여 입장 blink, logo bob  
  selector: `#title::before => animation:drift 60s linear infinite`
- `bob` — Title — **ported earlier** — backdrop drift, 탭하여 입장 blink, logo bob  
  selector: ``
- `blink` — Title — **ported earlier** — backdrop drift, 탭하여 입장 blink, logo bob  
  selector: `#title.done .press => animation:blink 1.4s steps(2) infinite`
- `pulse` — HUD touch buttons (ULT / attack) — **partial** — ult readiness shown on the crescent arc; touch button shine/stripes not drawn  
  selector: `#bUlt.ready => animation:pulse 1.2s ease-in-out infinite`
- `qtein` — HUD bench QTE — **partial** — face grows + glow ring + timer arc; no striped call-out card  
  selector: `#pcol .ps.qte => animation:qtein .2s ease-out,qtep .45s .2s ease-in-out infinite alternate`
- `qtep` — HUD bench QTE — **partial** — face grows + glow ring + timer arc; no striped call-out card  
  selector: `#pcol .ps.qte => animation:qtein .2s ease-out,qtep .45s .2s ease-in-out infinite alternate`
- `panelIn` — old v1 panels / dialogue — **superseded** — overridden by the v2/v3 CSS in the prototype  
  selector: `#opts .box,#party .box,#stat .box,#best .box => animation:panelIn .24s cubic-bezier(.2,.9,.3,1.`
- `dnb` — old v1 panels / dialogue — **superseded** — overridden by the v2/v3 CSS in the prototype  
  selector: `#dlg.done .dnext => animation:dnb 1s infinite`
- `dpIn` — old v1 panels / dialogue — **superseded** — overridden by the v2/v3 CSS in the prototype  
  selector: `#dlg .dpor => animation:dpIn .35s cubic-bezier(.2,.8,.2,1)`
- `dtIn` — old v1 panels / dialogue — **superseded** — overridden by the v2/v3 CSS in the prototype  
  selector: `#dlg .dtxt.in => animation:dtIn .25s ease-out`
- `dnb2` — old v1 panels / dialogue — **superseded** — overridden by the v2/v3 CSS in the prototype  
  selector: `#dlg.done .dnext => animation:dnb2 1s infinite!important`
- `dcIn` — old v1 panels / dialogue — **superseded** — overridden by the v2/v3 CSS in the prototype  
  selector: `#dlg .dch button => animation:dcIn .28s cubic-bezier(.2,.8,.2,1) both!important`
- `lrArt` — Loot / clear tiles — **ported earlier** — clear_screen.gd  
  selector: `#lootres .lr-art => animation:lrArt .5s cubic-bezier(.2,1.4,.4,1) both`
- `lrPop` — Loot / clear tiles — **ported earlier** — clear_screen.gd  
  selector: `#lootres .lr-head b => animation:lrPop .4s .15s both`
- `lrTile` — Loot / clear tiles — **ported earlier** — clear_screen.gd  
  selector: `.ltile => animation:lrTile .32s var(--d,0ms) both`
- `cx_spin` — Character screen v2 (#cx) — **partial** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .burst => animation:cx_spin 70s linear infinite`
- `cx_breath` — Character screen v2 (#cx) — **partial** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .artb => animation:cx_breath 4.2s ease-in-out infinite`
- `cx_slam` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .art.slam => animation:cx_slam .62s var(--bk) both`
- `cx_hop` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .artj.hop => animation:cx_hop .55s var(--bk)`
- `cx_shake` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .artj.shake => animation:cx_shake .42s linear`
- `cx_emo` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .emo.go => animation:cx_emo 1.2s var(--bk) forwards`
- `cx_drop` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .name i.drop => animation:cx_drop .5s var(--bk) both`
- `cx_flash` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .flash.go => animation:cx_flash .38s var(--mv)`
- `cx_gdpop` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .gd.pop => animation:cx_gdpop .42s var(--bk)`
- `cx_shout` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .shout.pop => animation:cx_shout .45s var(--bk)`
- `cx_xgear` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .xa[data-k=gear].on => animation:cx_xgear .7s var(--bk)`
- `cx_xskill` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .xa[data-k=skill].on => animation:cx_xskill .5s cubic-bezier(.1,1.4,.3,1)`
- `cx_speed` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .xa[data-k=skill].on .speed => animation:cx_speed .55s ease-out`
- `cx_xrec` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .xa[data-k=match].on => animation:cx_xrec .75s var(--bk)`
- `cx_mpulse` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .mn.next => animation:cx_mpulse 1.2s ease-in-out infinite`
- `cx_drift` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx.memo .xa[data-k=rec] .xj => animation:cx_drift 14s ease-in-out infinite alternate`
- `cx_memin` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx.memo .xa[data-k=rec].on .xj => animation:cx_memin 1.6s cubic-bezier(.2,.7,.2,1),cx_drift 14`
- `cx_bloom` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx.memo .xa[data-k=rec].on .bloom => animation:cx_bloom 1.4s ease-out`
- `cx_twk` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx.memo .twk => animation:cx_twk 3.2s ease-in-out infinite alternate`
- `cx_mn` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx.op .menu button => animation:cx_mn .5s var(--bk) both`
- `cx_cd` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx.op .chars button => animation:cx_cd .5s var(--bk) both`
- `cx_flb` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .bl.flashb => animation:cx_flb .45s var(--bk)`
- `cx_mnb` — Character screen v2 (#cx) — **not ported** — ui_char.gd belongs to the cva-mem branch (entrance slam, tab cut-ins, name drop, memory nodes)  
  selector: `#cx .mn.burstn => animation:cx_mnb .6s var(--bk)`
- `txdots` — Menu sweep NOW LOADING — **ported here** — sweep.gd  
  selector: `#tx.ld .ld u::after => animation:txdots 1s steps(4) infinite`
- `phspin` — Main menu hub — **ported earlier** — menu.gd  
  selector: `#phub .burst => animation:phspin 80s linear infinite`
- `phbr` — Main menu hub — **ported earlier** — menu.gd  
  selector: `#phub .artb => animation:phbr 4.2s ease-in-out infinite`
- `phslam` — Main menu hub — **ported earlier** — menu.gd  
  selector: `#phub .art.slam => animation:phslam .6s var(--bk) both`
- `phip` — Main menu hub — **ported earlier** — menu.gd  
  selector: `#phub .info.pop => animation:phip .35s var(--bk)`
- `phmd` — Main menu hub — **ported earlier** — menu.gd  
  selector: `#phub.op .mi => animation:phmd .45s var(--bk) both`
- `fmdots` — Guild / adventure book — **ported earlier** — fame_book.gd  
  selector: `#fm .bg => animation:fmdots 7s linear infinite`
- `fmsl` — Level-up popup (#fmup) — **ported earlier** — fame_fx.gd lvCut  
  selector: `#fmup .sl => animation:fmsl .5s cubic-bezier(.2,1,.3,1) forwards`
- `fmin` — Level-up popup (#fmup) — **ported earlier** — fame_fx.gd lvCut  
  selector: `#fmup img => animation:fmin .6s .15s cubic-bezier(.2,1.2,.4,1) both`
- `fm_breath` — Guild / adventure book — **ported earlier** — fame_book.gd  
  selector: `#fm .band => animation:fm_breath 7s ease-in-out infinite`
- `fm_bump` — Guild / adventure book — **ported here** — fame_book.gd  
  selector: `#fm .wal.bump .tk => animation:fm_bump .55s cubic-bezier(.2,1.5,.4,1) both`
- `fm_swing` — Guild / adventure book — **ported here** — fame_book.gd  
  selector: `#fm .bm.bump => animation:fm_swing .7s cubic-bezier(.2,1.5,.4,1)`
- `fm_in` — Guild / adventure book — **ported here** — fame_book.gd  
  selector: `#fm .pg.in .col>*,#fm .pg.in .trk>*,#fm .sl>* => animation:fm_in .5s cubic-bezier(.16,1,.3,1) b`
- `fm_up` — Guild / adventure book — **ported earlier** — fame_book.gd  
  selector: `#fm .pg.in .people>* => animation:fm_up .6s cubic-bezier(.2,1.4,.4,1) both`
- `fm_swap` — Guild / adventure book (in-place morph flashes) — **not ported** — rows re-render without the FLIP morph flash  
  selector: `#fm .swap => animation:fm_swap .5s cubic-bezier(.2,1.5,.4,1) both`
- `fm_new` — Guild / adventure book (in-place morph flashes) — **not ported** — rows re-render without the FLIP morph flash  
  selector: `#fm .new => animation:fm_new .55s cubic-bezier(.2,1.5,.4,1) both`
- `fm_lit` — Guild / adventure book (in-place morph flashes) — **not ported** — rows re-render without the FLIP morph flash  
  selector: `#fm .pp.in.swap => animation:fm_lit .9s cubic-bezier(.2,1,.3,1) both`
- `fm_float` — Guild / adventure book — **ported earlier** — fame_book.gd  
  selector: `#fm .dc.on,#fm .rt.on => animation:fm_float 2.6s ease-in-out infinite`
- `fm_pulse` — Guild / adventure book — **ported earlier** — fame_book.gd  
  selector: `#fm .fbtn.go => animation:fm_pulse 1.5s ease-in-out infinite`
- `fm_hit` — Guild / adventure book — **ported here** — fame_book.gd  
  selector: `#fm .wal .tk.hot => animation:fm_hit .5s cubic-bezier(.2,1.6,.4,1) both`
- `fm_wob` — Guild / adventure book — **ported earlier** — fame_book.gd  
  selector: `#fm .ms button.can => animation:fm_wob 1.3s ease-in-out infinite`
- `fm_mail` — Guild / adventure book — **ported earlier** — fame_book.gd  
  selector: `#fm .letter .qr => animation:fm_mail 1.6s ease-in-out infinite`
- `fm_can` — Guild / adventure book — **ported earlier** — fame_book.gd  
  selector: `#fm .lv.can => animation:fm_can 1.8s ease-in-out infinite`
- `fm_spin` — Guild / adventure book — **ported here** — fame_book.gd  
  selector: `#fm .burst => animation:fm_spin 80s linear infinite`
- `fm_lead` — Guild / adventure book — **ported here** — fame_book.gd  
  selector: `#fm .bgl.lead .slash => animation:fm_lead .95s var(--mv)`
- `fm_lead2` — Guild / adventure book — **ported here** — fame_book.gd  
  selector: `#fm .bgl.lead .edge => animation:fm_lead2 .95s var(--mv)`
- `fm_lead3` — Guild / adventure book — **ported here** — fame_book.gd  
  selector: `#fm .bgl.lead .bigen => animation:fm_lead3 .95s var(--mv)`
- `fmstp` — Level-up popup (#fmup) — **ported earlier** — fame_fx.gd lvCut  
  selector: `#fmup .stp => animation:fmstp .45s .7s cubic-bezier(.3,1.6,.5,1) both`
- `fm_dot` — Top-right button badge dot — **not ported** — the port top bar has no badge dots yet  
  selector: `#topR .tbx i.dot => animation:fm_dot 1.6s ease-in-out infinite`
- `w_dotf` — v2 pages: forge / bag / party / bestiary / settings — **ported here (bag) / ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .dots,#sx2 .dots => animation:w_dotf 6s linear infinite`
- `w_spin` — v2 pages: forge / bag / party / bestiary / settings — **ported here (bag) / ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .burst,#sx2 .burst => animation:w_spin 80s linear infinite`
- `w_stamp` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .stamp,#sx2 .stamp => animation:w_stamp .5s var(--bk) both`
- `w_shake` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .shake,#sx2 .shake => animation:w_shake .4s linear`
- `w_bob` — v2 pages: forge / bag / party / bestiary / settings — **ported here (bag) / ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .spot .big,#sx2 .spot .big => animation:w_bob 2.6s ease-in-out infinite`
- `w_pop` — v2 pages: forge / bag / party / bestiary / settings — **ported here (bag) / ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#sx2 .spot.pop .disc,#fg2 .spot.pop .big,#sx2 .spot.pop .big => animation:w_spin 14s linear inf`
- `w_popd` — v2 pages: forge / bag / party / bestiary / settings — **ported here (bag) / ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .spot.pop .big,#sx2 .spot.pop .big => animation:w_bob 2.6s ease-in-out infinite,w_popd .45`
- `w_flick` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .fire => animation:w_flick 1.8s ease-in-out infinite alternate`
- `w_wbob` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .anvil .wpn,#sx2 .anvil .wpn => animation:w_wbob 2.4s ease-in-out infinite`
- `w_fl` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .flash.go,#sx2 .flash.go => animation:w_fl .4s ease-out`
- `w_resin` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .res.play,#sx2 .res.play => animation:w_resin 1.2s var(--bk) forwards`
- `w_bgf` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .bigen => animation:w_bgf 36s linear infinite`
- `w_skb` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .sk.cur,#sx2 .sk.cur => animation:w_skb 1s ease-in-out infinite`
- `w_dsh` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .ftri line,#sx2 .ftri line => animation:w_dsh 1s linear infinite`
- `w_qa` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .qd .qa,#sx2 .qd .qa => animation:w_qa 3.4s ease-in-out infinite alternate`
- `w_qb` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .qd .qb,#sx2 .qd .qb => animation:w_qb 2.8s ease-in-out infinite alternate`
- `w_qc` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .qd .qc,#sx2 .qd .qc => animation:w_qc 3s ease-in-out infinite alternate`
- `w_qka` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .qd.kick .qa,#sx2 .qd.kick .qa => animation:w_qka .5s cubic-bezier(.2,1.4,.4,1)`
- `w_qkb` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .qd.kick .qb,#sx2 .qd.kick .qb => animation:w_qkb .5s cubic-bezier(.2,1.4,.4,1)`
- `w_ndl` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .cut .cl svg,#sx2 .cut .cl svg => animation:w_ndl .5s cubic-bezier(.2,.7,.4,1) both`
- `w_sprite` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .poster .spr,#sx2 .poster .spr => animation:w_sprite .7s steps(4) infinite`
- `w_flip` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .poster.flip,#sx2 .poster.flip => animation:w_flip .55s var(--bk)`
- `w_sray` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#sx2 .sray => animation:w_sray 5s linear infinite`
- `w_sprite8` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .smob .sp.e8,#sx2 .smob .sp.e8 => animation:w_sprite8 .7s steps(8) infinite`
- `w_bustin` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .bust,#sx2 .bust => animation:w_bustin .55s var(--bk) both`
- `w_nb` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .dnext,#sx2 .dnext => animation:w_nb .8s ease-in-out infinite`
- `w_chin` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: `#fg2 .chs.on button,#sx2 .chs.on button => animation:w_chin .4s var(--bk) both`
- `w_spr8` — v2 pages: forge / bag / party / bestiary / settings — **ported earlier** — ui_forge.gd, ui_bag.gd, options.gd, ui_codex.gd  
  selector: ``
- `dlgBust` — Dialogue (v3) — **ported here** — talk_fx.gd (dialog.gd, ui_choice.gd)  
  selector: `#wrap #dlg .dpor => animation:dlgBust .45s cubic-bezier(.2,1.5,.4,1) both!important`
- `dlgCh` — Dialogue (v3) — **ported here** — talk_fx.gd (dialog.gd, ui_choice.gd)  
  selector: `#wrap #dlg .dch button => animation:dlgCh .4s cubic-bezier(.2,1.5,.4,1) both!important`
- `h2spin` — HUD touch buttons (ULT / attack) — **partial** — ult readiness shown on the crescent arc; touch button shine/stripes not drawn  
  selector: `#wrap #padR .b-atk::before => animation:h2spin 14s linear infinite`
- `h2pulse` — HUD bench QTE — **partial** — face grows + glow ring + timer arc; no striped call-out card  
  selector: `#wrap #bUlt.ready => animation:h2stripe .5s linear infinite,h2pulse 1s ease-in-out infinite!imp`
- `h2stripe` — HUD touch buttons (ULT / attack) — **partial** — ult readiness shown on the crescent arc; touch button shine/stripes not drawn  
  selector: `#wrap #bUlt.ready => animation:h2stripe .5s linear infinite,h2pulse 1s ease-in-out infinite!imp`
- `asmIn` — Title — **partial** — -ASSEMBLE- stamps in as one slab, not letter by letter  
  selector: `#title .asm span => animation:asmIn .7s cubic-bezier(.2,1.5,.4,1) .3s both`
- `h3ulb` — HUD touch buttons (ULT / attack) — **partial** — ult readiness shown on the crescent arc; touch button shine/stripes not drawn  
  selector: `#wrap #bUlt.ready => animation:h3ulb .9s ease-in-out infinite alternate!important`
- `h3sweep` — HUD touch buttons (ULT / attack) — **partial** — ult readiness shown on the crescent arc; touch button shine/stripes not drawn  
  selector: `#wrap #bUlt.ready .usw::after => animation:h3sweep 1.3s ease-in-out infinite`
- `h3str` — HUD bench QTE — **partial** — face grows + glow ring + timer arc; no striped call-out card  
  selector: `#wrap #pcol .ps .qc .qf => animation:h3str .6s linear infinite`
- `h3bob` — HUD bench QTE — **partial** — face grows + glow ring + timer arc; no striped call-out card  
  selector: `#wrap #pcol .ps.qte .qc => animation:h3bob .9s ease-in-out .4s infinite alternate`
- `h3sh` — Dialogue (v3) — **ported here** — talk_fx.gd (dialog.gd, ui_choice.gd)  
  selector: `#wrap #dlg .dcut .s1 => animation:h3sh .5s cubic-bezier(.2,1.6,.4,1) both`
- `h3bal` — Dialogue (v3) — **ported here** — talk_fx.gd (dialog.gd, ui_choice.gd)  
  selector: `#wrap #dlg .dbox => animation:h3bal .45s cubic-bezier(.2,1.6,.4,1) .12s both`
- `h3ch` — Dialogue (v3) — **ported here** — talk_fx.gd (dialog.gd, ui_choice.gd)  
  selector: `#wrap #dlg .dtxt span => animation:h3ch .28s cubic-bezier(.2,1.6,.4,1) both`
- `h3rn` — Dialogue (v3) — **ported here** — talk_fx.gd (dialog.gd, ui_choice.gd)  
  selector: `#wrap #dlg .dname b i => animation:h3rn .5s cubic-bezier(.2,1.6,.4,1) both`
- `h3chIn` — Dialogue (v3) — **ported here** — talk_fx.gd (dialog.gd, ui_choice.gd)  
  selector: `#wrap #dlg .dch button.c3 => animation:h3chIn .45s cubic-bezier(.2,1.6,.4,1) both`
- `nlIn` — Notice feed — **ported earlier** — fame_fx.gd  
  selector: `#nfeed .nl => animation:nlIn .25s steps(3) both`
- `nlOut` — Notice feed — **ported earlier** — fame_fx.gd  
  selector: `#nfeed .nl.out => animation:nlOut .3s steps(4) forwards`
- `cdx_spr` — Codex mob sprites — **ported earlier** — ui_codex.gd  
  selector: ``
- `cl_dots` — Clear screen — **ported earlier** — clear_screen.gd  
  selector: `#lootres.cl2 .c-bg .dots => animation:cl_dots 9s linear infinite`
- `cl_spin` — Clear screen — **ported earlier** — clear_screen.gd  
  selector: `#lootres.cl2 .c-bg .ray => animation:cl_spin 80s linear infinite`
- `cl_breath` — Clear screen — **ported earlier** — clear_screen.gd  
  selector: `#lootres.cl2 .c-bg .slab => animation:cl_breath 8s ease-in-out infinite`
- `lvc_run` — Level cut — **ported earlier** — fame_fx.gd  
  selector: `#lvc .k::after => animation:lvc_run .35s linear infinite`
- `kbblink` — Settings key capture — **ported earlier** — options.gd  
  selector: `#kbd .r button.cap => animation:kbblink .6s steps(2) infinite`
- `stmLow` — HUD fatigue chip — **ported earlier** — hud.gd  
  selector: `#stm.low::before => animation:stmLow 1.1s ease-in-out infinite`
- `stmHit` — HUD fatigue chip — **ported here** — hud.gd  
  selector: `#stm.hit => animation:stmHit .5s cubic-bezier(.2,.8,.3,1)`
- `stmDrop` — HUD fatigue chip — **ported here** — hud.gd  
  selector: `#stm .sg i.drop => animation:stmDrop .6s ease-out`

## WAAPI `.animate()` groups

- txSweep2 menu transition (colour + black band, NOW LOADING) — **ported earlier** (sweep.gd), dots **ported here**
- fame_ui openFx (paper rise, shard / edge / slash / band / GUILD word slide-in, staggered rows), headerFx (title, tabs, tab cursor, tokens, bookmark, ✕) — **ported here** (fame_book.gd)
- fame_ui pageSlide (blank sheets, new sheet SL_IN over the old one, SL_OUT going back), speedFx streaks, .bgl lead, tab cursor springs (tabInd), hero glide between docks (heroSync springs), wal/bm bump — **ported here**
- fame_ui wipe (book switch fan, 1140 ms, five keyframes with their own easings), dropFx — **ported here** (dropFx folded into the header pop)
- fame_ui fmClose (paper drop, band out, header lift-off, hero drift, slash out; page closes after 440 ms) — **ported here**
- fame_ui stampFx (stamp slam, paper jolt, lift-off) and moveEl (reward chips fly to the purse, token fm_hit) — **ported here**; claimFx order differs: the claim applies at once instead of when the chips land
- fame_ui deepShift, morphFlip/outAnim (FLIP row morphs), press/tilt on rows, ghostTo — **not ported** (rows are immediate-mode; no per-row identity across renders)
- sortie.js sxGo (tab wipe), sxLaunch (bands slam in, SORTIE letters, slam shake, stretch-and-clip exit, blink-out), sweep()/peel layered bands, run-in/out — **ported earlier** (dsel.gd, sortie.gd), checked frame by frame
- sortie.js clearFx / leave — **ported earlier** (clear_screen.gd)
- sortie.js lvCut / rankCut / tcPlay title cards, tflash — **ported earlier** (fame_fx.gd, title_card.gd)
- codex.js book fall / pick-up / open / page riffle / stamp / close-toss — **ported earlier** (ui_codex.gd)
- forge2.js goP station wipe, result stamps (rbig), anvil strike, Bran cut-in, gear picker, engrave / fuse / salvage moves — **ported earlier** (ui_forge.gd)
- status.js setChar wipe and cx tab entrances — **not ported here** (ui_char.gd, cva-mem branch)
- effBox flip (forge / bag effect box) — **ported earlier**

## CSS transitions (grouped)

- Hero select `.card` transform .3s --bk / background .15s — **ported here** (title.gd)
- Book tabs transform .35s --bk, colour .25s, small label — **ported here**; .bgl layer positions per tab .75s --mv — **ported here**
- Dialogue choice lean `.c3` .25s, text size .2s — **ported here**
- Bag rows `.sbody .it` .5s --bk, 60 ms apart — **ported here** (was 30 px / 300 ms from the wrong side)
- Settings rows `.st` .5s --bk stagger, key slot blink — **ported earlier**
- Hub cursor plates, info card, art slam — **ported earlier**
- Top-right buttons hover magnet / press — **ported earlier** (instant colour change instead of .15s fades)
- v2 page `.fb` / `.fcur` / `.stabs` cursor transitions in forge — **ported earlier**
- Party page (#pt2 `.pcol` flex .55s) — **not ported**: the top-bar 파티 page is still the "준비 중" placeholder (only the fountain party screen exists)

## Not ported, by design

- Character screen motion (cs*/cx_*, setChar wipe): cva-mem owns ui_char.gd on its branch.
- Dialogue `자동` / `건너뛰기` buttons: features, not motion; absent from the port.
- FLIP morphs inside the books (fm_swap / fm_new / fm_lit, outAnim): need per-row identity the immediate-mode pages do not keep.

## Screenshot pairs

Captured with `?uiclock` in the web build (port) and a time-warped Chromium (prototype), same times after the trigger; see the report for paths.
