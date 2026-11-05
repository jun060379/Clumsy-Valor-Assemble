"""Re-draw the town sprites drawn at 1.35x (town.gd BS) at 1.35x on the 1-px grid: premultiplied Lanczos, then each pixel
snapped to the source palette, alpha cut at 128 -> assets/town/hx/. Usage: python3 tools/rebake_town.py"""
import sys
from PIL import Image
import numpy as np
K=1.35
def rebake(src):
    im=Image.open(src).convert('RGBA'); a=np.array(im)
    w,h=im.size; W,H=round(w*K),round(h*K)
    # palette of the source (opaque pixels)
    op=a[a[...,3]>127][:,:3]
    pal=np.unique(op.reshape(-1,3),axis=0).astype(np.float32)
    # premultiplied smooth resample
    pm=a.astype(np.float32); pm[...,:3]*=pm[...,3:4]/255
    big=np.stack([np.array(Image.fromarray(pm[...,c]).resize((W,H),Image.LANCZOS)) for c in range(4)],-1)
    al=np.clip(big[...,3],0,255)
    rgb=big[...,:3]/np.maximum(al[...,None],1)*255
    mask=al>127
    q=rgb[mask]
    # nearest palette colour (in a rough perceptual space)
    wts=np.array([0.3,0.59,0.11])**0.5
    d=(((q[:,None,:]-pal[None])*wts)**2).sum(-1)
    out=np.zeros((H,W,4),np.uint8)
    out[mask,:3]=pal[d.argmin(1)].astype(np.uint8); out[mask,3]=255
    return Image.fromarray(out)


KEYS = ["g_store", "g_tentR", "g_barn", "g_cottage", "g_well", "g_forge", "g_anvil", "g_kiln", "g_hall", "g_hall_win", "q_fountain",
        "f_tree2", "f_tree2_leaf", "f_tree2_trunk", "f_tree3", "f_tree3_leaf", "f_tree3_trunk", "f_bigtree", "f_bigtree_leaf", "f_bigtree_trunk",
        "f_bush1", "f_bush2", "f_bush3"]
if __name__ == "__main__":
    import os
    os.makedirs("assets/town/hx", exist_ok=True)
    for k in KEYS:
        rebake("assets/town/%s.png" % k).save("assets/town/hx/%s.png" % k)
