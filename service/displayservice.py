import sys
sys.path.insert(0, "/opt/tinybox/screen/")

from display import Display
from socketserver import UnixStreamServer, StreamRequestHandler
import threading, time, signal, os, random, logging
from enum import Enum
from abc import ABC, abstractmethod
from queue import Queue
import numpy as np
import PIL.Image

class Displayable(ABC):
  @abstractmethod
  def display(self, display: Display) -> None: pass

class Text(Displayable):
  def __init__(self, text: str): self.text = text
  def display(self, display: Display):
    # split text into lines
    lines = self.text.split("\n")
    starting_offset = 225 - (80 * (len(lines) - 1)) // 2
    for i, line in enumerate(lines):
      text = display.text(line)
      display.blit(text, (400 - text.shape[0] // 2, starting_offset + (120 - text.shape[1] // 2) + i * 80))

class AText(Displayable):
  def __init__(self, text_states: list[str]): self.text_states, self.current_state = text_states, 0
  def display(self, display: Display):
    text = display.text(self.text_states[self.current_state])
    display.blit(text, (400 - text.shape[0] // 2, 225 + (120 - text.shape[1] // 2)))
    self.current_state = (self.current_state + 1) % len(self.text_states)

class PositionableText(Displayable):
  def __init__(self, text: str, xy: tuple[int, int]):
    self.text, self.x, self.y = text, xy[0], xy[1]
  def display(self, display: Display):
    text = display.text(self.text)
    display.blit(text, (self.x - text.shape[0] // 2, self.y - text.shape[1] // 2))

class VerticalProgressBar(Displayable):
  def __init__(self, value: float, max_value: float, width: int, height: int, x: int):
    self.value, self.max_value, self.width, self.height, self.x = value, max_value, width, height, x
    self.background = np.full((width, height, 3), 20)
  def display(self, display: Display):
    # draw background
    display.blit(self.background, (self.x - self.width // 2, 240 - self.height // 2))
    # draw bar
    bar_height = self.height * self.value // self.max_value
    bar = np.full((self.width, bar_height, 3), 255)
    display.blit(bar, (self.x - self.width // 2, 240 - bar_height // 2))

class Image(Displayable):
  def __init__(self, path: str, xy: tuple[int, int], scale: tuple[int, int]):
    self.image = np.array(PIL.Image.open(path).convert("RGBA").resize(scale)).transpose(1, 0, 2)
    self.x, self.y = xy
  def display(self, display: Display): display.blit(self.image, (self.x, self.y))

class DVDImage(Displayable):
  def __init__(self, path: str, scale: tuple[int, int], speed: float = 1):
    self.image = np.array(PIL.Image.open(path).convert("RGBA").resize(scale)).transpose(1, 0, 2)
    self.x_speed, self.y_speed = speed, speed
    self.reset()
  def display(self, display: Display):
    if self.x + self.image.shape[0] + self.x_speed > 800 or self.x + self.x_speed < 0: self.x_speed *= -1
    if self.y + self.image.shape[1] + self.y_speed > 480 or self.y + self.y_speed < 0: self.y_speed *= -1
    self.x += self.x_speed
    self.y += self.y_speed
    display.blit(self.image, (self.x, self.y))
  def reset(self): self.x, self.y = random.randint(abs(self.x_speed), 800 - self.image.shape[0] - abs(self.x_speed)), random.randint(abs(self.y_speed), 480 - self.image.shape[1] - abs(self.y_speed))

def get_gpu_utilizations() -> list[float]:
  gpu_utilizations = []
  try:
    for i in range(1, 7):
      with open(f"/sys/class/drm/card{i}/device/gpu_busy_percent", "r") as f:
        gpu_utilizations.append(int(f.read().strip()))
  except: logging.warning("Failed to read GPU utilization")
  return gpu_utilizations

def get_gpu_power_draw() -> list[int]:
  gpu_power_draws = []
  try:
    for i in range(1, 7):
      with open(f"/sys/class/drm/card{i}/device/hwmon/hwmon{i+4}/power1_average", "r") as f:
        gpu_power_draws.append(int(f.read().strip()) // 1000000)
  except: logging.warning("Failed to read GPU power draw")
  return gpu_power_draws

DisplayState = Enum("DisplayState", ["TEXT", "STATUS"])
control_queue = Queue()
display_thread_alive = True
def display_thread():
  # initialize display
  display = Display("/dev/ttyACM0")
  display.clear()
  display.flip()

  # load assets
  logo = Image("/opt/tinybox/screen/logo.png", (200, 25), (400, 240))
  logo_sleep = DVDImage("/opt/tinybox/screen/logo.png", (400, 240))

  display_state = DisplayState.TEXT
  display_last_active = time.monotonic()
  start_time = time.monotonic()
  to_display: Displayable | None = None

  while display_thread_alive:
    st = time.perf_counter()
    if not control_queue.empty():
      command, args = control_queue.get()
      logging.info(f"Received command {command} with args {args}")
      if command == "text":
        display_state = DisplayState.TEXT
        to_display = args
        start_time = time.monotonic()
      elif command == "status":
        display_state = DisplayState.STATUS
        display_last_active = time.monotonic()
      elif command == "sleep":
        display_state = DisplayState.TEXT
        to_display = None
        logo_sleep.reset()
    else:
      # reset display state if inactive for 15 seconds
      if time.monotonic() - display_last_active > 15 and display_state == DisplayState.STATUS:
        logging.info("Display inactive for 15 seconds, switching back to sleep text state")
        display_state, to_display = DisplayState.TEXT, None
        display_last_active = time.monotonic()
        logo_sleep.reset()

      # check if display should be in status state
      gpu_utilizations = get_gpu_utilizations()
      logging.debug(f"GPU Utilizations: {gpu_utilizations}")
      mean_gpu_utilization = (sum(gpu_utilizations) / len(gpu_utilizations)) if len(gpu_utilizations) > 0 else 0
      if mean_gpu_utilization > 5 and time.monotonic() - start_time > 10:
        display_state = DisplayState.STATUS
        display_last_active = time.monotonic()

      display.clear()
      if display_state == DisplayState.TEXT:
        if to_display is not None:
          logo.display(display)
          logging.debug(f"Displaying: {to_display}")
          to_display.display(display)
        else: logo_sleep.display(display)
      elif display_state == DisplayState.STATUS:
        for i, utilization in enumerate(gpu_utilizations):
          VerticalProgressBar(utilization, 100, 50, 380, 50 + 75 * i).display(display)
        power_draws = get_gpu_power_draw()
        total_power_draw = sum(power_draws)
        PositionableText(f"{total_power_draw}W", (625, 240)).display(display)

    # update display
    display.flip()
    flip_time = time.perf_counter() - st

    # sleep
    if (sleep_time := 0.08 - flip_time) > 0: time.sleep(sleep_time)

class ControlHandler(StreamRequestHandler):
  def handle(self):
    data = self.rfile.readline().strip(b"\r\n").decode()
    command, *args = data.split(",")
    logging.info(f"Received command {command} with args {args}")
    if command == "text":
      control_queue.put(("text", Text("\n".join(args))))
    elif command == "atext":
      control_queue.put(("text", AText(args)))
    elif command == "status":
      control_queue.put(("status", None))
    elif command == "sleep":
      control_queue.put(("sleep", None))

if __name__ == "__main__":
  logging.basicConfig(level=logging.INFO)

  # start display thread
  dt = threading.Thread(target=display_thread)
  dt.start()

  # handle exit signals
  def signal_handler(sig, frame):
    logging.info("Exiting...")
    global display_thread_alive
    display_thread_alive = False
    os.remove("/run/tinybox-screen.sock")
    sys.exit(0)
  signal.signal(signal.SIGINT, signal_handler)
  signal.signal(signal.SIGTERM, signal_handler)

  # start control server
  with UnixStreamServer("/run/tinybox-screen.sock", ControlHandler) as server:
    os.chmod("/run/tinybox-screen.sock", 0o777)
    server.serve_forever()
