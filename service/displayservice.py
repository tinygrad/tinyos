from math import e
import sys
sys.path.insert(0, "/opt/tinybox/screen/")

from display import Display
from socketserver import UnixStreamServer, StreamRequestHandler
import threading, time, signal, os
from enum import Enum
from abc import ABC, abstractmethod
from queue import Queue
import pygame as pg

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
      text = display.text(line, 100, True, (255, 255, 255))
      display.blit(text, (400 - text.get_width() // 2, starting_offset + (120 - text.get_height() // 2) + i * 70))

class AText(Displayable):
  def __init__(self, text_states: list[str]): self.text_states, self.current_state = text_states, 0
  def display(self, display: Display):
    text = display.text(self.text_states[self.current_state], 100, True, (255, 255, 255))
    display.blit(text, (400 - text.get_width() // 2, 225 + (120 - text.get_height() // 2)))
    self.current_state = (self.current_state + 1) % len(self.text_states)

DisplayState = Enum("DisplayState", ["TEXT", "STATUS"])
control_queue = Queue()
display_thread_alive = True
def display_thread():
  # initialize display
  display = Display("/dev/ttyACM0")
  display.clear()
  display.flip()

  # load assets
  logo = pg.image.load("/opt/tinybox/screen/logo.png")
  logo = pg.transform.scale(logo, (400, 240))

  display_state = DisplayState.TEXT
  display_last_active = time.monotonic()
  to_display: Displayable | None = None

  while display_thread_alive:
    if not control_queue.empty():
      command, args = control_queue.get()
      print(f"[DT] Received command {command} with args {args}")
      match command:
        case "text":
          display_state = DisplayState.TEXT
          to_display = args
    else:
      # reset display state if inactive for 60 seconds
      if time.monotonic() - display_last_active > 60 and display_state == DisplayState.STATUS:
        print("[DT] Display inactive for 60 seconds, switching back to sleep text state")
        display_state, to_display = DisplayState.TEXT, None
        display_last_active = time.monotonic()

      display.clear()
      match display_state:
        case DisplayState.TEXT:
          display.blit(logo, (200, 25))
          if to_display is not None:
            print(f"[DT] Displaying: {to_display}")
            to_display.display(display)
          else: Text("zZzZz").display(display)
        case DisplayState.STATUS:
          pass

      if display_state == DisplayState.TEXT:
        # check gpu utilization to see if we should switch to status
        pass

    # update display
    display.flip()

    # sleep
    time.sleep(0.5)

class ControlHandler(StreamRequestHandler):
  def handle(self):
    data = self.rfile.readline().strip(b"\r\n").decode()
    command, *args = data.split(",")
    print(f"[CH] Received command {command} with args {args}")
    match command:
      case "text":
        control_queue.put(("text", Text("\n".join(args))))
      case "atext":
        control_queue.put(("text", AText(args)))

if __name__ == "__main__":
  # start display thread
  dt = threading.Thread(target=display_thread)
  dt.start()

  # handle exit signals
  def signal_handler(sig, frame):
    print("[M] Exiting...")
    global display_thread_alive
    display_thread_alive = False
    os.remove("/run/tinybox-screen.sock")
    sys.exit(0)
  signal.signal(signal.SIGINT, signal_handler)
  signal.signal(signal.SIGTERM, signal_handler)

  # start control server
  with UnixStreamServer("/run/tinybox-screen.sock", ControlHandler) as server:
    server.serve_forever()
