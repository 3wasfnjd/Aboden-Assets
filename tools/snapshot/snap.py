import sys, json, os
from playwright.sync_api import sync_playwright
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
# jobs: list of [assetId, quality, overrides, cam, label]
jobs = json.loads(sys.argv[1])
outp = sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 3
size = 600

html = open(os.path.join(HERE, 'render.html')).read().replace('REPO/', 'file://' + REPO + '/')
tmp = os.path.join(HERE, '_r.html'); open(tmp, 'w').write(html)

imgs = []
with sync_playwright() as p:
    b = p.chromium.launch(executable_path=os.environ.get('CHROME') or None,
                          args=['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--allow-file-access-from-files', '--ignore-gpu-blocklist'])
    pg = b.new_page(viewport={'width': size, 'height': size})
    errs = []
    pg.on('console', lambda m: errs.append(m.text) if m.type == 'error' else None)
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file://' + tmp)
    for a, q, over, cam, label in jobs:
        cam = dict(cam); cam['w'] = size; cam['h'] = size
        info = pg.evaluate('([a,q,o,c]) => render(a,q,o,c)', [a, q, over, cam])
        f = os.path.join(HERE, '_s.png'); pg.locator('#c').screenshot(path=f)
        im = Image.open(f).convert('RGB')
        d = ImageDraw.Draw(im); d.rectangle([0, 0, size, 24], fill=(0, 0, 0))
        d.text((6, 6), f"{label}  {info['tris']} tris  h={info['h']:.1f}", fill=(255, 255, 255))
        imgs.append(im)
    if errs: print('ERRORS', errs[:5])
    b.close()

rows = (len(imgs) + cols - 1) // cols
sheet = Image.new('RGB', (cols * size, rows * size), (30, 30, 30))
for i, im in enumerate(imgs): sheet.paste(im, ((i % cols) * size, (i // cols) * size))
sheet.save(outp)
print('saved', outp, len(imgs))
