#!/usr/bin/env python3
"""Render the SignalFinder app icon to PNG mipmaps using PIL only.

Draws at supersampled resolution then downscales for crisp edges.
Mirrors assets/icon/netboost_app_icon.svg.
"""
import math
from PIL import Image, ImageDraw, ImageFilter

S = 1024
SS = 2
N = S * SS

def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))

def grad_fill(p0, c0, p1, c1, size=N, lowres=512):
    """Linear gradient as full-size RGBA image (rendered small, upscaled)."""
    g = Image.new("RGB", (lowres, lowres))
    px = g.load()
    dx, dy = (p1[0] - p0[0]) / size * lowres, (p1[1] - p0[1]) / size * lowres
    x0, y0 = p0[0] / size * lowres, p0[1] / size * lowres
    den = dx * dx + dy * dy
    for y in range(lowres):
        for x in range(lowres):
            t = (((x - x0) * dx + (y - y0) * dy) / den) if den else 0.0
            t = 0.0 if t < 0 else 1.0 if t > 1 else t
            px[x, y] = lerp(c0, c1, t)
    return g.resize((size, size), Image.BILINEAR).convert("RGBA")

def sc(v):
    return v * SS

def new_layer():
    return Image.new("RGBA", (N, N), (0, 0, 0, 0))

def draw_arc(layer, cx, cy, r, a0, a1, width, color):
    d = ImageDraw.Draw(layer)
    box = [sc(cx - r), sc(cy - r), sc(cx + r), sc(cy + r)]
    d.arc(box, a0, a1, fill=color, width=int(sc(width)))

def mask_from(layer):
    return layer.split()[3]

def paste_grad(base, p0, c0, p1, c1, shape_layer):
    """Fill the opaque region of shape_layer with a gradient, onto base."""
    g = grad_fill([sc(p0[0]), sc(p0[1])], c0, [sc(p1[0]), sc(p1[1])], c1)
    g.putalpha(mask_from(shape_layer))
    base.alpha_composite(g)

# ---- palette ----
BG0, BG1, BG2 = (0x0F, 0x3A, 0x40), (0x08, 0x2A, 0x2F), (0x04, 0x16, 0x1A)
PIN0, PIN1 = (0xF4, 0xFF, 0xFC), (0xBC, 0xF4, 0xE2)
DOT0, DOT1 = (0xE8, 0xFF, 0x7A), (0x28, 0xDD, 0xC8)
W0, W1, W2 = (0x28, 0xDD, 0xC8), (0x6F, 0xEA, 0xA0), (0xE6, 0xFF, 0x6A)
TEAL = (0x35, 0xE0, 0xC0)
INK = (0x0A, 0x2A, 0x2E)

CX, CY = 512, 430  # center of the locator dot / radar


def build(round_icon=False):
    img = new_layer()

    # background gradient over rounded square (or circle)
    bgshape = new_layer()
    bd = ImageDraw.Draw(bgshape)
    if round_icon:
        bd.ellipse([sc(64), sc(64), sc(960), sc(960)], fill=(255, 255, 255, 255))
    else:
        bd.rounded_rectangle([sc(64), sc(64), sc(960), sc(960)],
                             radius=sc(214), fill=(255, 255, 255, 255))
    paste_grad(img, (160, 96), BG0, (864, 928), BG2, bgshape)

    # faint radar rings
    rings = new_layer()
    for r in (300, 232):
        draw_arc(rings, CX, CY, r, 0, 360, 2, (0x2F, 0x8E, 0x85, 90))
    img.alpha_composite(rings)

    # signal wave arcs (gradient stroke approximated per-arc tint)
    waves = new_layer()
    draw_arc(waves, CX, CY, 232, 200, 340, 9.5, W1 + (242,))
    draw_arc(waves, CX, CY, 300, 205, 335, 9.5, W0 + (180,))
    img.alpha_composite(waves)

    # drop shadow for the pin group
    pin = new_layer()
    pd = ImageDraw.Draw(pin)
    # teardrop pin: circle top + triangle bottom meeting at (512,712)
    R = 180
    pd.ellipse([sc(CX - R), sc(CY - R), sc(CX + R), sc(CY + R)], fill=(255,) * 4)
    ax = math.radians(35)
    lx = CX - R * math.cos(ax)
    rx = CX + R * math.cos(ax)
    ty = CY + R * math.sin(ax)
    pd.polygon([(sc(lx), sc(ty)), (sc(rx), sc(ty)), (sc(CX), sc(712))],
               fill=(255,) * 4)

    shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sm = pin.split()[3]
    shadow.putalpha(sm)
    shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 90), (0, int(sc(22))), sm)
    shadow = shadow.filter(ImageFilter.GaussianBlur(sc(20)))
    img.alpha_composite(shadow)

    # pin body gradient
    paste_grad(img, (512, 250), PIN0, (512, 712), PIN1, pin)

    # inner ink circle + teal ring + glowing dot
    ov = new_layer()
    od = ImageDraw.Draw(ov)
    od.ellipse([sc(CX - 118), sc(CY - 118), sc(CX + 118), sc(CY + 118)],
               fill=INK + (255,))
    od.ellipse([sc(CX - 118), sc(CY - 118), sc(CX + 118), sc(CY + 118)],
               outline=TEAL + (217,), width=int(sc(14)))
    img.alpha_composite(ov)

    # glow under the dot
    glow = new_layer()
    gd = ImageDraw.Draw(glow)
    gd.ellipse([sc(CX - 70), sc(CY - 70), sc(CX + 70), sc(CY + 70)],
               fill=(0x29, 0xE6, 0xCC, 140))
    glow = glow.filter(ImageFilter.GaussianBlur(sc(10)))
    img.alpha_composite(glow)

    dot = new_layer()
    dd = ImageDraw.Draw(dot)
    dd.ellipse([sc(CX - 52), sc(CY - 52), sc(CX + 52), sc(CY + 52)],
               fill=(255,) * 4)
    paste_grad(img, (470, 388), DOT0, (554, 472), DOT1, dot)

    return img.resize((S, S), Image.LANCZOS)


def main():
    import os
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    res = os.path.join(root, "android", "app", "src", "main", "res")
    sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}

    master = build(round_icon=False)
    master.save(os.path.join(root, "assets", "icon",
                             "signal_finder_icon_1024.png"))

    sq = build(round_icon=False)
    rd = build(round_icon=True)
    for dpi, px in sizes.items():
        d = os.path.join(res, "mipmap-" + dpi)
        sq.resize((px, px), Image.LANCZOS).save(
            os.path.join(d, "ic_launcher.png"))
        rd.resize((px, px), Image.LANCZOS).save(
            os.path.join(d, "ic_launcher_round.png"))
    print("done")


if __name__ == "__main__":
    main()
