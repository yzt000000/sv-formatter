"""Generate demo GIFs showing before -> after formatting for the README."""
import re
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TMP = os.path.join(HERE, 'demo-tmp')

BG       = (30, 30, 30)
DEFAULT  = (212, 212, 212)
KEYWORD  = (86, 156, 214)
COMMENT  = (106, 153, 85)
NUMBER   = (181, 206, 168)
SCAN     = (255, 215, 0)

KEYWORDS = {
    'module','endmodule','input','output','inout','wire','reg','logic',
    'assign','always','begin','end','if','else','parameter','posedge',
    'negedge','integer','genvar','generate','endgenerate','for','initial',
}

font = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', 14)
bbox = font.getbbox('M')
char_w = bbox[2] - bbox[0]
line_h = 18
pad = 12

def colorize(line):
    if '//' in line:
        idx = line.index('//')
        return colorize_code(line[:idx]) + [(line[idx:], COMMENT)]
    return colorize_code(line)

def colorize_code(s):
    parts = re.split(r'([A-Za-z_]\w*|\d+)', s)
    res = []
    for p in parts:
        if not p:
            continue
        if p in KEYWORDS:
            res.append((p, KEYWORD))
        elif re.fullmatch(r'\d+', p):
            res.append((p, NUMBER))
        else:
            res.append((p, DEFAULT))
    return res

def make_gif(name, out_path, hold_before=12, hold_after=24, loop_back=8):
    before = open(os.path.join(TMP, f'{name}-before.txt'), encoding='utf-8').read().rstrip('\n').split('\n')
    after  = open(os.path.join(TMP, f'{name}-after.txt'),  encoding='utf-8').read().rstrip('\n').split('\n')

    max_cols = max(max(len(l) for l in before), max(len(l) for l in after))
    total = max(len(before), len(after))
    W = pad * 2 + max_cols * char_w
    H = pad * 2 + total * line_h

    def render(lines, scan_row=-1):
        img = Image.new('RGB', (W, H), BG)
        draw = ImageDraw.Draw(img)
        y = pad
        for line in lines:
            x = pad
            for text, color in colorize(line):
                draw.text((x, y), text, fill=color, font=font)
                x += len(text) * char_w
            y += line_h
        if 0 <= scan_row < total:
            sy = pad + scan_row * line_h
            draw.line([(0, sy - 1), (W, sy - 1)], fill=SCAN, width=2)
            draw.line([(0, sy + line_h), (W, sy + line_h)], fill=SCAN, width=1)
        return img

    frames = []
    for _ in range(hold_before):
        frames.append(render(before))
    for i in range(total + 1):
        visible = []
        for j in range(total):
            if j < i and j < len(after):
                visible.append(after[j])
            elif j < len(before):
                visible.append(before[j])
            else:
                visible.append('')
        frames.append(render(visible, scan_row=i))
    for _ in range(hold_after):
        frames.append(render(after))
    for _ in range(loop_back):
        frames.append(render(before))

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    frames[0].save(
        out_path, save_all=True, append_images=frames[1:],
        duration=55, loop=0, optimize=True, disposal=2,
    )
    print(f'{out_path}  ({len(frames)} frames, {W}x{H}, {os.path.getsize(out_path)/1024:.1f} KB)')

make_gif('sync',     os.path.join(ROOT, 'images', 'demo.gif'))
make_gif('instance', os.path.join(ROOT, 'images', 'demo-instance.gif'))