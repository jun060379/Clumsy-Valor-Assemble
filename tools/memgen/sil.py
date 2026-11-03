"""White silhouettes (alpha masks) of the character-screen art, half size: drawn white for the 3 px outline the prototype gets
from CSS drop-shadow, and black for the offset shadow. python3 tools/memgen/sil.py"""
import os
from PIL import Image
D = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'ui', 'st')
for c in ['estelle', 'aida', 'luce', 'kenin']:
    for k in ['skill', 'rec', 'old_base']:
        im = Image.open(os.path.join(D, '%s_%s.webp' % (c, k))).convert('RGBA')
        a = im.getchannel('A').resize((im.width // 2, im.height // 2), Image.LANCZOS)
        out = Image.new('RGBA', a.size, (255, 255, 255, 0))
        out.putalpha(a)
        out.save(os.path.join(D, '%s_%s_sil.webp' % (c, k)), lossless=True)
