import logging, time
logging.basicConfig(level=logging.INFO)

from pathlib import Path

from tinyturing.display import Display
from tinyturing.screens import SleepScreen

# initialize
display = Display()
display.clear()
display.flip(force=True)

display.clear()

screen = SleepScreen(Path(__file__).parent / "logo.png", bmc_password="Tq3j11enlGpm", bmc_ip="192.168.52.220", ip="192.168.52.22")

while True:
  display.clear()
  screen.blit(display)
  display.flip()

  time.sleep(0.01)
