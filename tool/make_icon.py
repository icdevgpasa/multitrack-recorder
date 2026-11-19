import math, sys
from PIL import Image, ImageDraw, ImageFilter

S = 1024
SS = 2  # supersample
W = S * SS

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

# Background: diagonal deep violet → near-black → teal-black.
bg = Image.new("RGB", (W, W))
px = bg.load()
c0, c1, c2 = (38, 22, 92), (11, 12, 22), (6, 30, 38)
for y in range(W):
    for x in range(0, W):
        t = (x + y) / (2 * W)
        px[x, y] = lerp(c0, c1, t / 0.55) if t < 0.55 else lerp(c1, c2, (t - 0.55) / 0.45)

# Soft glows.
glow = Image.new("RGB", (W, W), (0, 0, 0))
g = ImageDraw.Draw(glow)
g.ellipse([W*0.05, W*0.05, W*0.75, W*0.75], fill=(90, 60, 220))
g.ellipse([W*0.45, W*0.45, W*1.05, W*1.05], fill=(0, 140, 130))
glow = glow.filter(ImageFilter.GaussianBlur(W * 0.12))
bg = Image.blend(bg, Image.eval(glow, lambda v: v), 0.35)

# Three stacked waveform tracks in track colours.
img = bg.convert("RGBA")
layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(layer)
colors = [(124, 92, 255), (0, 209, 193), (255, 178, 56)]
rows = [0.33, 0.50, 0.67]
bars = 15
left, right = W * 0.17, W * 0.83
step = (right - left) / bars
bw = step * 0.56
for r, (cy, col) in enumerate(zip(rows, colors)):
    for i in range(bars):
        x = left + i * step + (step - bw) / 2
        a = 0.25 + 0.75 * abs(math.sin(i * 0.9 + r * 1.7)) * (0.55 + 0.45 * math.sin(i / bars * math.pi))
        h = W * 0.13 * a
        d.rounded_rectangle([x, cy * W - h / 2, x + bw, cy * W + h / 2], radius=bw / 2, fill=col + (255,))
glow2 = layer.filter(ImageFilter.GaussianBlur(W * 0.012))
img = Image.alpha_composite(img, glow2)
img = Image.alpha_composite(img, layer)

# Record dot, bottom-right, with glow.
rec = Image.new("RGBA", (W, W), (0, 0, 0, 0))
rd = ImageDraw.Draw(rec)
cx, cy, rr = W * 0.75, W * 0.80, W * 0.085
rd.ellipse([cx - rr * 1.6, cy - rr * 1.6, cx + rr * 1.6, cy + rr * 1.6], fill=(255, 59, 92, 120))
rec = rec.filter(ImageFilter.GaussianBlur(W * 0.03))
img = Image.alpha_composite(img, rec)
d = ImageDraw.Draw(img)
d.ellipse([cx - rr * 1.25, cy - rr * 1.25, cx + rr * 1.25, cy + rr * 1.25], fill=(11, 12, 22, 255))
d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(255, 59, 92, 255))

out = img.convert("RGB").resize((S, S), Image.LANCZOS)  # opaque, no alpha
out.save(sys.argv[1])
