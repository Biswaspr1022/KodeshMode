#!/usr/bin/env python3
import argparse
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SIZES = [12, 18, 22, 24, 28, 30, 36, 44, 52, 60, 68, 76, 84]
FAMILIES = [
    ("Varela", "varela", "varela")
]

# ASCII source only: build Hebrew chars by Unicode ranges.
def make_chars():
    chars = []

    def add(s):
        for ch in s:
            if ch not in chars:
                chars.append(ch)

    add(" ")
    add("0123456789")
    add("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")

    # Hebrew letters U+05D0..U+05EA, includes final forms.
    for code in range(0x05D0, 0x05EB):
        add(chr(code))

    # Common Hebrew punctuation: geresh/gershayim/maqaf.
    add(chr(0x05F3))
    add(chr(0x05F4))
    add(chr(0x05BE))

    add(".,:;!?/\\-–—_()[]{}'\"+*=<>%@#&|~")
    return "".join(chars)

CHARS = make_chars()


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--varela", required=True, help="Path to VarelaRound-Regular.ttf")
    # parser.add_argument("--stam", required=True, help="Path to Stam TTF")
    # parser.add_argument("--simple", required=True, help="Path to Simple TTF")
    parser.add_argument("--out", default="resources", help="Resources directory")
    parser.add_argument("--atlas-width", type=int, default=1024)
    parser.add_argument("--padding", type=int, default=1)
    parser.add_argument("--extra-line-padding", type=int, default=2)
    return parser.parse_args()


def font_path_for(args, key):
    if key == "varela":
        return Path(args.varela)
    if key == "stam":
        return Path(args.stam)
    if key == "simple":
        return Path(args.simple)
    raise ValueError(key)


def ceil_num(v):
    return int(math.ceil(v))


def next_power_of_two(v):
    p = 1
    while p < v:
        p *= 2
    return p


