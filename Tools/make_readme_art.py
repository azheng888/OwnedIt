# Builds the README hero banners and framed screenshots in docs/images.
# Usage: python3 -E Tools/make_readme_art.py <raw-simulator-screenshots-dir> OwnedIt/Assets.xcassets/AppIcon.appiconset docs/images
# Raw screenshots: Debug build on an iPhone 17 Pro simulator, launched with
#   -seedSampleData YES -hasSeenOnboarding YES -initialTab <items|summary|rooms|maintenance>
# and `xcrun simctl status_bar <sim> override --time 9:41 ...`; files named light-<tab>.png / dark-<tab>.png / light-onboarding.png.
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
SHOTS, ICON_DIR, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
FONT = '/System/Library/Fonts/SFNS.ttf'
def font(size, weight):
    f = ImageFont.truetype(FONT, size); f.set_variation_by_name(weight); return f
def hexc(h): return ((h>>16)&255, (h>>8)&255, h&255, 255)

def rounded(im, r):
    m = Image.new('L', im.size, 0); ImageDraw.Draw(m).rounded_rectangle([0,0,im.width-1,im.height-1], r, fill=255)
    out = im.convert('RGBA'); out.putalpha(m); return out

def phone(shot, width, dark_bezel=True):
    """Screenshot in a simple device frame (bezel + rounded screen)."""
    s = Image.open(f'{SHOTS}/{shot}.png').convert('RGBA')
    sw = width - int(width*0.05)
    s = s.resize((sw, int(s.height*sw/s.width)), Image.LANCZOS)
    b = (width-sw)//2
    W, H = width, s.height + 2*b
    r_out = int(width*0.16); r_in = r_out - b
    frame = Image.new('RGBA', (W, H), (0,0,0,0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([0,0,W-1,H-1], r_out, fill=(28,27,25,255))
    d.rounded_rectangle([2,2,W-3,H-3], r_out-2, outline=(70,67,62,255), width=max(2, width//300))
    frame.alpha_composite(rounded(s, r_in), (b, b))
    return frame

def drop(canvas, obj, xy, blur, off, alpha):
    a = obj.split()[3]
    sh = Image.new('L', canvas.size, 0); sh.paste(a, (xy[0], xy[1]+off))  # no wrap-around
    sh = sh.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v*alpha))
    canvas.paste(Image.new('RGBA', canvas.size, (20,16,10,255)), (0,0), sh)
    canvas.alpha_composite(obj, xy)

def hero(mode):
    dark = mode == 'dark'
    W, H = 2560, 1280
    bg, ink, sub = (hexc(0x151412), hexc(0xF2EFE8), hexc(0xA39D8C)) if dark else (hexc(0xF5F2EB), hexc(0x1F1D19), hexc(0x77715F))
    c = Image.new('RGBA', (W, H), bg)
    # soft vignette glow
    glow = Image.new('L', (W, H), 0); ImageDraw.Draw(glow).ellipse([1300, -300, 2900, 1500], fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(260)).point(lambda v: int(v*(0.10 if dark else 0.55)))
    c.paste(Image.new('RGBA', (W,H), (255,255,255,255) if not dark else (90,84,74,255)), (0,0), glow)
    # icon
    icon = Image.open(f"{ICON_DIR}/{'AppIcon-Dark' if dark else 'AppIcon'}.png").convert('RGBA').resize((220,220), Image.LANCZOS)
    icon = rounded(icon, 50)
    drop(c, icon, (180, 330), 30, 18, 0.35 if not dark else 0.6)
    d = ImageDraw.Draw(c)
    d.text((176, 600), 'OwnedIt', font=font(150, 'Bold'), fill=ink)
    d.text((184, 790), 'Everything you own, accounted for.', font=font(56, 'Medium'), fill=ink)
    d.text((184, 870), 'A calm, private home inventory for iPhone —', font=font(44, 'Regular'), fill=sub)
    d.text((184, 926), 'photos, receipts, warranties and value, synced with iCloud.', font=font(44, 'Regular'), fill=sub)
    # phones, overlapping fan
    p = 'dark' if dark else 'light'
    back_l = phone(f'{p}-summary', 480)
    front  = phone(f'{p}-items', 560)
    back_r = phone(f'{p}-rooms', 480)
    y0 = 150
    drop(c, back_l, (1380, y0+130), 50, 40, 0.30)
    drop(c, back_r, (2050, y0+130), 50, 40, 0.30)
    drop(c, front, (1690, y0), 60, 50, 0.40)
    c.convert('RGB').save(f'{OUT}/hero-{mode}.png', optimize=True)

def gallery():
    for name in ['light-onboarding','light-items','light-summary','light-rooms','light-maintenance','dark-items','dark-summary','dark-rooms']:
        p = phone(name, 600)
        pad = 40
        c = Image.new('RGBA', (p.width+2*pad, p.height+2*pad), (0,0,0,0))
        drop(c, p, (pad, pad-10), 18, 12, 0.25)
        c.save(f'{OUT}/{name}.png', optimize=True)

hero('light'); hero('dark'); gallery(); print('ok')
