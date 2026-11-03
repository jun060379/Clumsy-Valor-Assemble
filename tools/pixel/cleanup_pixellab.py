# Clean a PixelLab frame: hard alpha, lone-pixel cleanup, contrast remap, face colour merge, hand-listed strand bridges (BR, specific to estelle east), 1px outline.
# usage: python3 cleanup_pixellab.py <dir containing pl_east.png>  (writes estelle_east_clean3.png + compare images)
# NOTE: the face box / bridge coordinates are for that one image; generalise before using on other frames.
import numpy as np, sys
from PIL import Image
from scipy import ndimage
O=sys.argv[1]
a=np.array(Image.open(O+'/pl_east.png').convert('RGBA')).astype(int)
H,W=a.shape[:2]
K=np.where(a[...,3]>=128,(a[...,0]<<16)|(a[...,1]<<8)|a[...,2],-1)
def nb4(K):
    P=np.pad(K,1,constant_values=-1); return [P[:-2,1:-1],P[2:,1:-1],P[1:-1,:-2],P[1:-1,2:]]
for _ in range(2):
    N=nb4(K); out=K.copy()
    for y in range(H):
        for x in range(W):
            c=K[y,x]; nb=[n[y,x] for n in N]
            if c in nb: continue
            vals,cnt=np.unique(nb,return_counts=True); i=cnt.argmax()
            if cnt[i]>=3: out[y,x]=vals[i]
    K=out
remap={0x942f55:0x86234f,0x483e5a:0x3a3050,0x8a7ba5:0x9486b4,0x7a566d:0x6b4560,0xed6d8b:0xe8607f}
for s,d in remap.items(): K[K==s]=d
HP,HW,Hp,SK,KK,DD,WH=0xf1aeb1,0x86234f,0xe8607f,0xf2d3c9,0x1b1020,0x3a3050,0xf0eeef
# --- face: same pixels, similar colours merged (coords of the un-outlined image) ---
x0,x1,y0,y1=79,93,15,37
box=np.zeros_like(K,bool); box[y0:y1,x0:x1]=True
# eye: the dark lash / iris shades become one dark
eye=np.zeros_like(K,bool); eye[22:27,84:91]=True
K[eye&((K==DD)|(K==HW))]=KK
# the mid-pink specks on the face/fringe join their surroundings (skin or hair)
P8=np.pad(K,1,constant_values=-1)
ys,xs=np.nonzero(box&(K==Hp))
newv={}
for y,x in zip(ys,xs):
    nb=P8[y:y+3,x:x+3].ravel(); s=(nb==SK).sum(); h=(nb==HP).sum()
    newv[(y,x)]=SK if s>h else HP
for (y,x),v in newv.items(): K[y,x]=v
# --- hair: join the broken strands by hand (outlined-image coords, -1 here); only empty pixels are painted ---
def line(x0,y0,x1,y1):
    pts=[]; dx=abs(x1-x0); dy=-abs(y1-y0); sx=1 if x0<x1 else -1; sy=1 if y0<y1 else -1; e=dx+dy
    while True:
        pts.append((x0,y0))
        if x0==x1 and y0==y1: return pts
        e2=2*e
        if e2>=dy: e+=dy; x0+=sx
        if e2<=dx: e+=dx; y0+=sy
BR=[(HW,[(12,84),(14,83),(17,82),(19,82)]),                     # the loose wine lock on the left back to its strand
    (HP,[(137,80),(138,82)]),                                    # right edge: the little piece by the shoulder
    (HP,[(145,92),(147,94)]),(HP,[(147,96),(145,101)]),(HP,[(145,104),(147,107)]),(HP,[(147,108),(148,110)])]  # the dotted lock down the right
for col,pts in BR:
    for (xa,ya),(xb,yb) in zip(pts,pts[1:]):
        for x,y in line(xa-1,ya-1,xb-1,yb-1):
            if K[y,x]<0: K[y,x]=col
# outline
Kp=np.pad(K,1,constant_values=-1)
occ=Kp>=0; P=np.pad(occ,1)
ring=(~occ)&(P[:-2,1:-1]|P[2:,1:-1]|P[1:-1,:-2]|P[1:-1,2:])
Kp[ring]=KK
def img(K):
    o=np.zeros(K.shape+(4,),np.uint8); m=K>=0
    o[m,0]=(K[m]>>16)&255; o[m,1]=(K[m]>>8)&255; o[m,2]=K[m]&255; o[m,3]=255
    return Image.fromarray(o)
out=img(Kp); out.save(O+'/estelle_east_clean3.png')
prev=Image.open(O+'/estelle_east_clean.png').convert('RGBA')
bg=(98,120,96,255); S=4; w,h=out.size
cv=Image.new('RGBA',(w*S*2+24,h*S),bg)
cv.alpha_composite(prev.resize((w*S,h*S),Image.NEAREST),(0,0)); cv.alpha_composite(out.resize((w*S,h*S),Image.NEAREST),(w*S+24,0))
cv.convert('RGB').save(O+'/compare3.png')
hb=(60,0,130,60); S=10
hz=Image.new('RGBA',(70*S*2+20,60*S),bg)
hz.alpha_composite(prev.crop(hb).resize((700,600),Image.NEAREST),(0,0)); hz.alpha_composite(out.crop(hb).resize((700,600),Image.NEAREST),(720,0))
hz.convert('RGB').save(O+'/compare3_head.png')
