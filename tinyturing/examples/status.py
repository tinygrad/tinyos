import logging, time, random
logging.basicConfig(level=logging.INFO)

from tinyturing.display import Display
from tinyturing.screens import StatusScreen

# initialize
display = Display()
display.clear()
display.flip(force=True)

display.clear()

status_screen = StatusScreen(4)

while True:
  display.clear()
  status_screen.update(
    [random.uniform(50, 100) for _ in range(6)],
    [random.uniform(50, 100) for _ in range(6)],
    [random.uniform(90, 100) for _ in range(64)],
    [random.uniform(50, 450) for _ in range(6)],
    random.uniform(50, 300),
    (random.randint(0, 10000), random.randint(0, 10000))
  )
  status_screen.blit(display)
  display.flip()

  time.sleep(0.01)
