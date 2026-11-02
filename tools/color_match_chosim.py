## 초심's sheets come from four deliveries in different colour moods (orange vs pink hair, beige vs silver armour).
## Run after make_skin_chosim.py: python3 tools/color_match_chosim.py <sheet dir> <out dir>. Per row (Lab): warm hues
## (hair, tights, skin) turned to the rows' median hue / chroma, whites and darks to the common cast, tinted metal pulled
## to the common white (skin hues spared). Alpha is untouched, so bounds.gd stays valid.
import numpy as np, sys, json
from PIL import Image
from skimage import color
from scipy import ndimage
D, OUT = sys.argv[1], sys.argv[2]
sh = [np.asarray(Image.open(f'{D}/sheet_{i}.png').convert('RGBA')).astype(np.float32) / 255 for i in range(6)]
def row(r): return sh[r // 7][(r % 7) * 352:(r % 7 + 1) * 352]
rows = [r for r in range(42) if row(r)[..., 3].max() > 0]
def warm_stats(R):
    m = R[..., 3] > 0.5
    lab = color.rgb2lab(R[..., :3])[m]; Cc = np.hypot(lab[:, 1], lab[:, 2]); H = np.degrees(np.arctan2(lab[:, 2], lab[:, 1]))
    w = (Cc > 25) & (H > -30) & (H < 75)
    return np.median(H[w]), np.percentile(Cc[(Cc > 20) & (H > -30) & (H < 75)], 90), np.median(lab[w, 0]), w.sum()
def neutral_stats(R):
    m = R[..., 3] > 0.5
    lab = color.rgb2lab(R[..., :3])[m]; Cc = np.hypot(lab[:, 1], lab[:, 2])
    wh = (Cc < 10) & (lab[:, 0] > 65); dk = lab[:, 0] < 25
    return lab[wh, 1:].mean(0), lab[wh, 0].mean(), lab[dk, 1:].mean(0), wh.sum(), dk.sum()
WS = {r: warm_stats(row(r)) for r in rows}
NS = {r: neutral_stats(row(r)) for r in rows}
tH = float(np.median([WS[r][0] for r in rows])); tC = float(np.median([WS[r][1] for r in rows])); tL = float(np.median([WS[r][2] for r in rows]))
tWab = np.median([NS[r][0] for r in rows], 0); tWL = float(np.median([NS[r][1] for r in rows])); tDab = np.median([NS[r][2] for r in rows], 0)
log = {}
for r in rows:
    R = row(r); a = R[..., 3]
    lab = color.rgb2lab(R[..., :3])
    L, A, B = lab[..., 0], lab[..., 1], lab[..., 2]
    Cc = np.hypot(A, B); H = np.degrees(np.arctan2(B, A))
    h0, c0, l0, _ = WS[r]
    dh = tH - h0; k = float(np.clip(tC / c0, 0.85, 1.3)); dl = (tL - l0) * 0.6
    hw = np.clip((H + 50) / 20, 0, 1) * np.clip((95 - H) / 20, 0, 1)          # warm hues, soft edges
    w = np.clip((Cc - 12) / 13, 0, 1) * hw
    H2 = H + w * dh; C2 = Cc * (1 + w * (k - 1)); L2 = L + w * dl
    A2 = C2 * np.cos(np.radians(H2)); B2 = C2 * np.sin(np.radians(H2))
    # neutrals: the whites' and darks' cast toward the common one
    wab, wl, dab, nw, nd = NS[r]
    wn = np.clip((10 - Cc) / 6, 0, 1) * np.clip((L - 55) / 10, 0, 1)
    wd = np.clip((30 - L) / 8, 0, 1) * (1 - w)
    A2 = A2 + wn * (tWab[0] - wab[0]) + wd * (tDab[0] - dab[0]) * 0.7
    B2 = B2 + wn * (tWab[1] - wab[1]) + wd * (tDab[1] - dab[1]) * 0.7
    L2 = L2 + wn * (tWL - wl) * 0.5
    # tinted metal (beige armour in one delivery, lavender boots in another): pull toward the common white, skin hues spared
    skinh = np.clip((H - 20) / 8, 0, 1) * np.clip((75 - H) / 8, 0, 1)
    wm = np.clip((20 - Cc) / 8, 0, 1) * np.clip((L - 48) / 10, 0, 1) * (1 - skinh) * (1 - wn) * 0.65
    A2 = A2 * (1 - wm) + tWab[0] * wm
    B2 = B2 * (1 - wm) + tWab[1] * wm
    rgb2 = np.clip(color.lab2rgb(np.dstack([L2, A2, B2])), 0, 1)
    R[..., :3] = np.where((a > 0)[..., None], rgb2, R[..., :3])
    log[r] = [round(dh, 1), round(k, 2), round(dl, 1)]
for i in range(6):
    Image.fromarray((sh[i] * 255 + 0.5).astype(np.uint8)).save(f'{OUT}/sheet_{i}.png')
print('target hue %.1f C90 %.1f L %.1f' % (tH, tC, tL)); print(log)
