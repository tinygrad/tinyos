import sys
sys.path.insert(0, "/opt/tinybox/screen/")

from display import Display
from socketserver import UnixStreamServer, StreamRequestHandler
import threading, time, signal, os, random, logging, math
logging.basicConfig(level=logging.INFO)
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
  def __init__(self, text_states: list[str]):
    self.text_states, self.current_state = [], 0
    for text_state in text_states: self.text_states.extend([text_state] * 2)
  def display(self, display: Display):
    text = display.text(self.text_states[self.current_state])
    display.blit(text, (400 - text.shape[0] // 2, 225 + (120 - text.shape[1] // 2)))
    self.current_state = (self.current_state + 1) % len(self.text_states)

class PositionableText(Displayable):
  def __init__(self, text: str, xy: tuple[int, int], align: str = "center"):
    self.text, self.x, self.y, self.align = text, xy[0], xy[1], align
  def display(self, display: Display):
    text = display.text(self.text)
    if self.align == "center": display.blit(text, (self.x - text.shape[0] // 2, self.y - text.shape[1] // 2))
    elif self.align == "left": display.blit(text, (self.x, self.y - text.shape[1] // 2))
    elif self.align == "right": display.blit(text, (self.x - text.shape[0], self.y - text.shape[1] // 2))

class VerticalProgressBar(Displayable):
  def __init__(self, value: float, max_value: float, width: int, height: int, x: int):
    self.value, self.max_value, self.width, self.height, self.x = value, max_value, width, height, x
    self.background = np.full((width, height, 3), 25)
  def display(self, display: Display):
    # draw background
    display.blit(self.background, (self.x - self.width // 2, 240 - self.height // 2))
    # draw bar
    bar_height = self.height * self.value // self.max_value
    bar = np.full((self.width, bar_height, 3), 255)
    display.blit(bar, (self.x - self.width // 2, 240 - bar_height // 2))

class HorizontalProgressBar(Displayable):
  def __init__(self, value: float, max_value: float, width: int, height: int, xy: tuple[int, int]):
    self.value, self.max_value, self.width, self.height, self.x, self.y = value, max_value, width, height, xy[0], xy[1]
    self.background = np.full((width, height, 3), 50)
  def display(self, display: Display):
    # draw background
    display.blit(self.background, (self.x, self.y - self.height // 2))
    # draw bar
    bar_width = self.width * self.value // self.max_value
    bar = np.full((bar_width, self.height, 3), 255)
    display.blit(bar, (self.x, self.y - self.height // 2))

class VerticalLine(Displayable):
  def __init__(self, x: int, height: int, color: tuple[int, int, int]):
    self.x, self.height, self.color = x, height, color
  def display(self, display: Display):
    line = np.full((1, self.height, 3), self.color)
    display.blit(line, (self.x, 240 - self.height // 2))

class HorizontalLine(Displayable):
  def __init__(self, x: int, width: int, color: tuple[int, int, int]):
    self.x, self.width, self.color = x, width, color
  def display(self, display: Display):
    line = np.full((self.width, 1, 3), self.color)
    display.blit(line, (self.x - self.width // 2, 240))

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

def line(x1: int, y1: int, x2: int, y2: int):
  if abs(x2 - x1) < abs(y2 - y1):
    xx, yy, val = line(y1, x1, y2, x2)
    return yy, xx, val
  if x1 > x2: return line(x2, y2, x1, y1)
  x = np.arange(x1, x2 + 1, dtype=float)
  y = x * (y2 - y1) / (x2 - x1) + (x2 * y1 - x1 * y2) / (x2 - x1)

  valbot = np.floor(y) - y + 1
  valtop = y - np.floor(y)
  return np.concatenate((np.floor(y), np.floor(y) + 1)).astype(int), np.concatenate((x, x)).astype(int), np.concatenate((valbot, valtop))

class LineGraph(Displayable):
  def __init__(self, width: int, height: int, x: int, y: int, points_to_keep: int=10):
    self.width, self.height, self.x, self.y, self.points_to_keep = width, height, x, y, points_to_keep
    self.data = []
  def add_data(self, data: float):
    self.data.append(data)
    if len(self.data) > self.points_to_keep: self.data.pop(0)
  def display(self, display: Display):
    if len(self.data) < 2: return
    max_data, min_data = max(self.data), min(self.data)
    if max_data == min_data: return
    surface = np.full((self.width, self.height, 3), 0)
    for i in range(len(self.data) - 1):
      x1, y1 = int(self.width * i / (self.points_to_keep - 1)), int((self.height - 1) * (self.data[i] - min_data) / (max_data - min_data))
      x2, y2 = int(self.width * (i + 1) / (self.points_to_keep - 1)), int((self.height - 1) * (self.data[i + 1] - min_data) / (max_data - min_data))
      # draw line
      yy, xx, val = line(x1, y1, x2, y2)
      surface[yy, xx] = (255 * val).astype(int)[..., None]
    display.blit(surface, (self.x - self.width // 2, self.y - self.height // 2))

# determine GPU type
try:
  import pynvml as N
  logging.info("pynvml found, assuming NVIDIA GPU")
  N.nvmlInit()
  GPU_HANDLES = [N.nvmlDeviceGetHandleByIndex(i) for i in range(6)]
  def get_gpu_utilizations() -> list[float]:
    gpu_utilizations = []
    try:
      for handle in GPU_HANDLES:
        utilization = N.nvmlDeviceGetUtilizationRates(handle)
        gpu_utilizations.append(utilization.gpu)
    except:
      logging.warning("Failed to read GPU utilization")
      return []
    return gpu_utilizations
  def get_gpu_memory_utilizations() -> list[float]:
    gpu_memory_utilizations = []
    try:
      for handle in GPU_HANDLES:
        utilization = N.nvmlDeviceGetUtilizationRates(handle)
        gpu_memory_utilizations.append(utilization.memory)
    except:
      logging.warning("Failed to read GPU memory utilization")
      return []
    return gpu_memory_utilizations
  def get_gpu_power_draw() -> list[int]:
    gpu_power_draws = []
    try:
      for handle in GPU_HANDLES:
        power = N.nvmlDeviceGetPowerUsage(handle)
        gpu_power_draws.append(power // 1000)
    except:
      logging.warning("Failed to read GPU power draw")
      return []
    return gpu_power_draws
except ImportError:
  logging.info("pynvml not found, assuming AMD GPU")
  def get_gpu_utilizations() -> list[float]:
    gpu_utilizations = []
    try:
      for i in range(1, 7):
        with open(f"/sys/class/drm/card{i}/device/gpu_busy_percent", "r") as f:
          gpu_utilizations.append(int(f.read().strip()))
    except:
      logging.warning("Failed to read GPU utilization")
      return []
    return gpu_utilizations

  def get_gpu_memory_utilizations() -> list[float]:
    gpu_memory_utilizations = []
    try:
      for i in range(1, 7):
        with open(f"/sys/class/drm/card{i}/device/mem_info_vram_used", "r") as f:
          used = int(f.read().strip())
        with open(f"/sys/class/drm/card{i}/device/mem_info_vram_total", "r") as f:
          total = int(f.read().strip())
        gpu_memory_utilizations.append(used / total * 100)
    except:
      logging.warning("Failed to read GPU memory utilization")
      return []
    return gpu_memory_utilizations

  def get_gpu_power_draw() -> list[int]:
    gpu_power_draws = []
    try:
      for i in range(1, 7):
        with open(f"/sys/class/drm/card{i}/device/hwmon/hwmon{i+4}/power1_average", "r") as f:
          gpu_power_draws.append(int(f.read().strip()) // 1000000)
    except:
      logging.warning("Failed to read GPU power draw")
      return []
    return gpu_power_draws

DisplayState = Enum("DisplayState", ["TEXT", "STATUS"])
control_queue = Queue()
display_thread_alive = True
def display_thread():
  try:
    # initialize display
    display = Display()
    display.clear()
    display.flip(force=True)

    # load assets
    logo = Image("/opt/tinybox/screen/logo.png", (200, 68), (400, 154))
    logo_sleep = DVDImage("/opt/tinybox/screen/logo.png", (400, 154))

    display_state = DisplayState.TEXT
    display_last_active = time.monotonic()
    start_time = time.monotonic()
    to_display: Displayable | None = None
    total_power_draw_avg = 0
    status_graph = LineGraph(350, 190, 600, 360)

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
          if to_display is not None or display_state != DisplayState.TEXT:
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
        if any(map(lambda x: x > 2, gpu_utilizations)) and time.monotonic() - start_time > 10:
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
            VerticalProgressBar(utilization, 100, 50, 430, 50 + 60 * i).display(display)

          VerticalLine(400, 280, (255, 255, 255)).display(display)
          HorizontalLine(600, 280, (255, 255, 255)).display(display)

          total_power_draw = sum(get_gpu_power_draw())
          total_power_draw_avg = math.floor(0.9 * total_power_draw_avg + 0.1 * total_power_draw)
          PositionableText(f"{total_power_draw_avg}W", (425, 90), "left").display(display)

          memory_utilizations = get_gpu_memory_utilizations()
          mean_memory_utilization = int(sum(memory_utilizations) / len(memory_utilizations))
          HorizontalProgressBar(mean_memory_utilization, 100, 175, 50, (425, 150)).display(display)

          status_graph.add_data(total_power_draw_avg)
          status_graph.display(display)

      # update display
      display.flip()
      flip_time = time.perf_counter() - st

      # sleep
      if (sleep_time := 0.05 - flip_time) > 0: time.sleep(sleep_time)
  except Exception as e:
    logging.error(f"Display thread error: {e}")
    # stacktrace
    import traceback
    traceback.print_exc()
    os._exit(1)

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
  if os.path.exists("/run/tinybox-screen.sock"): os.remove("/run/tinybox-screen.sock")
  with UnixStreamServer("/run/tinybox-screen.sock", ControlHandler) as server:
    os.chmod("/run/tinybox-screen.sock", 0o777)
    server.serve_forever()
