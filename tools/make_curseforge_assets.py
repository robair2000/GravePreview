from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np
import math, os

OUT = r"C:\Users\robai\Documents\Standaardproject\GravePreview"
FONT_BOLD = r"C:\Windows\Fonts\segoeuib.ttf"
FONT_SEMI = r"C:\Windows\Fonts\seguisb.ttf"
FONT_REG = r"C:\Windows\Fonts\segoeui.ttf"

GOLD = (224, 184, 76)
GOLD_LIGHT = (243, 210, 117)
RED = (255, 89, 64)
TEXT = (232, 236, 240)
MUTED = (150, 160, 170)
DARK = (9, 12, 16)


def font(path, size):
    return ImageFont.truetype(path, size)


def tracked_width(draw, text, fnt, tracking):
    return sum(draw.textlength(ch, font=fnt) for ch in text) + tracking * max(0, len(text) - 1)


def draw_tracked(draw, xy, text, fnt, fill, tracking=0):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=fnt, fill=fill)
        x += draw.textlength(ch, font=fnt) + tracking
    return x


def vertical_gradient(size, top, bottom):
    w, h = size
    arr = np.zeros((h, w, 3), dtype=np.uint8)
    for c in range(3):
        arr[:, :, c] = np.linspace(top[c], bottom[c], h, dtype=np.uint8)[:, None]
    return Image.fromarray(arr, "RGB")


def radial_glow(size, center, radius, color, strength):
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w]
    dist = np.sqrt((xx - center[0]) ** 2 + (yy - center[1]) ** 2) / radius
    alpha = np.clip(1 - dist, 0, 1) ** 2 * strength
    overlay = Image.new("RGBA", size, color + (0,))
    overlay.putalpha(Image.fromarray((alpha * 255).astype(np.uint8), "L"))
    return overlay


def rounded(draw, box, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def wrap(draw, text, fnt, max_width):
    words = text.split()
    lines, line = [], ""
    for word in words:
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=fnt) <= max_width:
            line = trial
        else:
            if line:
                lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def draw_gravestone(draw, cx, cy, w, h, fill, outline=None, width=1):
    x0, y0 = cx - w / 2, cy - h / 2
    draw.rounded_rectangle((x0, y0, x0 + w, y0 + h), radius=w * 0.42, fill=fill, outline=outline, width=width)
    # base
    draw.rectangle((x0 - w * 0.12, y0 + h * 0.86, x0 + w * 1.12, y0 + h), fill=fill)
    # cross
    cw = max(2, int(w * 0.10))
    draw.rectangle((cx - cw / 2, y0 + h * 0.20, cx + cw / 2, y0 + h * 0.55), fill=DARK)
    draw.rectangle((cx - w * 0.22, y0 + h * 0.31, cx + w * 0.22, y0 + h * 0.31 + cw), fill=DARK)


def draw_pin(draw, cx, cy, scale, ring=True):
    # outer glow
    if ring:
        for i, alpha in [(1.9, 22), (1.55, 32), (1.25, 45)]:
            r = 70 * scale * i
            draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(224, 184, 76, alpha), width=int(4 * scale))
    # teardrop
    r = 54 * scale
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=GOLD)
    draw.polygon([(cx - r * 0.64, cy + r * 0.72), (cx + r * 0.64, cy + r * 0.72), (cx, cy + r * 1.85)], fill=GOLD)
    # inner
    ir = r * 0.72
    draw.ellipse((cx - ir, cy - ir, cx + ir, cy + ir), fill=(17, 22, 27))
    draw_gravestone(draw, cx, cy + ir * 0.06, ir * 0.78, ir * 1.0, (235, 240, 236))


