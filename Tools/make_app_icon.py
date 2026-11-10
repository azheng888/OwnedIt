# Draws the OwnedIt app icon (and the alternative concepts B/C) procedurally.
# Usage: python3 Tools/make_app_icon.py <output-dir>   (needs Pillow)
# Shipped icon: A-ink-tag.png -> AppIcon.png, A-dark.png -> AppIcon-Dark.png, A-tinted.png -> AppIcon-Tinted.png
import sys, math
from PIL import Image, ImageDraw, ImageFilter, ImageChops
OUT = sys.argv[1]
N = 2048  # supersampled; downscaled to 1024
def hexc(h, a=255): return ((h>>16)&255, (h>>8)&255, h&255, a)
PAPER, PAPER_HI, INK, INK_HI, CREAM = 0xF5F2EB, 0xFCFBF8, 0x1F1D19, 0x3A3631, 0xFBF8F1

def lin_grad(size, top, bot):
    g = Image.new('RGBA', (1, 256))
    for y in range(256):
        t = y/255; g.putpixel((0,y), tuple(int(top[i]+(bot[i]-top[i])*t) for i in range(4)))
    return g.resize(size, Image.BILINEAR)

def radial_bg(c_center, c_edge):
    small = Image.new('RGBA', (256,256))
    for y in range(256):
        for x in range(256):
            d = min(1, math.hypot(x-128, y-90)/200)
            small.putpixel((x,y), tuple(int(c_center[i]+(c_edge[i]-c_center[i])*d) for i in range(4)))
    return small.resize((N,N), Image.BICUBIC)

def round_mask(mask, r):
    # round convex corners: blur + threshold
    m = mask.filter(ImageFilter.GaussianBlur(r))
    return m.point(lambda v: 255 if v > 128 else 0).filter(ImageFilter.GaussianBlur(1.2))

def rot(pts, ang, cx, cy):
    a = math.radians(ang); c, s = math.cos(a), math.sin(a)
    return [(cx+(x-cx)*c-(y-cy)*s, cy+(x-cx)*s+(y-cy)*c) for x,y in pts]

def price_tag_pts(cx, cy, w, h, ang):
    # pointed end on the left
    l, r, t, b = cx-w/2, cx+w/2, cy-h/2, cy+h/2
    pts = [(l, cy), (l+h*0.5, t), (r, t), (r, b), (l+h*0.5, b)]
    return rot(pts, ang, cx, cy)

def house_tag_pts(cx, cy, w, h, ang):
    l, r, t, b = cx-w/2, cx+w/2, cy-h/2, cy+h/2
    roof = t + w*0.5
    pts = [(cx, t), (r, roof), (r, b), (l, b), (l, roof)]
    return rot(pts, ang, cx, cy)

def shape_mask(pts, rr):
    m = Image.new('L', (N,N), 0); ImageDraw.Draw(m).polygon(pts, fill=255)
    return round_mask(m, rr)

def punch(mask, center, rad):
    hole = Image.new('L', (N,N), 0)
    ImageDraw.Draw(hole).ellipse([center[0]-rad, center[1]-rad, center[0]+rad, center[1]+rad], fill=255)
    hole = hole.filter(ImageFilter.GaussianBlur(1.2))
    return ImageChops.subtract(mask, hole), hole

def composite_object(bg, mask, top, bot, shadow_strength=0.35, highlight=0.22, rim_dark=False):
    # drop shadow (soft + contact)
    for blur, off, alpha in ((70, 60, shadow_strength), (18, 14, shadow_strength*0.8)):
        sh = mask.filter(ImageFilter.GaussianBlur(blur))
        sh = ImageChops.offset(sh, 0, off).point(lambda v: int(v*alpha))
        bg = Image.composite(Image.new('RGBA', (N,N), (20,16,10,255)), bg, sh)
    # body fill with vertical gradient across its bbox
    x0,y0,x1,y1 = mask.getbbox()
    body = Image.new('RGBA', (N,N), (0,0,0,0))
    body.paste(lin_grad((x1-x0, y1-y0), top, bot), (x0,y0))
    bg = Image.composite(body, bg, mask)
    # top inner highlight (bevel): mask minus shifted mask
    inner = ImageChops.subtract(mask, ImageChops.offset(mask, 0, 10)).filter(ImageFilter.GaussianBlur(5))
    bg = Image.composite(Image.new('RGBA',(N,N),(255,255,255,255)), bg, inner.point(lambda v:int(v*highlight)))
    # bottom inner shade
    lower = ImageChops.subtract(mask, ImageChops.offset(mask, 0, -12)).filter(ImageFilter.GaussianBlur(6))
    bg = Image.composite(Image.new('RGBA',(N,N),(0,0,0,255)), bg, lower.point(lambda v:int(v*(0.35 if not rim_dark else 0.18))))
    return bg

def hole_inner_shadow(bg, hole, center, rad):
    # shadow cast inside the hole by the top edge
    ring = ImageChops.subtract(hole, ImageChops.offset(hole, 0, 14)).filter(ImageFilter.GaussianBlur(8))
    return Image.composite(Image.new('RGBA',(N,N),(0,0,0,255)), bg, ring.point(lambda v:int(v*0.35)))

