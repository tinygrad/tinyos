import logging
logging.basicConfig(level=logging.INFO)

from pathlib import Path

from tinyturing.display import Display
from tinyturing.screens import WelcomeScreen

# initialize
display = Display()
display.clear()
display.flip(force=True)

display.clear()

screen = WelcomeScreen(Path(__file__).parent / "docs_qr.png", bmc_password="<redacted>", bmc_ip="<redacted>")
screen.blit(display)
display.flip()
