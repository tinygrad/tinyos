import logging
logging.basicConfig(level=logging.INFO)

from pathlib import Path

from tinyturing.display import Display, HEIGHT
from tinyturing.components import Anchor, Component, ComponentParent
from tinyturing.components import Image, Text

# initialize
display = Display()
display.clear()
display.flip(force=True)

display.clear()

class WelcomeScreen(Component):
  def __init__(self):
    self.qr = Image(Path(__file__).parent / "docs_qr.png", (300, 300), y=HEIGHT // 2, anchor=Anchor.MIDDLE_LEFT)
    self.desc1 = Text("Scan for Docs", "sans", anchor=Anchor.TOP_LEFT, parent=ComponentParent(self.qr, Anchor.TOP_RIGHT))
    self.bmc_password = Text("<redacted>", "mono", anchor=Anchor.BOTTOM_LEFT, parent=ComponentParent(self.qr, Anchor.BOTTOM_RIGHT))
    self.bmc_ip = Text("<redacted>", "mono", anchor=Anchor.BOTTOM_LEFT, parent=ComponentParent(self.bmc_password, Anchor.TOP_LEFT))
    self.desc2 = Text("BMC IP & Passwd", "sans", anchor=Anchor.BOTTOM_LEFT, parent=ComponentParent(self.bmc_ip, Anchor.TOP_LEFT))

  def blit(self, display:Display):
    self.qr.blit(display)
    self.desc1.blit(display)
    self.bmc_password.blit(display)
    self.bmc_ip.blit(display)
    self.desc2.blit(display)

screen = WelcomeScreen()
screen.blit(display)
display.flip()