def render_glyph(font, ch, padding):
    if ch == " ":
        advance = max(1, ceil_num(font.getlength(ch)))
        img = Image.new("RGBA", (1, 1), (0, 0, 0, 0))
        return img, 0, 0, advance

    # Measure with a temporary draw object. The bbox may have negative offsets.
    probe = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    draw = ImageDraw.Draw(probe)
    bbox = draw.textbbox((0, 0), ch, font=font)
    x0, y0, x1, y1 = bbox

    w = max(1, x1 - x0)
    h = max(1, y1 - y0)

    # Render the glyph into its own bitmap with padding.
    img = Image.new("RGBA", (w + padding * 2, h + padding * 2), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(img)
    # Drawing at (padding - x0, padding - y0) ensures the glyph's (x0, y0)
    # is at (padding, padding) in our new image.
    gdraw.text((padding - x0, padding - y0), ch, font=font, fill=(255, 255, 255, 255))

    # Patch the Varela Round "Qof" (ק) letter which has a connecting line
    # between the two legs. Erase all pixels (including anti-aliased ones)
    # in the middle third of rows where both legs are present but the
    # middle is not fully solid.
    if ch == chr(0x05E7):
        ALPHA_THRESH = 5  # catch even faint anti-aliased pixels
        iwidth, iheight = img.size
        leftmost, rightmost = iwidth, 0
        for y in range(iheight):
            for x in range(iwidth):
                if img.getpixel((x,y))[3] > ALPHA_THRESH:
                    leftmost, rightmost = min(leftmost, x), max(rightmost, x)
        if rightmost > leftmost:
            left_leg_max = leftmost + (rightmost - leftmost) // 3
            right_leg_min = rightmost - (rightmost - leftmost) // 3
            for y in range(iheight):
                has_left = any(img.getpixel((x,y))[3] > ALPHA_THRESH for x in range(leftmost, left_leg_max))
                has_right = any(img.getpixel((x,y))[3] > ALPHA_THRESH for x in range(right_leg_min, rightmost + 1))
                if has_left and has_right:
                    middle_solid = all(img.getpixel((x,y))[3] > 200 for x in range(left_leg_max, right_leg_min))
                    if not middle_solid:
                        for x in range(left_leg_max, right_leg_min):
                            img.putpixel((x,y), (0,0,0,0))

    xoffset = x0 - padding
    yoffset = y0 - padding
    advance = ceil_num(font.getlength(ch))

    return img, xoffset, yoffset, advance


def pack_glyphs(glyphs, atlas_width, padding, line_height):
    x = padding
    y = padding
    row_h = line_height
    packed = []

    for rec in glyphs:
        img = rec["img"]
        if x + img.size[0] + padding > atlas_width:
            x = padding
            y += row_h + padding
            row_h = line_height

        packed.append((rec, x, y, rec["yoffset"]))
        x += img.size[0] + padding
        row_h = max(row_h, img.size[1])

    atlas_height = next_power_of_two(y + row_h + padding)
    return packed, atlas_height


def write_fnt(path, png_name, face, size, line_height, base, atlas_width, atlas_height, packed):
    lines = []
    lines.append(
        'info face="{}" size={} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0'.format(face, size)
    )
    lines.append(
        'common lineHeight={} base={} scaleW={} scaleH={} pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4'.format(line_height, base, atlas_width, atlas_height)
    )
    lines.append('page id=0 file="{}"'.format(png_name))
    lines.append('chars count={}'.format(len(packed)))

    for rec, x, y, yoff in packed:
        img = rec["img"]
        lines.append(
            'char id={} x={} y={} width={} height={} xoffset={} yoffset={} xadvance={} page=0 chnl=15'.format(
                rec["id"], x, y, img.size[0], img.size[1], rec["xoffset"], yoff, rec["advance"]
            )
        )

    lines.append('kernings count=0')
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def generate_one(ttf_path, rez_id, file_id, size, fonts_dir, atlas_width, padding, extra_line_padding):
    if not ttf_path.exists():
        raise FileNotFoundError(str(ttf_path))

    font = ImageFont.truetype(str(ttf_path), size)
    glyphs = []
    max_h = 1

    for ch in CHARS:
        img, xoffset, yoffset, advance = render_glyph(font, ch, padding)
        max_h = max(max_h, img.size[1])
        glyphs.append({
            "char": ch,
            "id": ord(ch),
            "img": img,
            "advance": advance,
            "xoffset": xoffset,
            "yoffset": yoffset,
        })

    line_height = max_h + extra_line_padding
    base = int(line_height * 0.80)
    packed, atlas_height = pack_glyphs(glyphs, atlas_width, padding, line_height)

    atlas = Image.new("RGBA", (atlas_width, atlas_height), (0, 0, 0, 0))
    for rec, x, y, yoff in packed:
        atlas.alpha_composite(rec["img"], (x, y))

    png_path = fonts_dir / (file_id + ".png")
    fnt_path = fonts_dir / (file_id + ".fnt")
    atlas.save(png_path)

    write_fnt(
        fnt_path,
        png_path.name,
        ttf_path.stem,
        size,
        line_height,
        base,
        atlas_width,
        atlas_height,
        packed,
    )
    print("Generated {}: {}".format(rez_id, fnt_path))
    return rez_id, file_id


def write_fonts_xml(resources_dir, generated):
    lines = ["<resources>"]
    for rez_id, file_id in generated:
        lines.append('    <font id="{}" filename="fonts/{}.fnt" antialias="true" />'.format(rez_id, file_id))
    lines.append("</resources>")
    (resources_dir / "fonts.xml").write_text('\n'.join(lines) + '\n', encoding='utf-8')


def main():
    args = parse_args()
    resources_dir = Path(args.out)
    fonts_dir = resources_dir / "fonts"
    fonts_dir.mkdir(parents=True, exist_ok=True)

    generated = []
    for rez_prefix, file_prefix, family_key in FAMILIES:
        ttf_path = font_path_for(args, family_key)
        for size in SIZES:
            generated.append(
                generate_one(
                    ttf_path,
                    "{}{}".format(rez_prefix, size),
                    "{}_{}".format(file_prefix, size),
                    size,
                    fonts_dir,
                    args.atlas_width,
                    args.padding,
                    args.extra_line_padding,
                )
            )

    write_fonts_xml(resources_dir, generated)
    print("Generated {}".format(resources_dir / "fonts.xml"))


if __name__ == "__main__":
    main()