def make_logo():
    S = 2048
    base = vertical_gradient((S, S), (17, 24, 32), (4, 6, 9)).convert("RGBA")
    base = Image.alpha_composite(base, radial_glow((S, S), (S / 2, S * 0.40), S * 0.72, GOLD, 0.16))

    overlay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)

    # arc contour lines
    for i in range(7):
        y = 1180 + i * 34
        d.arc((120 - i * 20, y - 240 - i * 10, S - 120 + i * 20, y + 240 + i * 10), 200, 340, fill=(224, 184, 76, 18), width=2)

    # outer frame
    rounded(d, (70, 70, S - 70, S - 70), 90, outline=GOLD + (220,), width=6)
    rounded(d, (96, 96, S - 96, S - 96), 72, outline=GOLD + (60,), width=2)

    # pin emblem
    draw_pin(d, S / 2, 760, 3.2, ring=True)

    # title
    title_font = font(FONT_BOLD, 196)
    tracking = 8
    title = "GRAVEPREVIEW"
    tw = tracked_width(d, title, title_font, tracking)
    draw_tracked(d, ((S - tw) / 2, 1210), title, title_font, TEXT, tracking)

    # subtitle
    sub_font = font(FONT_SEMI, 58)
    sub = "WORLD OF WARCRAFT ADDON"
    sw = d.textlength(sub, font=sub_font)
    d.text(((S - sw) / 2, 1460), sub, font=sub_font, fill=GOLD_LIGHT)

    # divider
    d.line((S / 2 - 330, 1580, S / 2 + 330, 1580), fill=GOLD + (120,), width=3)

    # tagline
    tag_font = font(FONT_REG, 52)
    tag = "Likely respawn graveyard on the world map"
    tw = d.textlength(tag, font=tag_font)
    d.text(((S - tw) / 2, 1630), tag, font=tag_font, fill=MUTED)

    # bottom strip
    strip_font = font(FONT_SEMI, 38)
    strip = "MAP   •   OPEN WORLD   •   OPENMAP"
    sw = tracked_width(d, strip, strip_font, 4)
    draw_tracked(d, ((S - sw) / 2, 1830), strip, strip_font, GOLD, 4)

    out = Image.alpha_composite(base, overlay).convert("RGB")
    out = out.resize((512, 512), Image.LANCZOS)
    out.save(os.path.join(OUT, "CurseForge-logo.png"), "PNG", optimize=True)
    print("logo done")


def map_background(w, h):
    img = vertical_gradient((w, h), (25, 42, 33), (13, 23, 19)).convert("RGBA")
    d = ImageDraw.Draw(img)

    # water at edges
    d.rectangle((0, 0, w, h), fill=(12, 25, 31, 255))
    # large land mass
    land = [
        (int(w * 0.02), int(h * 0.22)), (int(w * 0.18), int(h * 0.06)), (int(w * 0.43), int(h * 0.10)),
        (int(w * 0.58), int(h * 0.04)), (int(w * 0.79), int(h * 0.12)), (int(w * 0.97), int(h * 0.30)),
        (int(w * 0.95), int(h * 0.72)), (int(w * 0.82), int(h * 0.94)), (int(w * 0.61), int(h * 0.88)),
        (int(w * 0.46), int(h * 0.96)), (int(w * 0.24), int(h * 0.86)), (int(w * 0.08), int(h * 0.70)),
    ]
    d.polygon(land, fill=(37, 56, 42, 255))
    # lighter inner land
    inner = [(int(x * 0.94 + w * 0.03), int(y * 0.90 + h * 0.05)) for x, y in land]
    d.polygon(inner, fill=(47, 70, 51, 255))

    # big terrain patches
    for cx, cy, rx, ry, col in [
        (0.26, 0.26, 0.16, 0.14, (55, 82, 58, 120)),
        (0.63, 0.34, 0.20, 0.16, (61, 88, 62, 110)),
        (0.48, 0.70, 0.22, 0.18, (41, 62, 47, 140)),
        (0.78, 0.72, 0.13, 0.13, (57, 80, 56, 100)),
    ]:
        d.ellipse((int((cx - rx) * w), int((cy - ry) * h), int((cx + rx) * w), int((cy + ry) * h)), fill=col)

    # grid
    for x in range(0, w, 160):
        d.line((x, 0, x, h), fill=(210, 230, 210, 14), width=1)
    for y in range(0, h, 160):
        d.line((0, y, w, y), fill=(210, 230, 210, 14), width=1)

    # contour-ish lines
    for i in range(14):
        y0 = int(h * (0.18 + i * 0.045))
        pts = []
        for x in range(0, w + 1, 40):
            yy = y0 + int(math.sin(x / 210 + i * 0.8) * 18 + math.sin(x / 93 + i) * 8)
            pts.append((x, yy))
        d.line(pts, fill=(194, 220, 190, 22), width=2, joint="curve")

    # river
    river = []
    for x in range(0, w + 1, 30):
        yy = int(h * 0.58 + math.sin(x / 260) * 70 + math.sin(x / 90) * 18)
        river.append((x, yy))
    d.line(river, fill=(45, 100, 120, 210), width=18, joint="curve")
    d.line(river, fill=(75, 140, 158, 140), width=7, joint="curve")

    # roads
    road = [(int(w * 0.10), int(h * 0.56)), (int(w * 0.28), int(h * 0.47)), (int(w * 0.45), int(h * 0.52)),
            (int(w * 0.62), int(h * 0.44)), (int(w * 0.78), int(h * 0.50)), (int(w * 0.92), int(h * 0.42))]
    d.line(road, fill=(190, 160, 100, 170), width=9, joint="curve")
    d.line(road, fill=(220, 190, 125, 90), width=3, joint="curve")

    # vignette
    vig = radial_glow((w, h), (w / 2, h / 2), max(w, h) * 0.68, (0, 0, 0), 1.0)
    # invert-ish: use dark edges via a manual mask
    yy, xx = np.mgrid[0:h, 0:w]
    dist = np.sqrt((xx - w / 2) ** 2 + (yy - h / 2) ** 2) / (max(w, h) * 0.62)
    alpha = np.clip(dist - 0.55, 0, 1) ** 1.5 * 150
    shade = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shade.putalpha(Image.fromarray(alpha.astype(np.uint8), "L"))
    img = Image.alpha_composite(img, shade)

    return img


