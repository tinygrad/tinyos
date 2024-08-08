import logging
logging.basicConfig(level=logging.INFO)

from pathlib import Path

from tinyturing.display import Display, HEIGHT
from tinyturing.components import Anchor, ComponentParent, Image, Text

# initialize
display = Display()
display.clear()
display.flip(force=True)

display.clear()

qr = Image(Path(__file__).parent / "docs_qr.png", (300, 300), y=HEIGHT // 2, anchor=Anchor.MIDDLE_LEFT)
qr.blit(display)

text = Text("Scan for Docs", "sans", anchor=Anchor.TOP_LEFT, parent=ComponentParent(qr, Anchor.TOP_RIGHT))
text.blit(display)

text = Text("<redacted>", "mono", anchor=Anchor.BOTTOM_LEFT, parent=ComponentParent(qr, Anchor.BOTTOM_RIGHT))
text.blit(display)

text = Text("<redacted>", "mono", anchor=Anchor.BOTTOM_LEFT, parent=ComponentParent(text, Anchor.TOP_LEFT))
text.blit(display)

text = Text("BMC IP & Passwd", "sans", anchor=Anchor.BOTTOM_LEFT, parent=ComponentParent(text, Anchor.TOP_LEFT))
text.blit(display)

display.flip()
