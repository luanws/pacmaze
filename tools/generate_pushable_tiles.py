"""
Generates pushable-wall tiles by copying the wall styles from row 1 of walls.png
and overlaying directional arrow markers to make them visually distinct.
The new row is appended as row 2 of the atlas.
"""
from PIL import Image, ImageDraw

TILE = 30
COLS = 11

img = Image.open(r"assets/sprites/walls.png")
assert img.size == (COLS * TILE, 2 * TILE), f"Unexpected size: {img.size}"

# Create a new image with one more row.
new_img = Image.new("RGBA", (COLS * TILE, 3 * TILE), (0, 0, 0, 0))
new_img.paste(img, (0, 0))

for col in range(COLS):
    # Copy the wall tile from row 1.
    x0 = col * TILE
    tile = img.crop((x0, TILE, x0 + TILE, 2 * TILE)).copy()

    # Darken the tile slightly to differentiate.
    pixels = tile.load()
    for py in range(TILE):
        for px in range(TILE):
            r, g, b, a = pixels[px, py]
            if a > 0:
                pixels[px, py] = (int(r * 0.7), int(g * 0.7), int(b * 0.7), a)

    # Draw arrow markers (4 small triangles pointing inward from each edge).
    draw = ImageDraw.Draw(tile)
    cx, cy = TILE // 2, TILE // 2
    arrow_color = (255, 255, 100, 220)  # Yellowish

    # Size parameters.
    tip_dist = 7    # How far the tip is from center.
    base_dist = 13  # How far the base corners are from center.
    spread = 4      # Half-width of the arrow base.

    # Up arrow (pointing down toward center).
    draw.polygon([
        (cx, cy - tip_dist),
        (cx - spread, cy - base_dist),
        (cx + spread, cy - base_dist),
    ], fill=arrow_color)

    # Down arrow (pointing up toward center).
    draw.polygon([
        (cx, cy + tip_dist),
        (cx - spread, cy + base_dist),
        (cx + spread, cy + base_dist),
    ], fill=arrow_color)

    # Left arrow (pointing right toward center).
    draw.polygon([
        (cx - tip_dist, cy),
        (cx - base_dist, cy - spread),
        (cx - base_dist, cy + spread),
    ], fill=arrow_color)

    # Right arrow (pointing left toward center).
    draw.polygon([
        (cx + tip_dist, cy),
        (cx + base_dist, cy - spread),
        (cx + base_dist, cy + spread),
    ], fill=arrow_color)

    new_img.paste(tile, (x0, 2 * TILE), tile)

new_img.save(r"assets/sprites/walls.png")
print(f"Done — walls.png is now {new_img.size[0]}x{new_img.size[1]}")
