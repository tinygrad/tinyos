import logging, time
logging.basicConfig(level=logging.INFO)

from pathlib import Path

from tinyturing.display import Display, WIDTH, HEIGHT
from tinyturing.components import Anchor, ComponentParent
from tinyturing.components import AnimatedText

# initialize
display = Display()
display.clear()
display.flip(force=True)

display.clear()

text = AnimatedText(["aaa\nbbb\nccc", "bbb\nccc\naaa", "ccc\naaa\nbbb"], "sans", x=WIDTH // 2, y=HEIGHT // 2, anchor=Anchor.MIDDLE_CENTER)

while True:
  display.clear()
  text.blit(display)
  display.flip()

  time.sleep(0.1)
