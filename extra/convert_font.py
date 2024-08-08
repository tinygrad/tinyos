# Use https://stmn.github.io/font2bitmap/ to convert a font to a bitmap then feed it to this script to convert it into the format that the display driver is expecting.

import sys

from PIL import Image
import numpy as np

# font is 32x64
# grid is 19x5
font_grid = Image.open(sys.argv[1])
# convert to 8bpp grayscale
font_grid = font_grid.convert("LA")

font_grid_order = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
# sort by ascii
corrected_font_grid_order = sorted(font_grid_order, key=lambda x: ord(x))
# get the index of each char in corrected_font_grid_order
corrected_index = [font_grid_order.index(char) for char in corrected_font_grid_order]

# we want to convert it to a binary array of 95x32x64
chars = []
for y in range(5):
  for x in range(19):
    char = font_grid.crop((x * 32, y * 64, (x + 1) * 32, (y + 1) * 64))
    # numpy array
    char = np.array(char)[:, :, 1]
    chars.append(char)

    # print
    for i in range(64):
      for j in range(32):
        if not char[i, j]: print(" ", end="")
        else:
          print("#", end="")
      print()

# reorder chars to match corrected_font_grid_order
chars = [chars[i] for i in corrected_index]

# save
chars = np.array(chars)
print(chars.shape)
np.save(sys.argv[2], chars)
