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

    pygame.draw.rect(self.framebuffer, (0, 0, 0), (0, 0, WIDTH, HEIGHT))
    self.framebuffer_dirty = [[True] * WIDTH for _ in range(HEIGHT)]
    self.flip()

  def __del__(self): self.lcd.close()

  def send_command(self, command, payload=None):
    print(f"[D] Sending command {command}")
    command = command.copy()
    if payload is not None: command += payload
    padding = 0 if command[0] != 0x2c else 0x2c
    if not ((cmd_len:=len(command)) / 250).is_integer(): command += bytearray([padding] * (250 * math.ceil(cmd_len / 250) - cmd_len))
    try: self.lcd.write(command)
    except serial.SerialTimeoutException:
      print("[D] Serial write timeout, resetting usb device and retrying")
      port, baudrate = self.lcd.port, self.lcd.baudrate
      self.lcd.close()
      time.sleep(1)
      subprocess.run(["usbreset", "1d6b:0106"])
      print("[D] Waiting 5 seconds for usb device to reset")
      time.sleep(5)
      self.lcd = serial.Serial(port, baudrate, timeout=5, write_timeout=5)
      self.lcd.write(command)

  def text(self, text, size, *args, **kwargs):
    if size not in self.font_cache: self.font_cache[size] = pygame.font.Font(None, size)
    return self.font_cache[size].render(text, *args, **kwargs)
  def blit(self, source, dest=(0, 0), area=None):
    print(f"[D] Blitting {source.get_width()}x{source.get_height()} image at {dest} with area {area}")
    old_framebuffer = self.framebuffer.copy()
    self.framebuffer.blit(source, dest, area)
    for x in range(WIDTH):
      for y in range(HEIGHT):
        if self.framebuffer.get_at((x, y)) != old_framebuffer.get_at((x, y)):
          self.framebuffer_dirty[y][x] = True
  def clear(self):
    pygame.draw.rect(self.framebuffer, (0, 0, 0), (0, 0, WIDTH, HEIGHT))
    self.framebuffer_dirty = [[True] * WIDTH for _ in range(HEIGHT)]

  def flip(self):
    if not any(any(row) for row in self.framebuffer_dirty):
      print("[D] Skipping flip because framebuffer is clean")
      return
    print("[D] Flipping framebuffer")
    self.send_command(PRE_UPDATE_BITMAP)
    self.send_command(START_DISPLAY_BITMAP)
    self.send_command(DISPLAY_BITMAP)
    framebuffer = pygame.surfarray.array2d(self.framebuffer).transpose().tobytes()
    self.send_command(bytearray([0xff]), b"\x00".join([framebuffer[i:i+249] for i in range(0, len(framebuffer), 249)]))
    print(f"[D] {self.lcd.read(1024)[:0x20]}")
    self.framebuffer_dirty = [[False] * WIDTH for _ in range(HEIGHT)]
