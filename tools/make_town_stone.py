"""Stone paving for the town ground (owner 2026-11-06: "돌길은 옆이랑 앞이랑 이어지게 자연스럽게"), from the map scene's
cobble piece (AI source, kept out of the repo; 1-px grid -> doubled to the town's 2-px grid).
  k_stone.png      the paving tile: cobbles on the top, a row of dressed curb stones along the front edge, then earth
  k_stone_cap.png  the paving's end over the lawn: whole stones thinning out raggedly into the turf, the curb ending
                   on a stone (drawn at each end of a STONE span, mirrored on the right)
Usage: python3 tools/make_town_stone.py COBBLE_PIECE.png"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

cob = np.array(Image.open(sys.argv[1]).convert("RGBA"))
cl = np.array(Image.open("assets/town/wide/k_clear.png").convert("RGBA"))
lawn = np.array(Image.open("assets/town/wide/k_lawn.png").convert("RGBA"))
x2 = lambda a: np.repeat(np.repeat(a, 2, 0), 2, 1)
TOP0, TOP1 = 4, 28                       # the walkable top's rows in the ground tiles
band = x2(cob[12:24, 30:160])[:TOP1 - TOP0]          # cobbles, 260 wide
band = np.concatenate([band, band[:, ::-1]], 1)      # 520, seamless by mirroring
curb = x2(cob[0:8, 30:160])                          # 16 rows, 260 wide (period divides 520)
W = 1040
st = np.tile(cl, (1, 1 + W // cl.shape[1], 1))[:, :W].copy()
t = np.tile(band, (1, W // band.shape[1], 1))
reg = st[TOP0:TOP1]; m = t[..., 3] > 127; reg[m] = t[m]
c = np.tile(curb, (1, W // curb.shape[1], 1))
reg = st[TOP1:TOP1 + 16]; m = c[..., 3] > 127; reg[m] = c[m]
# a dark shadow line under the curb, then the earth face as before
sh = st[TOP1 + 16:TOP1 + 18]; o = sh[..., 3] > 127; sh[o, :3] = (sh[o, :3] * 0.6).astype(np.uint8)
st[:TOP0, :, 3] = 0
Image.fromarray(st).save("assets/town/wide/k_stone.png")

# the end cap: 96 px; left = lawn, right = paving; the edge walks along whole cobbles
CW = 96
cap = lawn[:, :CW].copy()
src = st[:, :CW]
# cobble blobs: the light stone pixels between the dark mortar
top = src[TOP0:TOP1]
lum = top[..., :3].astype(int).sum(-1)
stone = (lum > np.percentile(lum[top[..., 3] > 127], 35)) & (top[..., 3] > 127)
lab, n = ndi.label(stone)
rng = np.random.default_rng(11)
keep = np.zeros(n + 1, bool)
for i in range(1, n + 1):
    ys, xs = np.nonzero(lab == i)
    cx = xs.mean() + rng.normal(0, 7)
    keep[i] = cx > CW * 0.42                      # stones nearer the paving stay, the outer ones are gone
mask = keep[lab]
mask = ndi.binary_dilation(mask, iterations=1) & (top[..., 3] > 127)   # each kept stone with its mortar ring
mask[:, int(CW * 0.78):] = True
cap[TOP0:TOP1][mask] = top[mask]
# the curb: whole from the first curb joint past the middle, nothing before it
cx0 = int(CW * 0.5) // 2 * 2
cap[TOP1:TOP1 + 18, cx0:] = src[TOP1:TOP1 + 18, cx0:]
cap[TOP1:TOP1 + 18, cx0:cx0 + 2, :3] = (src[TOP1:TOP1 + 18, cx0:cx0 + 2, :3] * 0.55).astype(np.uint8)   # the curb's end face
Image.fromarray(cap).save("assets/town/k_stone_cap.png")
print("k_stone", st.shape, "cap", cap.shape)

import split_wide                                        # the game reads them in 2400-px pieces (tools/split_wide.py)
for _k in ("k_lawn", "k_clear", "k_stone"): split_wide.split(_k)
