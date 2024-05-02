import math, os
import serial, pygame

# commands
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
    self.lcd = serial.Serial(port, 115200, timeout=5, write_timeout=5, rtscts=True)
    os.environ["SDL_VIDEODRIVER"] = "dummy"
    pygame.init()
    pygame.font.init()
    self.font_cache = {}
    self.framebuffer = pygame.Surface((WIDTH, HEIGHT), flags=pygame.SRCALPHA)

    # initialize
    self.send_command(OPTIONS, bytearray([0x00, 0x00, 0x00, 0x00]))
    self.send_command(SET_BRIGHTNESS, bytearray([0xff]))
    pygame.draw.rect(self.framebuffer, (0, 0, 0), (0, 0, WIDTH, HEIGHT))
    self.flip()

  def send_command(self, command, payload=None):
    if payload is not None: command += payload
    padding = 0 if command[0] != 0x2c else 0x2c
    if not ((cmd_len:=len(command)) / 250).is_integer(): command += bytearray([padding] * (250 * math.ceil(cmd_len / 250) - cmd_len))
    try: self.lcd.write(command)
    except serial.SerialTimeoutException:
      self.lcd.reset_input_buffer()
      self.lcd.write(command)

  def text(self, text, size, *args, **kwargs):
    if size not in self.font_cache: self.font_cache[size] = pygame.font.Font(None, size)
    return self.font_cache[size].render(text, *args, **kwargs)
  def blit(self, source, dest=(0, 0), area=None): self.framebuffer.blit(source, dest, area)

  def flip(self):
    self.send_command(PRE_UPDATE_BITMAP)
    self.send_command(START_DISPLAY_BITMAP)
    self.send_command(DISPLAY_BITMAP)
    framebuffer = pygame.surfarray.array2d(self.framebuffer).transpose().tobytes()
    self.send_command(bytearray([0xff]), b"\x00".join([framebuffer[i:i+249] for i in range(0, len(framebuffer), 249)]))
    self.lcd.read(1024)
