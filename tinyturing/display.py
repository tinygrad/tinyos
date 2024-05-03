import math, os, subprocess, time
os.environ['PYGAME_HIDE_SUPPORT_PROMPT'] = "hide"
import serial, pygame
import numpy as np
from numba import njit

# commands
HELLO = bytearray([0x01, 0xef, 0x69, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0xc5, 0xd3])
RESTART = bytearray([0x84, 0xef, 0x69, 0x00, 0x00, 0x00, 0x01])
OPTIONS = bytearray([0x7d, 0xef, 0x69, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x2d])
SET_BRIGHTNESS = bytearray([0x7b, 0xef, 0x69, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00])
PRE_UPDATE_BITMAP = bytearray([0x86, 0xef, 0x69, 0x00, 0x00, 0x00, 0x01])
START_DISPLAY_BITMAP = bytearray([0x2c])
DISPLAY_BITMAP = bytearray([0xc8, 0xef, 0x69, 0x00, 0x17, 0x70])
UPDATE_BITMAP = bytes([0xcc, 0xef, 0x69, 0x00])
QUERY_STATUS = bytearray([0xcf, 0xef, 0x69, 0x00, 0x00, 0x00, 0x01])

WIDTH, HEIGHT = 800, 480
class Display:
  def __init__(self, port):
    self.lcd = serial.Serial(port, 1825200, timeout=5, write_timeout=5)

    # initialize display
    self.send_command(HELLO)
    print(self.lcd.read(22))
    self.send_command(OPTIONS, bytearray([0x00, 0x00, 0x00, 0x00]))
    self.send_command(SET_BRIGHTNESS, bytearray([0xff]))

    # initialize pygame
    os.environ["SDL_VIDEODRIVER"] = "dummy"
    pygame.font.init()
    self.font_cache = {}
    self.framebuffer = pygame.Surface((WIDTH, HEIGHT), flags=pygame.SRCALPHA)
    self.old_framebuffer = self.framebuffer.copy()
    self.partial_update_count = 0

  def __del__(self): self.lcd.close()

  def send_command(self, command, payload=None):
    print(f"[D] Sending command {command}")
    command = command.copy() if command != bytearray([0xff]) else bytearray()
    if payload is not None: command += payload
    padding = 0 if command[0] != 0x2c else 0x2c
    if not ((cmd_len:=len(command)) / 250).is_integer(): command += bytearray([padding] * (250 * math.ceil(cmd_len / 250) - cmd_len))
    try: self.lcd.write(command)
    except serial.SerialTimeoutException:
      print("[D] Serial write timeout, resetting usb device and retrying")
      port, baudrate = self.lcd.port, self.lcd.baudrate
      self.lcd.close()
      subprocess.run(["usbreset", "1d6b:0106"])
      print("[D] Waiting 5 seconds for usb device to reset")
      time.sleep(5)
      self.lcd = serial.Serial(port, baudrate, timeout=5, write_timeout=5)
      self.lcd.write(command)

  def text(self, text, size, *args, **kwargs):
    if size not in self.font_cache: self.font_cache[size] = pygame.font.Font(None, size)
    return self.font_cache[size].render(text, *args, **kwargs)
  def clear(self):
    self.old_framebuffer = self.framebuffer.copy()
    pygame.draw.rect(self.framebuffer, (0, 0, 0), (0, 0, WIDTH, HEIGHT))
  def blit(self, source, dest=(0, 0), area=None):
    print(f"[D] Blitting {source.get_width()}x{source.get_height()} image at {dest} with area {area}")
    self.framebuffer.blit(source, dest, area)

  def flip(self):
    dirty = _track_damage(pygame.surfarray.pixels2d(self.old_framebuffer), pygame.surfarray.pixels2d(self.framebuffer))

    if not np.any(dirty):
      print("[D] Skipping flip because framebuffer is clean")
      return

    # check if the whole framebuffer is dirty
    if np.all(dirty):
      print("[D] Flipping full framebuffer")
      self.send_command(PRE_UPDATE_BITMAP)
      self.send_command(START_DISPLAY_BITMAP)
      self.send_command(DISPLAY_BITMAP)
      framebuffer = pygame.surfarray.pixels2d(self.framebuffer).transpose().tobytes()
      self.send_command(bytearray([0xff]), b"\x00".join([framebuffer[i:i+249] for i in range(0, len(framebuffer), 249)]))
      print(f"[D] {self.lcd.read(1024)[:0x20]}")
      self.send_command(QUERY_STATUS)
      print(f"[D] {self.lcd.read(1024)[:0x20]}")
    else:
      print("[D] Flipping partial framebuffer")
      update, payload = _update_payload(dirty, pygame.PixelArray(self.framebuffer), self.partial_update_count)

      self.send_command(bytearray([0xff]), payload)
      self.send_command(bytearray([0xff]), update)
      self.send_command(QUERY_STATUS)
      res = self.lcd.read(1024)[:0x20]
      print(f"[D] {res}")
      if res == b"\x00" or res == b"" or b"Send:1" in res:
        print("[D] Partial update failed, full update required")
        self.send_command(PRE_UPDATE_BITMAP)
        self.send_command(START_DISPLAY_BITMAP)
        self.send_command(DISPLAY_BITMAP)
        framebuffer = pygame.surfarray.array2d(self.framebuffer).transpose().tobytes()
        self.send_command(bytearray([0xff]), b"\x00".join([framebuffer[i:i+249] for i in range(0, len(framebuffer), 249)]))
        print(f"[D] {self.lcd.read(1024)[:0x20]}")
        self.send_command(QUERY_STATUS)
        print(f"[D] {self.lcd.read(1024)[:0x20]}")
        self.partial_update_count = 0
      else:
        self.partial_update_count += 1
    self.framebuffer_dirty = [[False] * WIDTH for _ in range(HEIGHT)]

@njit
def _track_damage(old:np.ndarray, new:np.ndarray): return np.where(old != new, 1, 0).T

def _update_payload(dirty:np.ndarray, fb, partial_update_count):
  update = bytearray()
  for y in range(HEIGHT):
    if not np.any(dirty[y]): continue
    # find first dirty pixel
    start = 0
    while not dirty[y][start]: start += 1
    # find last dirty pixel
    end = WIDTH - 1
    while not dirty[y][end]: end -= 1
    update += (y * WIDTH + start).to_bytes(3, "big") + (end - start + 1).to_bytes(2, "big")
    for x in range(start, end + 1):
      pixel = fb[x, y]
      update += (pixel & 0xffffff).to_bytes(3, "little")
  update_size = (len(update) + 2).to_bytes(3, "big")
  payload = UPDATE_BITMAP + update_size + b"\x00\x00\x00" + partial_update_count.to_bytes(4, "big")
  update_chunks = []
  for i in range(0, len(update), 249): update_chunks.append(update[i:i+249])
  return b"\x00".join(update_chunks) + b"\xef\x69", payload
