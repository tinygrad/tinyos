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
    # read bmc password from /root/.bmc_password
    # if os.path.exists("/root/.bmc_password"):
    #   try:
    #     with open("/root/.bmc_password", "r") as f:
    #       bmc_password = f.read().strip().split("=")[1].strip()
    #     self.bmc_password = Text(bmc_password, "mono", y=HEIGHT, anchor=Anchor.BOTTOM_CENTER)
    #     try: subprocess.run(["ipmitool", "user", "set", "password", "2", bmc_password])
    #     except: logging.warning("Failed to set BMC password")
    #   except: logging.warning("Failed to read BMC password")
    # else: logging.warning("BMC password file not found")
    self.bmc_password = Text("BMC PW: Tq3j11enlGpm", "mono", x=WIDTH//2, y=HEIGHT, anchor=Anchor.BOTTOM_CENTER)

    # bmc ip
    # bmc_lan_info = subprocess.run(["ipmitool", "lan", "print"], capture_output=True).stdout.decode().split("\n")
    # bmc_ip = next((line.split()[3] for line in bmc_lan_info if "IP Address  " in line), "N/A")
    bmc_ip = "192.168.52.220"

    if hasattr(self, "bmc_password"): self.bmc_ip = Text(f"BMC: {bmc_ip}", "mono", anchor=Anchor.BOTTOM_CENTER, parent=ComponentParent(self.bmc_password, Anchor.TOP_CENTER))
    else: self.bmc_ip = Text(f"BMC: {bmc_ip}", "mono", x=WIDTH//2, y=HEIGHT, anchor=Anchor.BOTTOM_CENTER)

    # ip
    # ip = subprocess.run(["hostname", "-I"], capture_output=True).stdout.decode().strip()
    # ip = ip.split(" ")[0] if ip else "N/A"
    ip = "192.168.52.22"

    self.ip = Text(f"IP: {ip}", "mono", anchor=Anchor.BOTTOM_CENTER, parent=ComponentParent(self.bmc_ip, Anchor.TOP_CENTER))

    # seperator line
    self.line = Rectangle(WIDTH - WIDTH // 5, 1, y=-8, anchor=Anchor.BOTTOM_CENTER, parent=ComponentParent(self.ip, Anchor.TOP_CENTER))

    # bouncing logo
    offset = -2 if hasattr(self, "bmc_password") else 62
    self.logo = MultiCollidingDVDImage([
      Path(__file__).parent / "logo.png",
    ], [
      (400, 154),
    ], width=WIDTH, height=HEIGHT - (196 - offset), y=offset)

  def blit(self, display:Display):
    self.logo.blit(display)
    if hasattr(self, "bmc_password"):
      self.bmc_password.blit(display)
    self.bmc_ip.blit(display)
    self.ip.blit(display)
    self.line.blit(display)

screen = SleepScreen()

while True:
  display.clear()
  screen.blit(display)
  display.flip()

  time.sleep(0.01)
