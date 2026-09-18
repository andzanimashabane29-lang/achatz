from PIL import Image, ImageDraw
import os

root = os.path.dirname(os.path.abspath(__file__))
project = os.path.abspath(os.path.join(root, '..'))
src = os.path.join(project, 'assets', 'logo.png')
if not os.path.exists(src):
    raise FileNotFoundError(src)
logo = Image.open(src).convert('RGBA')
size = 1024
a = Image.new('RGBA', (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(a)
corner = 192
fill = (255, 255, 255, 255)
draw.rounded_rectangle((72, 72, size-72, size-72), radius=corner, fill=fill)
max_logo = int(size * 0.8)
w, h = logo.size
scale = min(max_logo / w, max_logo / h)
logo = logo.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
pos = ((size - logo.width) // 2, (size - logo.height) // 2)
a.alpha_composite(logo, dest=pos)
out_path = os.path.join(project, 'assets', 'splash_logo.png')
a.save(out_path)
print('wrote', out_path, 'size', os.path.getsize(out_path))