def string(bg, pts, color, width):
    lay = Image.new('L', (N,N), 0); d = ImageDraw.Draw(lay)
    # smooth quadratic bezier through control points
    p0, p1, p2 = pts
    curve = [((1-t)**2*p0[0]+2*(1-t)*t*p1[0]+t*t*p2[0], (1-t)**2*p0[1]+2*(1-t)*t*p1[1]+t*t*p2[1]) for t in [i/200 for i in range(201)]]
    d.line(curve, fill=255, width=width, joint='curve')
    for p in (curve[0], curve[-1]): d.ellipse([p[0]-width/2,p[1]-width/2,p[0]+width/2,p[1]+width/2], fill=255)
    lay = lay.filter(ImageFilter.GaussianBlur(1.5))
    sh = ImageChops.offset(lay, 0, 16).filter(ImageFilter.GaussianBlur(12)).point(lambda v:int(v*0.3))
    bg = Image.composite(Image.new('RGBA',(N,N),(0,0,0,255)), bg, sh)
    return Image.composite(Image.new('RGBA',(N,N),color), bg, lay)

def check(bg, pts, color, width):
    lay = Image.new('L', (N,N), 0); d = ImageDraw.Draw(lay)
    d.line(pts, fill=255, width=width, joint='curve')
    for p in (pts[0], pts[-1]): d.ellipse([p[0]-width/2,p[1]-width/2,p[0]+width/2,p[1]+width/2], fill=255)
    lay = lay.filter(ImageFilter.GaussianBlur(1.5))
    # debossed: dark fill + light lower edge
    edge = ImageChops.subtract(ImageChops.offset(lay,0,6), lay).filter(ImageFilter.GaussianBlur(3))
    bg = Image.composite(Image.new('RGBA',(N,N),(255,255,255,255)), bg, edge.point(lambda v:int(v*0.5)))
    return Image.composite(Image.new('RGBA',(N,N),color), bg, lay)

def save(img, name):
    img.convert('RGB').resize((1024,1024), Image.LANCZOS).save(f'{OUT}/{name}.png')

C = N/2
# A — ink tag on paper
bg = radial_bg(hexc(PAPER_HI), hexc(0xE9E3D6))
pts = price_tag_pts(C+40, C+60, 1240, 720, -22)
m = shape_mask(pts, 46)
hc = rot([(C+40-620+300, C+60)], -22, C+40, C+60)[0]
m, hole = punch(m, hc, 78)
bg = composite_object(bg, m, hexc(INK_HI), hexc(0x14120F), 0.32, 0.28)
bg = hole_inner_shadow(bg, hole, hc, 78)
bg = string(bg, [(hc[0], hc[1]), (hc[0]-260, hc[1]-560), (hc[0]+120, 250)], hexc(0xB9AE98), 30)
save(bg, 'A-ink-tag')

# B — cream tag with check, on ink
bg = radial_bg(hexc(0x3A3631), hexc(0x141210))
pts = price_tag_pts(C+40, C+40, 1260, 740, -22)
m = shape_mask(pts, 46)
hc = rot([(C+40-630+300, C+40)], -22, C+40, C+40)[0]
m, hole = punch(m, hc, 78)
bg = composite_object(bg, m, hexc(0xFFFDF8), hexc(0xE7E0D0), 0.6, 0.6, rim_dark=True)
bg = hole_inner_shadow(bg, hole, hc, 78)
ck = rot([(C+40-50, C+40+20), (C+40+90, C+40+150), (C+40+340, C+40-150)], -22, C+40, C+40)
bg = check(bg, ck, hexc(INK), 96)
bg = string(bg, [(hc[0], hc[1]), (hc[0]-280, hc[1]-520), (hc[0]+80, 230)], hexc(0xC9BFA9), 30)
save(bg, 'B-check-tag')

# C — house-shaped key tag on ink
bg = radial_bg(hexc(0x3A3631), hexc(0x141210))
pts = house_tag_pts(C, C+130, 980, 1180, -10)
m = shape_mask(pts, 60)
hc = rot([(C, C+130-590+300)], -10, C, C+130)[0]
m, hole = punch(m, hc, 84)
bg = composite_object(bg, m, hexc(0xFFFDF8), hexc(0xE5DECD), 0.6, 0.6, rim_dark=True)
bg = hole_inner_shadow(bg, hole, hc, 84)
bg = string(bg, [(hc[0], hc[1]), (hc[0]+300, hc[1]-420), (hc[0]-40, 120)], hexc(0xC9BFA9), 32)
save(bg, 'C-house-tag')
print('done')

# A-dark — same tag composition, cream tag on dark (for iOS dark icon); tinted = grayscale of it
bg = radial_bg(hexc(0x2A2824), hexc(0x0E0D0B))
pts = price_tag_pts(C+40, C+60, 1240, 720, -22)
m = shape_mask(pts, 46)
hc = rot([(C+40-620+300, C+60)], -22, C+40, C+60)[0]
m, hole = punch(m, hc, 78)
bg = composite_object(bg, m, hexc(0xF2EFE8), hexc(0xD9D2C2), 0.6, 0.6, rim_dark=True)
bg = hole_inner_shadow(bg, hole, hc, 78)
bg = string(bg, [(hc[0], hc[1]), (hc[0]-260, hc[1]-560), (hc[0]+120, 250)], hexc(0x8F8674), 30)
save(bg, 'A-dark')
bg.convert('L').convert('RGB').resize((1024,1024), Image.LANCZOS).save(f'{OUT}/A-tinted.png')
