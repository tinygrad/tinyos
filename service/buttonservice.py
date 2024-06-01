import evdev
import asyncio, logging, socket, subprocess
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] <%(filename)s:%(lineno)d::%(funcName)s> - %(message)s")

def find_power_button():
  for device in [evdev.InputDevice(fn) for fn in evdev.list_devices()]:
    if "Power Button" in device.name: return device
  raise Exception("power button not found")

in_menu, menu_selection = False, 0
MENU = ["exit", "start llm", "stop llm"]
def update_menu():
  global in_menu, menu_selection

  llm_status = subprocess.run(["systemctl", "is-active", "llmserve"], capture_output=True).stdout.decode().strip() == "active"
  llm_status = " (running)" if llm_status else " (stopped)"

  if in_menu:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
      s.connect("/run/tinybox-screen.sock")
      # build menu text
      # add running status
      menu = [f"{t}{llm_status if 'llm' in t else ''}" for t in MENU]
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

  await asyncio.sleep(0.5)
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
            logging.info("starting llm")
            subprocess.run(["systemctl", "start", "llmserve"])
            update_menu()
          case 2:
            logging.info("stopping llm")
            subprocess.run(["systemctl", "stop", "llmserve"])
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
