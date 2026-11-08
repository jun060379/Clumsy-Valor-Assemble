# Sketch only (not in the game): the hall slope painted over two stitched captures, big masses first.
# python3 tools/sketch_hall_hill.py SCRATCH  (needs SCRATCH/hl/a and hl/b captures)
# the hall's slope, big masses first: layers of grass mounds stepping down toward the camera, each nearer layer over
# the one above it; between some layers an exposed earth cut, and a dry-stone wall at the foot. Light from above:
# a mound's top band lit, its body the lawn, its foot a step down where the nearer layer shades it.
from PIL import Image
import numpy as np, math, random, sys
S=sys.argv[1]
A=np.array(Image.open(S+'/hl/a/a30.png').convert('RGB')).astype(int)
B=np.array(Image.open(S+'/hl/b/a30.png').convert('RGB')).astype(int)
full=np.concatenate([A,np.repeat(B[:1],10,0),B],0)
H,W=full.shape[:2]
P=np.array(Image.open('assets/town/palette.png').convert('RGB')).astype(int)
LW=[tuple(P[4,i]) for i in range(8)]; EA=[tuple(P[1,i]) for i in range(8)]; ST=[tuple(P[8,i]) for i in range(8)]
top, bot = 426, 892
img=np.zeros((H,W,3),int); filled=np.zeros((H,W),bool)
r=random.Random(8)
def even(v): return int(round(v/2))*2
def profile(base, n, hmin, hmax, wmin, wmax, seed):
  rr=random.Random(seed); xs=np.arange(W); y=np.full(W, float(base))
  for i in range(n):
    c=rr.uniform(-100,W+100); w=rr.uniform(wmin,wmax); h=rr.uniform(hmin,hmax)
    y-=h*np.clip(1-((xs-c)/w)**2,0,None)**0.6
  return np.array([even(v) for v in y])
def layer(prof, depth_to, cut=None, seed=0):
  # a layer: from its top silhouette down to depth_to (the next layer covers the rest)
  rr=random.Random(seed)
  for x in range(0,W,2):
    t=prof[x]
    for y in range(t, depth_to, 2):
      d=y-t
      c=LW[6] if d<2 else LW[5] if d<10 else LW[4]
      img[y:y+2,x:x+2]=c; filled[y:y+2,x:x+2]=True
    # a few lit blade marks on the top band
    if (x//2*7+seed)%9==0: img[t-2:t,x:x+2]=LW[5]
  if cut:
    y0,h,spans=cut
    for (a,b) in spans:
      for x in range(even(a),even(b),2):
        ease=min(x-a,b-x)/30.0
        hh=even(h*min(1,ease)+rr.uniform(-2,2))
        if hh<=0: continue
        yt=int(y0[x])-hh if hasattr(y0,'__len__') else even(y0+3*math.sin(x*0.05+seed))
        for y in range(yt,yt+hh,2):
          k=y-yt
          c=EA[4] if k<4 else EA[3] if k<hh*0.6 else EA[2]
          img[y:y+2,x:x+2]=c
        # stones and roots in the earth (Kingdom's band)
        if (x//2*11+seed)%23==0:
          sy=yt+even(rr.uniform(4,max(5,hh-6)))
          for dx in range(0,8,2):
            for dy in range(0,6,2):
              if 0<dx+dy<10: img[sy+dy:sy+dy+2,x+dx:x+dx+2]=ST[6] if dy==0 else ST[4]
        # the grass drapes over the cut's top: tongues of 2..10 px
        tg=even(rr.choice([2,2,4,4,6,8,10]))
        img[yt:yt+tg,x:x+2]=LW[4]; img[yt+tg-2:yt+tg,x:x+2]=LW[3]
        # its foot shaded on the grass below
        img[yt+hh:yt+hh+2,x:x+2]=LW[3]
# layers back (top) to front (bottom)
L1=np.full(W,top)
L2=profile(top+150,7,20,46,90,190,3)
L3=profile(top+280,8,18,40,80,170,5)
L4=profile(bot-80,9,10,26,70,140,9)
layer(L1, H, None, 1)
layer(L2, H, None, 2)
layer(L3, H, None, 3)
layer(L4, H, None, 4)
# the exposed earth: on the face of a layer right above the nearer layer's top (that is where the bank is cut)
layer(L1, L1[0], (L2, 36, [(60,330),(560,840)]), 2)
layer(L1, L1[0], (L3, 30, [(180,520)]), 3)
# the shade a nearer layer's top casts on the layer above, just over its silhouette (one step down, 4 px)
for prof in (L2,L3,L4):
  for x in range(0,W,2):
    t=prof[x]
    for y in range(t-6,t,2):
      if img[y,x].tolist()==list(LW[4]): img[y:y+2,x:x+2]=LW[3]
# the dry-stone wall at the foot, behind the lower street
wt=bot-44
for y in range(wt,bot,2):
  row=(y-wt)//10; off=(row*13)%22
  for x in range(0,W,2):
    k=(y-wt)%10; j=(x+off)%22
    c=ST[6] if k<2 else ST[5] if k<8 else ST[3]
    if j<2: c=ST[3]
    if k<2 and j<4: c=ST[5]
    img[y:y+2,x:x+2]=c
for x in range(0,W,2):
  tg=even(random.Random(x).choice([2,4,4,6,8]))
  img[wt:wt+tg,x:x+2]=LW[4]; img[wt+tg-2:wt+tg,x:x+2]=LW[3]
lum=full.mean(2); wall=(lum<55)&(full[...,0]>=full[...,1])&(full[...,2]<70)
reg=np.zeros((H,W),bool); reg[top:bot]=True
reg&=wall|(np.arange(H)[:,None]<top+44)
out=full.copy(); out[reg]=img[reg]
o=Image.fromarray(out.astype(np.uint8))
c=Image.new('RGB',(1810,H),(20,20,20)); c.paste(Image.fromarray(full.astype(np.uint8)),(0,0)); c.paste(o,(910,0)); c.save(S+'/hill3_cmp.png')
o.crop((0,420,450,900)).resize((900,960),0).save(S+'/hill3_z.png')
