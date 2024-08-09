import sys
sys.path.insert(0, "/opt/tinybox/tinyturing/")
sys.path.insert(0, "/opt/tinybox/service/displayservice/")

from socketserver import UnixStreamServer, StreamRequestHandler
import threading, time, signal, os, logging, math, subprocess
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] <%(filename)s:%(lineno)d::%(funcName)s> - %(message)s")
from enum import Enum
from queue import Queue

from tinyturing.display import Display, WIDTH, HEIGHT
from tinyturing.components import Anchor, Component, ComponentParent
from tinyturing.components import Text, Image, MultiCollidingDVDImage, AnimatedText, Rectangle, LineGraph, VerticalProgressBar, HorizontalProgressBar
from stats import get_gpu_utilizations, get_gpu_memory_utilizations, get_cpu_utilizations, get_gpu_power_draw, get_cpu_power_draw, get_disk_io_per_second

class StatusScreen(Component):
  def __init__(self):
    self.gpu_bars = [VerticalProgressBar(50, 430, x=30 + 64 * i, y=HEIGHT // 2) for i in range(6)]
    self.gpu_mem_bars = [HorizontalProgressBar(160, 5, x=425, y=100 + 7 * i, anchor=Anchor.MIDDLE_LEFT) for i in range(6)]
    self.gpu_mem_bar_backgrounds = [Rectangle(160, 5, color=0x323232ff, x=425, y=100 + 7 * i, anchor=Anchor.MIDDLE_LEFT) for i in range(6)]

    self.vertical_separator = Rectangle(1, 280, x=WIDTH // 2, y=HEIGHT // 2)
    self.horizontal_separator = Rectangle(280, 1, x=WIDTH // 2 + WIDTH // 4, y=HEIGHT // 2)

    self.cpu_bars = [VerticalProgressBar(2, 117, x=604 + 3 * i, y=84) for i in range(64)]

    self.rolling_power_draw = 0
    self.power_draw_text = Text("0W", style="mono", x=425, y=57, anchor=Anchor.MIDDLE_LEFT)
    self.rolling_disk_io = 0
    self.disk_io_text = Text("0MB/s", style="mono", x=WIDTH - 5, y=190, anchor=Anchor.MIDDLE_RIGHT)

    self.line_graph = LineGraph(370, 190, x=610, y=360)

  def update(self, gpu_utilizations: list[float], gpu_memory_utilizations: list[float], cpu_utilizations: list[float], gpu_power_draws: list[float], cpu_power_draw: float, disk_io: tuple[int, int]):
    for i, bar in enumerate(self.gpu_bars): bar.value = gpu_utilizations[i]
    for i, bar in enumerate(self.gpu_mem_bars): bar.value = gpu_memory_utilizations[i]
    for i, bar in enumerate(self.cpu_bars): bar.value = cpu_utilizations[i]

    self.rolling_power_draw = math.floor(0.8 * self.rolling_power_draw + 0.2 * sum(gpu_power_draws, cpu_power_draw))
    self.power_draw_text.text = f"{self.rolling_power_draw}W"

    self.rolling_disk_io = math.floor(0.8 * self.rolling_disk_io + 0.2 * sum(disk_io))
    self.disk_io_text.text = f"{self.rolling_disk_io}MB/s"

    self.line_graph.add_data(self.rolling_power_draw)

  def blit(self, display:Display):
    for bar in self.gpu_bars: bar.blit(display)
    for bar in self.gpu_mem_bar_backgrounds: bar.blit(display)
    for bar in self.gpu_mem_bars: bar.blit(display)
    self.vertical_separator.blit(display)
    self.horizontal_separator.blit(display)
    for bar in self.cpu_bars: bar.blit(display)
    self.power_draw_text.blit(display)
    self.disk_io_text.blit(display)
    self.line_graph.blit(display)

class SleepScreen(Component):
  def __init__(self):
    # read bmc password from /root/.bmc_password
    if os.path.exists("/root/.bmc_password"):
      try:
        with open("/root/.bmc_password", "r") as f:
          bmc_password = f.read().strip().split("=")[1].strip()
        self.bmc_password = Text(bmc_password, "mono", anchor=Anchor.TOP_RIGHT)
        # try setting the bmc password
        try: subprocess.run(["ipmitool", "user", "set", "password", "2", bmc_password])
        except: logging.warning("Failed to set BMC password")
      except: logging.warning("Failed to read BMC password")
    else: logging.warning("BMC password file not found")

    bmc_lan_info = subprocess.run(["ipmitool", "lan", "print"], capture_output=True).stdout.decode().split("\n")
    bmc_ip = next((line.split()[3] for line in bmc_lan_info if "IP Address  " in line), "N/A")

    ip = subprocess.run(["hostname", "-I"], capture_output=True).stdout.decode().strip()
    ip = ip.split(" ")[0] if ip else "N/A"

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
      "/opt/tinybox/service/logo.png",
      "/opt/tinybox/service/logo.png",
    ], [
      (200, 77),
      (200, 77),
    ], width=WIDTH, height=HEIGHT)

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

class WelcomeScreen(Component):
  def __init__(self):
    self.qr = Image("/opt/tinybox/service/docs_qr.png", (300, 300), y=HEIGHT // 2, anchor=Anchor.MIDDLE_LEFT)
    self.desc1 = Text("Scan for Docs", "sans", anchor=Anchor.TOP_LEFT, parent=ComponentParent(self.qr, Anchor.TOP_RIGHT))

    # read bmc password from /root/.bmc_password
    if os.path.exists("/root/.bmc_password"):
      try:
        with open("/root/.bmc_password", "r") as f:
          bmc_password = f.read().strip().split("=")[1].strip()
        self.bmc_password = Text(bmc_password, "mono", anchor=Anchor.BOTTOM_LEFT, parent=ComponentParent(self.qr, Anchor.BOTTOM_RIGHT))
        # try setting the bmc password
        try: subprocess.run(["ipmitool", "user", "set", "password", "2", bmc_password])
        except: logging.warning("Failed to set BMC password")
      except: logging.warning("Failed to read BMC password")
    else: logging.warning("BMC password file not found")

    bmc_lan_info = subprocess.run(["ipmitool", "lan", "print"], capture_output=True).stdout.decode().split("\n")
    bmc_ip = next((line.split()[3] for line in bmc_lan_info if "IP Address  " in line), "N/A")

    self.bmc_ip = Text(bmc_ip, "mono", anchor=Anchor.BOTTOM_LEFT, parent=ComponentParent(self.qr, Anchor.BOTTOM_RIGHT))
    if hasattr(self, "bmc_password"):
      self.bmc_ip.parent = ComponentParent(self.bmc_password, Anchor.TOP_LEFT)
      self.desc2 = Text("BMC IP & Passwd", "sans", anchor=Anchor.BOTTOM_LEFT, parent=ComponentParent(self.bmc_ip, Anchor.TOP_LEFT))
    else: self.desc2 = Text("BMC IP", "sans", anchor=Anchor.BOTTOM_LEFT, parent=ComponentParent(self.bmc_ip, Anchor.TOP_LEFT))

  def blit(self, display:Display):
    self.qr.blit(display)
    self.desc1.blit(display)
    if hasattr(self, "bmc_password"): self.bmc_password.blit(display)
    self.bmc_ip.blit(display)
    self.desc2.blit(display)

def uptime():
  with open("/proc/uptime", "r") as f:
    uptime = int(float(f.read().split()[0]))
  return uptime

DisplayState = Enum("DisplayState", ["STARTUP", "WELCOME", "TEXT", "MENU", "STATUS", "SLEEP"])
control_queue = Queue()
display_thread_alive = True
def display_thread():
  try:
    # initialize display
    display = Display()
    display.clear()
    display.flip(force=True)

    # if we are have been booted up for a while there is no need to show the startup screen
    if uptime() > 180:
      display_state = DisplayState.SLEEP
      to_display = SleepScreen()
    else:
      display_state = DisplayState.STARTUP
      to_display = AnimatedText([" .....", ". ....", ".. ...", "... ..", ".... .", "..... "], "sans", bounce=True, x=WIDTH // 2, y=HEIGHT // 2)
    display_last_active = time.monotonic()
    start_time = time.monotonic()
    status_screen = StatusScreen()

    while display_thread_alive:
      st = time.perf_counter()
      if not control_queue.empty():
        command, args = control_queue.get()
        logging.debug(f"Received command {command} with args {args}")
        if command == "text":
          display_state = DisplayState.TEXT
          to_display = Text("\n".join(args), "mono", x=WIDTH // 2, y=HEIGHT // 2)
          start_time = time.monotonic()
        elif command == "atext":
          display_state = DisplayState.TEXT
          to_display = AnimatedText(args, "mono", x=WIDTH // 2, y=HEIGHT // 2)
          start_time = time.monotonic()
        elif command == "menu":
          display_state = DisplayState.MENU
          to_display = Text("\n".join(args), "mono", x=WIDTH // 2, y=HEIGHT // 2)
          start_time = time.monotonic()
        elif command == "status":
          display_state = DisplayState.STATUS
          display_last_active = time.monotonic()
        elif command == "sleep":
          if display_state != DisplayState.SLEEP:
            display_state = DisplayState.SLEEP
            to_display = SleepScreen()
      else:
        # 10 second timeout from startup to sleep
        if time.monotonic() - start_time > 10 and display_state == DisplayState.STARTUP:
          logging.info("Startup timeout, switching states")
          # see if we need to switch to the welcome state
          if os.path.exists("/home/tiny/.before_firstsetup"):
            display_state = DisplayState.WELCOME
            display_last_active = time.monotonic()
            to_display = WelcomeScreen()
          else:
            display_state = DisplayState.SLEEP
            display_last_active = time.monotonic()
            to_display = SleepScreen()

        # reset display state if inactive for 30 seconds
        if time.monotonic() - display_last_active > 30 and display_state == DisplayState.STATUS:
          logging.info("Display inactive for 30 seconds, switching back to sleep state")
          display_state = DisplayState.SLEEP
          display_last_active = time.monotonic()
          to_display = SleepScreen()

        # check if display should be in status state
        gpu_utilizations = get_gpu_utilizations()
        logging.debug(f"GPU Utilizations: {gpu_utilizations}")
        if sum(gpu_utilizations) > 1 and time.monotonic() - start_time > 10 and display_state != DisplayState.MENU and display_state != DisplayState.TEXT and display_state != DisplayState.WELCOME:
          display_state = DisplayState.STATUS
          display_last_active = time.monotonic()

        # if we are in the welcome state, check if we should still be in this state
        if display_state == DisplayState.WELCOME:
          if not os.path.exists("/home/tiny/.before_firstsetup"):
            display_state = DisplayState.SLEEP
            display_last_active = time.monotonic()
            to_display = SleepScreen()

        display.clear()
        if display_state == DisplayState.STARTUP:
          to_display.blit(display)
        elif display_state == DisplayState.WELCOME:
          to_display.blit(display)
        if display_state == DisplayState.TEXT:
          to_display.blit(display)
        elif display_state == DisplayState.MENU:
          to_display.blit(display)
        elif display_state == DisplayState.STATUS:
          status_screen.update(gpu_utilizations, get_gpu_memory_utilizations(), get_cpu_utilizations(), get_gpu_power_draw(), get_cpu_power_draw(), get_disk_io_per_second())
          status_screen.blit(display)
        elif display_state == DisplayState.SLEEP:
          to_display.blit(display)

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
    control_queue.put((command, args))

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
