# Illustration -> real pixel-size reference for PixelLab / Sprite Flow.
# usage: python3 pixelize.py <in.png (transparent bg)> <out.png> <target height px> <colours>
# box-downscale over opaque pixels, k-means palette in Lab, lone-pixel cleanup, wisp removal, 1px darkest outline, centred on 256x256.
import numpy as np, sys
from PIL import Image
from scipy import ndimage
from sklearn.cluster import KMeans
src,out,TH,NC=sys.argv[1],sys.argv[2],int(sys.argv[3]),int(sys.argv[4])
im=Image.open(src).convert('RGBA'); im=im.crop(im.getbbox())
s=TH/im.height; w,h=max(1,round(im.width*s)),TH
# downscale: colour by area average over opaque pixels only, alpha by coverage
big=np.array(im).astype(float); a=big[...,3:]/255.0
pm=Image.fromarray(np.uint8(np.clip(big[...,:3]*a,0,255))).resize((w,h),Image.BOX)
am=im.getchannel('A').resize((w,h),Image.BOX)
A=np.array(am).astype(float)/255; C=np.array(pm).astype(float)/np.maximum(A[...,None],1e-3)
op=A>0.6
# thin wisps (1px hairs sticking out) are dropped so the outline doesn't turn them into scribbles
for _ in range(2):
    Pp=np.pad(op,1); n=sum(Pp[1+dy:op.shape[0]+1+dy,1+dx:op.shape[1]+1+dx].astype(int) for dy in (-1,0,1) for dx in (-1,0,1) if dy or dx)
    op=op&(n>=3)
# palette: k-means in a perceptual-ish space
from skimage.color import rgb2lab, lab2rgb
lab=rgb2lab(np.clip(C/255,0,1))
km=KMeans(NC,n_init=4,random_state=0).fit(lab[op])
pal=np.clip(lab2rgb(km.cluster_centers_[None])[0]*255,0,255).astype(int)
idx=np.full(op.shape,-1); idx[op]=km.labels_
# lone pixels -> neighbour majority
for _ in range(2):
    P=np.pad(idx,1,constant_values=-1); N=[P[:-2,1:-1],P[2:,1:-1],P[1:-1,:-2],P[1:-1,2:]]
    o=idx.copy()
    for y,x in zip(*np.nonzero(op)):
        nb=[n[y,x] for n in N]
        if idx[y,x] in nb: continue
        v,c=np.unique(nb,return_counts=True); i=c.argmax()
        if c[i]>=3 and v[i]>=0: o[y,x]=v[i]
    idx=o
# outline with the darkest palette colour
dark=int(np.argmin(pal.sum(1)))
I=np.pad(idx,1,constant_values=-1); occ=I>=0; Pp=np.pad(occ,1)
ring=(~occ)&(Pp[:-2,1:-1]|Pp[2:,1:-1]|Pp[1:-1,:-2]|Pp[1:-1,2:]); I[ring]=dark
res=np.zeros(I.shape+(4,),np.uint8); m=I>=0; res[m,:3]=pal[I[m]]; res[m,3]=255
r=Image.fromarray(res); W=256
c=Image.new('RGBA',(W,W),(0,0,0,0)); c.paste(r,((W-r.width)//2,W-4-r.height)); c.save(out)
print(r.size, NC)
