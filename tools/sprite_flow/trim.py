"""Trim Sprite Flow motions: keep chosen frames, mirror to face right, one global scale, per-motion fixed anchor.
Writes trimmed/<motion>/NN.png (448x352 cells, feet on y=340) and trimmed_preview.mp4 + trimmed_sheet.png.
usage: python3 -I trim.py
"""
import glob, os, subprocess, json
from PIL import Image, ImageDraw, ImageFont, ImageOps

R = lambda a, b: list(range(a, b + 1))
SEL = {  # 1-based frame numbers kept (cut: glitches, z-axis moves, stand-still lead-ins)
    "idle": R(1, 32),
    "run": R(4, 28),
    "start": R(6, 26),
    "runjump": R(7, 24) + R(27, 32),
    "djump": R(7, 23),
    "roll": R(3, 28),
    "crouch": R(1, 20),
    "death": R(5, 32),
    "teeter": R(1, 32),
    "tagout": R(1, 20),
    "shot1": [f for f in R(2, 30) if f != 13],
    "shot2": [f for f in R(5, 30) if f != 15],
    "upshot": R(3, 30),
    "airshots": R(3, 25),
    "plunge": R(2, 30),
    "stop": R(18, 30),
    "turnb": R(3, 16) + R(20, 30),
    "jumpb": R(3, 22) + R(24, 30),
    "hurtb": R(2, 28),
    "shot3b": R(10, 14) + R(16, 30),
    "crouchshotb": R(4, 24) + R(26, 32),
    "qte": R(3, 28),
    "skill": R(4, 30),
    "ult": R(3, 32),
}
ANCHOR = {"runjump": "xc_mid", "djump": "xc_mid", "roll": "xc_bottom", "tagout": "xc_bottom", "death": "xc_bottom",
          "plunge": "xc_bottom", "start": "xc_bottom", "stop": "xc_bottom", "turnb": "xc_bottom", "jumpb": "xc_mid"}
LABEL = {"idle": "대기", "run": "달리기", "start": "출발", "runjump": "달리며 점프", "djump": "더블 점프", "roll": "구르기 대시",
         "crouch": "앉기", "death": "사망", "teeter": "비틀거림", "tagout": "교대 퇴장", "shot1": "사격 1타", "shot2": "사격 2타",
         "upshot": "위로 쏘기", "airshots": "공중 3연사", "plunge": "낙공", "stop": "멈춤", "turnb": "방향 전환",
         "jumpb": "제자리 점프", "hurtb": "피격", "shot3b": "사격 3타", "crouchshotb": "앉아 쏘기", "qte": "QTE 헤드샷",
         "skill": "스킬 · 점착 폭탄", "ult": "궁 · 연쇄 기폭"}
CW, CH, FOOT, CX = 448, 352, 340, 215
TARGET_H = 186  # idle standing height in the cell

def bbox(im):
    return im.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()

idle1 = Image.open("frames/idle/01.png").convert("RGBA")
ib = bbox(idle1)
SCALE = TARGET_H / (ib[3] - ib[1])
os.makedirs("trimmed", exist_ok=True)
meta = {}
for m, keep in SEL.items():
    src = sorted(glob.glob(f"frames/{m}/*.png"))
    ims = [ImageOps.mirror(Image.open(src[k - 1]).convert("RGBA")) for k in keep]
    ims = [im.resize((int(im.width * SCALE), int(im.height * SCALE)), Image.LANCZOS) for im in ims]
    b0 = bbox(ims[0])
    # anchor: in-place motions keep the first frame's offset (feet on FOOT, centre on CX) so recoil reads;
    # travelling motions (the game moves the body) are re-centred every frame
    dx0 = CX - (b0[0] + b0[2]) // 2
    dy0 = FOOT - b0[3]
    os.makedirs(f"trimmed/{m}", exist_ok=True)
    for f in glob.glob(f"trimmed/{m}/*.png"):
        os.remove(f)
    clipped = 0
    for i, im in enumerate(ims):
        b = bbox(im)
        mode = ANCHOR.get(m, "fixed")
        dx, dy = dx0, dy0
        if mode in ("xc_bottom", "xc_mid"):
            dx = CX - (b[0] + b[2]) // 2
        if mode == "xc_bottom":
            dy = FOOT - b[3]
        elif mode == "xc_mid":
            dy = (FOOT - 95) - (b[1] + b[3]) // 2
        cell = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
        cell.paste(im, (dx, dy), im)
        if b[0] + dx < 0 or b[2] + dx > CW or b[1] + dy < 0 or b[3] + dy > CH:
            clipped += 1
        cell.save(f"trimmed/{m}/{i + 1:02d}.png")
    meta[m] = {"frames": len(ims), "clipped": clipped}
json.dump(meta, open("trimmed/meta.json", "w"), indent=1, ensure_ascii=False)
print(json.dumps(meta, ensure_ascii=False))

# preview: every motion in a cell on a backdrop with the foot line, 16 fps
ORDER = ['idle', 'run', 'start', 'stop', 'turnb', 'jumpb', 'runjump', 'shot1', 'shot2', 'shot3b', 'crouch', 'crouchshotb', 'upshot', 'airshots', 'plunge', 'djump', 'hurtb', 'death', 'skill', 'ult', 'qte', 'tagout', 'teeter', 'roll']
font = ImageFont.truetype("noto.ttf", 30)
os.makedirs("tprev", exist_ok=True)
for f in glob.glob("tprev/*.png"):
    os.remove(f)
k = 0
S = 2
for m in ORDER:
    fs = sorted(glob.glob(f"trimmed/{m}/*.png"))
    for _ in range(2 if m in ("idle", "run", "teeter", "roll") else 1):
        for f in fs:
            bg = Image.new("RGBA", (CW * S, CH * S), (150, 180, 205, 255))
            d = ImageDraw.Draw(bg)
            d.rectangle((0, FOOT * S, CW * S, CH * S), fill=(96, 128, 80, 255))
            c = Image.open(f).resize((CW * S, CH * S), Image.NEAREST)
            bg.alpha_composite(c)
            d.text((16, 10), LABEL[m], font=font, fill=(20, 20, 28))
            bg.convert("RGB").save(f"tprev/{k:05d}.png")
            k += 1
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "16", "-i", "tprev/%05d.png", "-c:v", "libx264",
                "-pix_fmt", "yuv420p", "-crf", "22", "trimmed_preview.mp4"], check=True)
print("preview frames", k)
