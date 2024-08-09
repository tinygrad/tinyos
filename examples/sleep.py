import logging, time, random, math, subprocess
logging.basicConfig(level=logging.INFO)

from pathlib import Path

from tinyturing.display import Display, WIDTH, HEIGHT
from tinyturing.components import Anchor, ComponentParent, Component
from tinyturing.components import Text, MultiCollidingDVDImage, HorizontalProgressBar, VerticalProgressBar, Rectangle, LineGraph

# initialize
display = Display()
display.clear()
display.flip(force=True)

display.clear()

class SleepScreen(Component):
  def __init__(self):
    # # read bmc password from /root/.bmc_password
    # if os.path.exists("/root/.bmc_password"):
    #   try:
    #     with open("/root/.bmc_password", "r") as f:
    #       bmc_password = f.read().strip().split("=")[1].strip()
    #     self.bmc_password = Text(bmc_password, "mono", anchor=Anchor.TOP_RIGHT)
    #     # try setting the bmc password
    #     try: subprocess.run(["ipmitool", "user", "set", "password", "2", bmc_password])
    #     except: logging.warning("Failed to set BMC password")
    #   except: logging.warning("Failed to read BMC password")
    # else: logging.warning("BMC password file not found")
    self.bmc_password = Text("Tq3j11enlGpm", "mono", anchor=Anchor.TOP_RIGHT)

    # bmc_lan_info = subprocess.run(["ipmitool", "lan", "print"], capture_output=True).stdout.decode().split("\n")
    # bmc_ip = next((line.split()[3] for line in bmc_lan_info if "IP Address  " in line), "N/A")
    bmc_ip = "192.168.52.220"

    # ip = subprocess.run(["hostname", "-I"], capture_output=True).stdout.decode().strip()
    # ip = ip.split(" ")[0] if ip else "N/A"
    ip = "192.168.52.22"

    bg_color = 0x000000aa
    self.desc1 = Text("Local IP", "sans", x=WIDTH, anchor=Anchor.TOP_RIGHT)
    self.desc1_bg = Rectangle(len(self.desc1.text) * 32, 64, color=bg_color, x=WIDTH, anchor=Anchor.TOP_RIGHT)
    self.ip = Text(ip, "mono", anchor=Anchor.TOP_RIGHT, parent=ComponentParent(self.desc1, Anchor.BOTTOM_RIGHT))
    self.ip_bg = Rectangle(len(self.ip.text) * 32, 64, color=bg_color, anchor=Anchor.TOP_RIGHT, parent=ComponentParent(self.desc1, Anchor.BOTTOM_RIGHT))
    if hasattr(self, "bmc_password"): self.desc2 = Text("BMC IP & Passwd", "sans", anchor=Anchor.TOP_RIGHT, parent=ComponentParent(self.ip, Anchor.BOTTOM_RIGHT))
    else: self.desc2 = Text("BMC IP", "sans", anchor=Anchor.TOP_RIGHT, parent=ComponentParent(self.ip, Anchor.BOTTOM_RIGHT))
    self.desc2_bg = Rectangle(len(self.desc2.text) * 32, 64, color=bg_color, anchor=Anchor.TOP_RIGHT, parent=ComponentParent(self.ip, Anchor.BOTTOM_RIGHT))
    self.bmc_ip = Text(bmc_ip, "mono", anchor=Anchor.TOP_RIGHT, parent=ComponentParent(self.desc2, Anchor.BOTTOM_RIGHT))
    self.bmc_ip_bg = Rectangle(len(self.bmc_ip.text) * 32, 64, color=bg_color, anchor=Anchor.TOP_RIGHT, parent=ComponentParent(self.desc2, Anchor.BOTTOM_RIGHT))
    if hasattr(self, "bmc_password"):
      self.bmc_password.parent = ComponentParent(self.bmc_ip, Anchor.BOTTOM_RIGHT)
      self.bmc_password_bg = Rectangle(len(self.bmc_password.text) * 32, 64, color=bg_color, anchor=Anchor.TOP_RIGHT, parent=ComponentParent(self.bmc_ip, Anchor.BOTTOM_RIGHT))

    self.logo = MultiCollidingDVDImage([
      Path(__file__).parent / "logo.png",
      Path(__file__).parent / "logo.png",
      Path(__file__).parent / "logo.png",
    ], [
      (200, 77),
      (200, 77),
      (200, 77),
    ], WIDTH, HEIGHT)

  def blit(self, display:Display):
    self.logo.blit(display)
    self.desc1_bg.blit(display)
    self.desc1.blit(display)
    self.ip_bg.blit(display)
    self.ip.blit(display)
    self.desc2_bg.blit(display)
    self.desc2.blit(display)
    self.bmc_ip_bg.blit(display)
    self.bmc_ip.blit(display)
    if hasattr(self, "bmc_password"):
      self.bmc_password_bg.blit(display)
      self.bmc_password.blit(display)

screen = SleepScreen()

while True:
  display.clear()
  screen.blit(display)
  display.flip()

  time.sleep(0.01)