def make_screenshot():
    W, H = 2560, 1440
    scale = 2
    base = Image.new("RGBA", (W, H), (8, 11, 15, 255))
    d = ImageDraw.Draw(base)

    # header
    d.text((70, 36), "GRAVEPREVIEW", font=font(FONT_BOLD, 58), fill=GOLD_LIGHT)
    d.text((72, 104), "Likely respawn graveyard on the world map", font=font(FONT_REG, 30), fill=MUTED)
    # badge
    badge_font = font(FONT_SEMI, 26)
    badge = "OPENMAP STITCHED MAP  •  PREVIEW"
    bw = d.textlength(badge, font=badge_font)
    rounded(d, (W - 70 - bw - 48, 44, W - 70, 110), 12, fill=(20, 26, 24, 255), outline=GOLD + (150,), width=2)
    d.text((W - 70 - bw - 24, 59), badge, font=badge_font, fill=GOLD)

    # map frame
    mx0, my0, mx1, my1 = 54, 164, W - 54, H - 54
    rounded(d, (mx0, my0, mx1, my1), 26, fill=(6, 9, 12, 255), outline=GOLD + (90,), width=3)
    map_img = map_background(mx1 - mx0 - 8, my1 - my0 - 8)
    base.alpha_composite(map_img, (mx0 + 4, my0 + 4))

    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)

    # zone labels
    od.text((170, 250), "HILLSBRAD FOOTHILLS", font=font(FONT_SEMI, 30), fill=(220, 235, 218, 120))
    od.text((190, 300), "Tarren Mill", font=font(FONT_SEMI, 24), fill=(210, 225, 208, 85))
    od.text((1850, 240), "ALTERAC MOUNTAINS", font=font(FONT_SEMI, 26), fill=(220, 235, 218, 90))
    od.text((1880, 900), "ARATHI HIGHLANDS", font=font(FONT_SEMI, 24), fill=(220, 235, 218, 80))
    od.text((340, 990), "SILVERPINE FOREST", font=font(FONT_SEMI, 24), fill=(220, 235, 218, 70))

    # other graveyards
    for gx, gy, name in [(400, 430, "Southshore"), (2060, 980, "Arathi"), (600, 1080, "Sepulcher"), (1540, 1070, "Hinterlands")]:
        od.ellipse((gx - 17, gy - 17, gx + 17, gy + 17), fill=(12, 18, 14, 230), outline=(130, 145, 125, 220), width=3)
        draw_gravestone(od, gx, gy, 13, 18, (190, 200, 185, 230))
        if name == "Southshore":
            od.text((gx + 28, gy - 14), name, font=font(FONT_REG, 22), fill=(205, 215, 198, 130))

    # player marker
    px, py = 1210, 835
    od.ellipse((px - 26, py - 26, px + 26, py + 26), fill=(20, 40, 70, 230), outline=(100, 180, 255, 240), width=3)
    od.polygon([(px, py - 38), (px - 15, py + 8), (px + 15, py + 8)], fill=(120, 200, 255, 245))
    od.text((px - 24, py + 40), "YOU", font=font(FONT_SEMI, 22), fill=(120, 200, 255, 230))

    # target pin
    tx, ty = 1640, 610
    draw_pin(od, tx, ty, 1.55, ring=True)

    # dotted line from player to pin
    for t in np.linspace(0, 1, 34):
        lx = int(px + (tx - px) * t)
        ly = int(py + (ty - py) * t + math.sin(t * math.pi) * 30)
        r = 3 if int(t * 34) % 2 == 0 else 2
        od.ellipse((lx - r, ly - r, lx + r, ly + r), fill=GOLD + (150,))
    od.text(((px + tx) / 2 - 50, (py + ty) / 2 + 42), "~120 yd", font=font(FONT_SEMI, 22), fill=GOLD + (200,))

    # tooltip card
    card_x, card_y, card_w, card_h = 1810, 250, 620, 300
    # shadow
    od.rounded_rectangle((card_x + 10, card_y + 12, card_x + card_w + 10, card_y + card_h + 12), radius=18, fill=(0, 0, 0, 120))
    rounded(od, (card_x, card_y, card_x + card_w, card_y + card_h), 18, fill=(8, 11, 15, 246), outline=GOLD + (200,), width=3)
    # mini pin in tooltip
    draw_pin(od, card_x + 60, card_y + 74, 0.55, ring=False)
    od.text((card_x + 110, card_y + 34), "Likely graveyard", font=font(FONT_BOLD, 30), fill=GOLD_LIGHT)
    od.text((card_x + 110, card_y + 78), "Tarren Mill", font=font(FONT_BOLD, 46), fill=TEXT)
    od.text((card_x + 110, card_y + 140), "~120 yd from you", font=font(FONT_REG, 28), fill=MUTED)
    wrap_font = font(FONT_REG, 22)
    lines = wrap(od, "Closest eligible graveyard. Zone rules can still pick a different one.", wrap_font, card_w - 80)
    yy = card_y + 192
    for line in lines:
        od.text((card_x + 40, yy), line, font=wrap_font, fill=(170, 178, 186, 235))
        yy += 30

    # bottom legend
    ly = H - 104
    od.ellipse((78, ly - 12, 102, ly + 12), fill=(12, 18, 14, 230), outline=GOLD + (220,), width=2)
    draw_gravestone(od, 90, ly, 10, 14, (235, 240, 236))
    od.text((118, ly - 16), "Corpse icon = likely respawn graveyard", font=font(FONT_SEMI, 24), fill=(205, 215, 205, 230))
    od.text((760, ly - 16), "Open world only  •  BG/dungeon coordinates are hidden from addons", font=font(FONT_REG, 22), fill=(150, 160, 168, 210))
    od.text((W - 300, ly - 16), "GravePreview", font=font(FONT_BOLD, 26), fill=GOLD + (230,))

    base = Image.alpha_composite(base, overlay).convert("RGB")
    base = base.resize((1280, 720), Image.LANCZOS)
    base.save(os.path.join(OUT, "CurseForge-screenshot.png"), "PNG", optimize=True)
    print("screenshot done")


if __name__ == "__main__":
    make_logo()
    make_screenshot()
