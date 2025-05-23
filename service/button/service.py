import evdev
import asyncio, logging, socket, subprocess
from pathlib import Path
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] <%(filename)s:%(lineno)d::%(funcName)s> - %(message)s")

def find_power_button():
  for device in [evdev.InputDevice(fn) for fn in evdev.list_devices()]:
    if "Power Button" in device.name: return device
  raise Exception("power button not found")

in_menu, menu_selection = False, 0
MENU = ["exit", "update", "setup", "force setup", "force stress", "skip provision"]
def update_menu():
  global in_menu, menu_selection

  if in_menu:
    hostname = subprocess.run(["hostname"], capture_output=True).stdout.decode().strip()
    so = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    so.connect(("10.254.254.254", 1))
    ip = so.getsockname()[0]

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
      s.connect("/run/tinybox-screen.sock")
      # build menu text
      menu = [item if item != "exit" else f"{item} ({hostname})" for item in MENU]
      menu = [item if item != "update" else f"{item} ({ip})" for item in menu]
      # add selection marker
      menu = ",".join(f"{'> ' if i == menu_selection else ''}{item}" for i, item in enumerate(menu))
      s.sendall(f"menu,{menu}".encode())
  else:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
      s.connect("/run/tinybox-screen.sock")
      s.sendall(b"sleep")

async def menu_timeout():
  global in_menu, menu_selection
  await asyncio.sleep(8)
  if in_menu:
    logging.info("menu timeout")
    in_menu = False
    update_menu()

timeout_task = None
async def power_button_pressed(count: int):
  global in_menu, menu_selection, timeout_task

  await asyncio.sleep(0.6)
  logging.info(f"pressed {count} times")

  # reset menu timeout
  if in_menu:
    if timeout_task: timeout_task.cancel()
    timeout_task = asyncio.create_task(menu_timeout())

  match count:
    case 1:
      if not in_menu:
        logging.info("powering off")
        subprocess.run(["systemctl", "poweroff"])
      else:
        menu_selection = (menu_selection + 1) % len(MENU)
        update_menu()
    case 2:
      if not in_menu:
        logging.info("switching to status")
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
          s.connect("/run/tinybox-screen.sock")
          s.sendall(b"status")
      else:
        match menu_selection:
          case 0:
            logging.info("exiting menu")
            in_menu = False
            update_menu()
          case 1:
            logging.info("updating")
            subprocess.run(["systemctl", "start", "autoupdate-tinybox"])
            in_menu = False
            update_menu()
          case 2:
            logging.info("running setup")
            subprocess.run(["systemctl", "start", "tinybox-setup"])
            in_menu = False
            update_menu()
          case 3:
            logging.info("forcing setup")
            Path("/tmp/force_setup").touch()
            subprocess.run(["systemctl", "start", "tinybox-setup"])
            in_menu = False
            update_menu()
          case 4:
            logging.info("forcing stress")
            Path("/tmp/force_resnet_train").touch()
            in_menu = False
            update_menu()
          case 5:
            logging.info("skipping provision")
            with open("/etc/tinybox-setup-stage", "w") as f:
              f.write("01001")
            subprocess.run(["systemctl", "start", "tinybox-setup"])
            in_menu = False
            update_menu()
    case 3:
      logging.info("entering menu")
      menu_selection = 0
      in_menu = True
      update_menu()

async def main():
  device = find_power_button()
  logging.info(f"found at {device.path}")

  pressed_count, pressed_task = 0, None
  with device.grab_context():
    async for event in device.async_read_loop():
      if event.value == 1:
        if pressed_task:
          if not pressed_task.cancel(): pressed_count = 0
        pressed_task = asyncio.create_task(power_button_pressed(pressed_count := pressed_count + 1))

asyncio.run(main())
