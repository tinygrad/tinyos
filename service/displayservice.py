import sys
sys.path.insert(0, "/opt/tinybox/screen/")

from display import Display, WIDTH, HEIGHT
from socketserver import UnixStreamServer, StreamRequestHandler
import threading, time, signal, os, random, logging, math, subprocess
logging.basicConfig(level=logging.INFO)
from enum import Enum
from abc import ABC, abstractmethod
from queue import Queue
import numpy as np
from numba import njit
import PIL.Image
import psutil

class Displayable(ABC):
  @abstractmethod
  def display(self, display: Display) -> None: pass

class Text(Displayable):
  def __init__(self, text: str): self.text = text
  def display(self, display: Display):
    # split text into lines
    lines = self.text.split("\n")
    starting_offset = 225 - (70 * (len(lines) - 1)) // 2
    for i, line in enumerate(lines):
      text = display.text(line)
      display.blit(text, (400 - text.shape[0] // 2, starting_offset + (120 - text.shape[1] // 2) + i * 70))

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
  def __init__(self, value: float, max_value: float, width: int, height: int, x: int, y: int = 240):
    self.value, self.max_value, self.width, self.height, self.x, self.y = value, max_value, width, height, x, y
  def display(self, display: Display):
    # draw bar
    bar_height = self.height * self.value // self.max_value
    bar = np.full((self.width, bar_height, 3), 255)
    display.blit(bar, (self.x - self.width // 2, self.y - bar_height // 2))

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

@njit
def line(x1: int, y1: int, x2: int, y2: int) -> list[tuple[int, int]]:
  points = []
  dx, dy = abs(x2 - x1), abs(y2 - y1)
  sx, sy = 1 if x1 < x2 else -1, 1 if y1 < y2 else -1
  err = dx - dy
  while True:
    points.append((x1, y1))
    if x1 == x2 and y1 == y2: break
    e2 = 2 * err
    if e2 > -dy:
      err -= dy
      x1 += sx
    if e2 < dx:
      err += dx
      y1 += sy
  return points

class LineGraph(Displayable):
  def __init__(self, width: int, height: int, x: int, y: int, points_to_keep: int=20):
    self.width, self.height, self.x, self.y, self.points_to_keep = width, height, x, y, points_to_keep
    self.data = []
  def add_data(self, data: float):
    self.data.append(data)
    if len(self.data) > self.points_to_keep: self.data.pop(0)
  def display(self, display: Display):
    if len(self.data) < 2: return
    min_data, max_data = min(self.data), max(self.data)
    data_range = max_data - min_data
    if data_range == 0: data_range = 1
    surface = np.full((self.width, self.height, 3), 0)
    for i in range(len(self.data) - 1):
      x1, y1 = int(self.width * i / (self.points_to_keep - 1)), self.height - int(self.height * (self.data[i] - min_data) / data_range)
      x2, y2 = int(self.width * (i + 1) / (self.points_to_keep - 1)), self.height - int(self.height * (self.data[i + 1] - min_data) / data_range)
      # draw line
      for point in line(x1, y1, x2, y2):
        # clamp point to graph bounds
        point = (max(0, min(self.width - 1, point[0])), max(0, min(self.height - 1, point[1])))
        surface[point[0], point[1]] = [255, 255, 255]
    display.blit(surface, (self.x - self.width // 2, self.y - self.height // 2))

class StatusScreen(Displayable):
  def __init__(self):
    self.vertical_line = VerticalLine(400, 280, (255, 255, 255))
    self.horizontal_line = HorizontalLine(600, 280, (255, 255, 255))

    self.gpu_bars = [VerticalProgressBar(0, 100, 50, 430, 30 + 64 * i) for i in range(6)]
    self.gpu_mem_bars = [HorizontalProgressBar(0, 100, 160, 5, (425, 100 + 7 * i)) for i in range(6)]
    self.cpu_bars = [VerticalProgressBar(0, 100, 2, 117, 604 + 3 * i, 89) for i in range(64)]

    self.rolling_power_draw = 0
    self.power_draw_text = PositionableText("", (425, 57), "left")
    self.rolling_disk_io = 0
    self.disk_io_text = PositionableText("", (WIDTH - 5, 190), "right")

    self.line_graph = LineGraph(370, 190, 610, 360)
  def update(self, gpu_utilizations: list[float], gpu_memory_utilizations: list[float], cpu_utilizations: list[float], gpu_power_draws: list[int], cpu_power_draw: int, disk_read_write: tuple[int, int]):
    for i, bar in enumerate(self.gpu_bars): bar.value = int(gpu_utilizations[i])
    for i, bar in enumerate(self.gpu_mem_bars): bar.value = int(gpu_memory_utilizations[i])

    for i, bar in enumerate(self.cpu_bars): bar.value = int(cpu_utilizations[i])

    self.rolling_power_draw = math.floor(0.9 * self.rolling_power_draw + 0.1 * sum(gpu_power_draws, cpu_power_draw))
    self.power_draw_text.text = f"{self.rolling_power_draw}W"

    self.rolling_disk_io = math.floor(0.9 * self.rolling_disk_io + 0.1 * sum(disk_read_write))
    self.disk_io_text.text = f"{self.rolling_disk_io}MB/s"

    self.line_graph.add_data(self.rolling_power_draw)
  def display(self, display: Display):
    self.vertical_line.display(display)
    self.horizontal_line.display(display)

    for bar in self.gpu_bars: bar.display(display)
    for bar in self.gpu_mem_bars: bar.display(display)
    for bar in self.cpu_bars: bar.display(display)

    self.power_draw_text.display(display)
    self.disk_io_text.display(display)

    self.line_graph.display(display)

class SleepScreen(Displayable):
  def __init__(self):
    self.logo = DVDImage("/opt/tinybox/screen/logo.png", (400, 154))
    ip = subprocess.run(["hostname", "-I"], capture_output=True).stdout.decode().strip()
    self.ip_text = PositionableText(f"IP: {ip}", (WIDTH, HEIGHT - 102), "right")

    bmc_lan_info = subprocess.run(["ipmitool", "lan", "print"], capture_output=True).stdout.decode().split("\n")
    bmc_ip = next((line.split()[3] for line in bmc_lan_info if "IP Address  " in line), "N/A")
    self.bmc_ip_text = PositionableText(f"BMC: {bmc_ip}", (WIDTH, HEIGHT - 32), "right")
  def display(self, display: Display):
    self.logo.display(display)
    self.ip_text.display(display)
    self.bmc_ip_text.display(display)

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
  total_vrams = [N.nvmlDeviceGetMemoryInfo(handle).total for handle in GPU_HANDLES]
  def get_gpu_memory_utilizations() -> list[float]:
    gpu_memory_utilizations = []
    try:
      for handle in GPU_HANDLES:
        memory = N.nvmlDeviceGetMemoryInfo(handle)
        gpu_memory_utilizations.append(memory.used / memory.total * 100)
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

def get_cpu_utilizations() -> list[float]:
  try:
    return psutil.cpu_percent(percpu=True)
  except:
    logging.warning("Failed to read CPU utilization")
    return []

last_energy, last_energy_time = 0, time.monotonic()
def get_cpu_power_draw() -> int:
  global last_energy, last_energy_time
  try:
    with open("/sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj", "r") as f:
      current_energy = int(f.read().strip())
    current_time = time.monotonic()
    power_draw = (current_energy - last_energy) / (current_time - last_energy_time) / 1e6
    if power_draw < 0:
      # energy counter rolled over
      power_draw = current_energy / (current_time - last_energy_time) / 1e6
    last_energy, last_energy_time = current_energy, current_time
    return int(power_draw)
  except:
    logging.warning("Failed to read CPU power draw")
    return 0

last_disk_read, last_disk_write, last_disk_time = 0, 0, time.monotonic()
def get_disk_io_per_second() -> tuple[int, int]:
  global last_disk_read, last_disk_write, last_disk_time
  counter = psutil.disk_io_counters(perdisk=True)["md0"]
  current_time = time.monotonic()
  disk_read = (counter.read_bytes - last_disk_read) / (current_time - last_disk_time)
  disk_write = (counter.write_bytes - last_disk_write) / (current_time - last_disk_time)
  last_disk_read, last_disk_write, last_disk_time = counter.read_bytes, counter.write_bytes, current_time
  return int(disk_read / 1e6), int(disk_write / 1e6)

DisplayState = Enum("DisplayState", ["TEXT", "STATUS", "SLEEP"])
control_queue = Queue()
display_thread_alive = True
def display_thread():
  try:
    # initialize display
    display = Display()
    display.clear()
    display.flip(force=True)

    # load assets
    logo = Image("/opt/tinybox/screen/logo.png", (200, 60), (400, 154))
    sleep = SleepScreen()

    display_state = DisplayState.SLEEP
    display_last_active = time.monotonic()
    start_time = time.monotonic()
    to_display: Displayable = Text("...")
    status_screen = StatusScreen()

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
          if display_state != DisplayState.SLEEP:
            display_state = DisplayState.SLEEP
            logo_sleep.reset()
      else:
        # reset display state if inactive for 30 seconds
        if time.monotonic() - display_last_active > 30 and display_state == DisplayState.STATUS:
          logging.info("Display inactive for 30 seconds, switching back to sleep state")
          display_state = DisplayState.SLEEP
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
          logo.display(display)
          logging.debug(f"Displaying: {to_display}")
          to_display.display(display)
        elif display_state == DisplayState.STATUS:
          status_screen.update(gpu_utilizations, get_gpu_memory_utilizations(), get_cpu_utilizations(), get_gpu_power_draw(), get_cpu_power_draw(), get_disk_io_per_second())
          status_screen.display(display)
        elif display_state == DisplayState.SLEEP:
          sleep.display(display)

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
