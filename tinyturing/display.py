import math, os, subprocess, time
os.environ['PYGAME_HIDE_SUPPORT_PROMPT'] = "hide"
import serial, pygame

# commands
HELLO = bytearray([0x01, 0xef, 0x69, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0xc5, 0xd3])
RESTART = bytearray([0x84, 0xef, 0x69, 0x00, 0x00, 0x00, 0x01])
OPTIONS = bytearray([0x7d, 0xef, 0x69, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x2d])
SET_BRIGHTNESS = bytearray([0x7b, 0xef, 0x69, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00])
PRE_UPDATE_BITMAP = bytearray([0x86, 0xef, 0x69, 0x00, 0x00, 0x00, 0x01])
START_DISPLAY_BITMAP = bytearray([0x2c])
DISPLAY_BITMAP = bytearray([0xc8, 0xef, 0x69, 0x00, 0x17, 0x70])
UPDATE_BITMAP = bytearray([0xcc, 0xef, 0x69, 0x00])
QUERY_STATUS = bytearray([0xcf, 0xef, 0x69, 0x00, 0x00, 0x00, 0x01])

WIDTH, HEIGHT = 800, 480
class Display:
  def __init__(self, port):
    self.lcd = serial.Serial(port, 115200, timeout=5, write_timeout=5)

    # initialize display
    self.send_command(HELLO)
    print(self.lcd.read(22))
    self.send_command(OPTIONS, bytearray([0x00, 0x00, 0x00, 0x00]))
    self.send_command(SET_BRIGHTNESS, bytearray([0xff]))

    # initialize pygame
    os.environ["SDL_VIDEODRIVER"] = "dummy"
    pygame.init()
    pygame.font.init()
    self.font_cache = {}
    self.framebuffer = pygame.Surface((WIDTH, HEIGHT), flags=pygame.SRCALPHA)
    self.old_framebuffer = self.framebuffer.copy()
    self.framebuffer_dirty = [[True] * WIDTH for _ in range(HEIGHT)]
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
    # track damage
    old_framebuffer = pygame.PixelArray(self.old_framebuffer)
    framebuffer = pygame.PixelArray(self.framebuffer)
    for x in range(WIDTH):
      for y in range(HEIGHT):
        pixel_old = old_framebuffer[x, y]
        pixel_new = framebuffer[x, y]
        if pixel_old == pixel_new: self.framebuffer_dirty[y][x] = False
        else: self.framebuffer_dirty[y][x] = True
    old_framebuffer.close()
    framebuffer.close()

    if not any(any(row) for row in self.framebuffer_dirty):
      print("[D] Skipping flip because framebuffer is clean")
      return

    # check if the whole framebuffer is dirty
    if all(all(row) for row in self.framebuffer_dirty):
      print("[D] Flipping full framebuffer")
      self.send_command(PRE_UPDATE_BITMAP)
      self.send_command(START_DISPLAY_BITMAP)
      self.send_command(DISPLAY_BITMAP)
      framebuffer = pygame.surfarray.array2d(self.framebuffer).transpose().tobytes()
      self.send_command(bytearray([0xff]), b"\x00".join([framebuffer[i:i+249] for i in range(0, len(framebuffer), 249)]))
      print(f"[D] {self.lcd.read(1024)[:0x20]}")
      self.send_command(QUERY_STATUS)
      print(f"[D] {self.lcd.read(1024)[:0x20]}")
    else:
      print("[D] Flipping partial framebuffer")
      update = ""
      for y in range(HEIGHT):
        if not any(self.framebuffer_dirty[y]): continue
        update += f"{(y * WIDTH):06x}{WIDTH:04x}"
        for x in range(WIDTH):
          pixel = self.framebuffer.get_at((x, y))
          update += f"{pixel[2]:02x}{pixel[1]:02x}{pixel[0]:02x}"
      update_size = f"{int((len(update) / 2) + 2):06x}"
      payload = UPDATE_BITMAP + bytearray.fromhex(update_size) + bytearray(3) + self.partial_update_count.to_bytes(4, "big")
      if len(update) > 500: update = "00".join(update[i:i + 498] for i in range(0, len(update), 498))
      update += "ef69"

      self.send_command(bytearray([0xff]), payload)
      self.send_command(bytearray([0xff]), bytearray.fromhex(update))
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
