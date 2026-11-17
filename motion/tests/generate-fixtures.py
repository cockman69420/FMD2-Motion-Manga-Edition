"""Generate original, non-manga test assets; Pillow >= 11.3 with AVIF support."""
from pathlib import Path
from PIL import Image, ImageDraw
import zipfile, json, subprocess

out = Path(__file__).parent / 'fixtures'
out.mkdir(exist_ok=True)
frames = []
for i, color in enumerate(['#b8f06c', '#ff976f', '#7cb8ff']):
    im = Image.new('RGB', (640, 180), '#171a1f')
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((30 + i * 165, 30, 170 + i * 165, 150), radius=16, fill=color)
    d.text((26, 8), 'FMD2 Motion / frame ' + str(i + 1), fill='white')
    frames.append(im)
durations = [120, 240, 360]
for ext in ('gif', 'webp', 'png', 'avif'):
    frames[0].save(out / ('animated.' + ext), save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, lossless=True, quality=100)
frames[0].save(out / 'static.png')
frames[0].save(out / 'static.webp', lossless=True)
frames[0].save(out / 'static.jpg', quality=95)
import imageio_ffmpeg
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
for ext, codec in [('mp4', 'libx264'), ('webm', 'libvpx-vp9')]:
    subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y',
                    '-i', str(out / 'animated.gif'), '-t', '2', '-an',
                    '-c:v', codec, '-pix_fmt', 'yuv420p', str(out / ('animated.' + ext))], check=True)
items = ['static.jpg', 'animated.avif', 'animated.webp', 'animated.gif', 'animated.png', 'animated.mp4', 'animated.webm']
for compression, name in ((zipfile.ZIP_STORED, 'demo-motion.cbz'), (zipfile.ZIP_DEFLATED, 'demo-deflate.cbz')):
    with zipfile.ZipFile(out / name, 'w', compression=compression) as z:
        for i, filename in enumerate(items): z.write(out / filename, f'{i+1:03d}-{filename}')
with zipfile.ZipFile(out / 'corrupt-crc.cbz', 'w', compression=zipfile.ZIP_STORED) as z:
    z.writestr('001.jpg', (out / 'static.jpg').read_bytes())
b = bytearray((out / 'corrupt-crc.cbz').read_bytes()); b[50] ^= 0x55
(out / 'corrupt-crc.cbz').write_bytes(b)
(out / 'not-a-zip.cbz').write_bytes(b'not a zip file')
(out / 'parser.html').write_text('''<div class="reading-content">
<div class="page-break no-gaps"><img src=" /one.jpg "></div>
<div class="page-break"><img src="data:image/gif;base64,AA" data-src="https://cdn.example/two.avif"><noscript><img src="https://cdn.example/two.avif"></noscript></div>
<div class="page-break"><picture><source type="image/avif" srcset="three-small.avif 480w, three.avif 1200w"><img src="three.jpg"></picture></div>
<div class="page-break"><video poster="poster.jpg"><source src="//cdn.example/four.webm" type="video/webm"></video></div>
<div class="page-break"><img data-original="five.gif" data-src="thumbnail.jpg" src="placeholder.jpg"></div>
</div><aside><img src="advertisement.webp"></aside>''', encoding='utf-8')
print(json.dumps({'fixtures': len(list(out.iterdir())), 'size': [640, 180], 'durations_ms': durations}))
