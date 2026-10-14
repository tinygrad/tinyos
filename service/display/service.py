import sys
sys.path.insert(0, "/opt/tinybox/tinyturing/")
sys.path.insert(0, "/opt/tinybox/service/display/")

from socketserver import UnixStreamServer, StreamRequestHandler
import threading, time, signal, os, logging, subprocess, socket
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] <%(filename)s:%(lineno)d::%(funcName)s> - %(message)s")
from enum import Enum
from queue import Queue

from tinyturing.display import Display, WIDTH, HEIGHT
from tinyturing.components import Text, AnimatedText
from tinyturing.screens import StatusScreen, SleepScreen, WelcomeScreen
from stats import Stats

def read_bmc_password():
  # read bmc password from /root/.bmc_password
  if not os.path.exists("/root/.bmc_password"):
    logging.warning("BMC password file not found")
    return None
  try:
    with open("/root/.bmc_password", "r") as f:
      return f.read().strip().split("=")[1].strip()
  except:
    logging.warning("Failed to read BMC password")
    return None

def get_bmc_ip():
  bmc_lan_info = subprocess.run(["ipmitool", "lan", "print"], capture_output=True).stdout.decode().split("\n")
  return next((line.split()[3] for line in bmc_lan_info if "IP Address  " in line), "N/A")

def get_local_ip():
  try:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(("10.254.254.254", 1))
    return s.getsockname()[0]
  except:
    logging.warning("Failed to get local IP address")
    return "N/A"

def make_sleep_screen():
  return SleepScreen("/opt/tinybox/service/display/logo.png", read_bmc_password(), get_bmc_ip(), get_local_ip())

def make_welcome_screen():
  bmc_password = read_bmc_password()
  if bmc_password is not None:
    # try setting the bmc password
    try: subprocess.run(["ipmitool", "user", "set", "password", "2", bmc_password])
    except: logging.warning("Failed to set BMC password")
  return WelcomeScreen("/opt/tinybox/service/display/docs_qr.png", bmc_password, get_bmc_ip())

def uptime():
  with open("/proc/uptime", "r") as f:
    uptime = int(float(f.read().split()[0]))
  return uptime

DisplayState = Enum("DisplayState", ["STARTUP", "WELCOME", "TEXT", "MENU", "STATUS", "SLEEP"])
control_queue = Queue()
display_up_event = threading.Event()
display_thread_alive = True
def display_thread():
  # initialize display
  while True:
    try:
      display = Display()
      break
    except Exception as e:
      logging.warning(f"Failed to initialize display: {e}")
      time.sleep(1)

  try:
    display.clear()
    display.flip(force=True)

    display_up_event.set()

    # if we are have been booted up for a while there is no need to show the startup screen
    if uptime() > 180:
      # see if we need to switch to the welcome state
      if os.path.exists("/home/tiny/.before_firstsetup"):
        display_state = DisplayState.WELCOME
        to_display = make_welcome_screen()
      else:
        display_state = DisplayState.SLEEP
        to_display = make_sleep_screen()
    else:
      display_state = DisplayState.STARTUP
      to_display = AnimatedText([" .....", ". ....", ".. ...", "... ..", ".... .", "..... "], "sans", bounce=True, x=WIDTH // 2, y=HEIGHT // 2)
    display_last_active = time.monotonic()
    start_time = time.monotonic()

    stats = Stats()
    status_screen = StatusScreen(stats.gpu.get_gpu_count())

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
          if display_state != DisplayState.WELCOME:
            display_state = DisplayState.STATUS
            display_last_active = time.monotonic()
        elif command == "sleep":
          # see if we need to switch to the welcome state
          if os.path.exists("/home/tiny/.before_firstsetup"):
            if display_state != DisplayState.WELCOME:
              display_state = DisplayState.WELCOME
              to_display = make_welcome_screen()
          else:
            if display_state != DisplayState.SLEEP:
              display_state = DisplayState.SLEEP
              to_display = make_sleep_screen()
      else:
        # 10 second timeout from startup to sleep
        if time.monotonic() - start_time > 10 and display_state == DisplayState.STARTUP:
          logging.info("Startup timeout, switching states")
          # see if we need to switch to the welcome state
          if os.path.exists("/home/tiny/.before_firstsetup"):
            display_state = DisplayState.WELCOME
            display_last_active = time.monotonic()
            to_display = make_welcome_screen()
          else:
            display_state = DisplayState.SLEEP
            display_last_active = time.monotonic()
            to_display = make_sleep_screen()

        # reset display state if inactive for 30 seconds
        if time.monotonic() - display_last_active > 30 and display_state == DisplayState.STATUS:
          logging.info("Display inactive for 30 seconds, switching back to sleep state")
          display_state = DisplayState.SLEEP
          display_last_active = time.monotonic()
          to_display = make_sleep_screen()

        # check if display should be in status state
        gpu_utilizations = stats.gpu.get_gpu_utilizations()
        cpu_utilizations = stats.get_cpu_utilizations()
        logging.debug(f"GPU Utilizations: {gpu_utilizations}")
        mean_cpu_utilization = sum(cpu_utilizations) / len(cpu_utilizations)
        if (sum(gpu_utilizations) > 1 or mean_cpu_utilization > 50) and time.monotonic() - start_time > 10 and display_state != DisplayState.MENU and display_state != DisplayState.TEXT and display_state != DisplayState.WELCOME:
          display_state = DisplayState.STATUS
          display_last_active = time.monotonic()

        # if we are in the welcome state, check if we should still be in this state
        if display_state == DisplayState.WELCOME:
          if not os.path.exists("/home/tiny/.before_firstsetup"):
            display_state = DisplayState.SLEEP
            display_last_active = time.monotonic()
            to_display = make_sleep_screen()

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
          if stats.gpu.get_gpu_count() != status_screen.gpu_count:
            status_screen = StatusScreen(stats.gpu.get_gpu_count())

          status_screen.update(
            gpu_utilizations,
            stats.gpu.get_gpu_memory_utilizations(),
            cpu_utilizations,
            stats.gpu.get_gpu_power_draw(),
            stats.get_cpu_power_draw(),
            stats.get_disk_io_per_second()
          )
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

  # wait for display thread to be ready
  while not display_up_event.is_set():
    time.sleep(0.1)

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
