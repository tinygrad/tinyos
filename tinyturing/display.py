import math, subprocess, time, logging
import serial
import numpy as np
from numba import njit

# commands
HELLO = bytearray([0x01, 0xef, 0x69, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0xc5, 0xd3])
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
    logging.debug(self.lcd.read(22))
    self.send_command(OPTIONS, bytearray([0x00, 0x00, 0x00, 0x00]))
    self.send_command(SET_BRIGHTNESS, bytearray([0xff]))

    self.font = np.load("/opt/tinybox/screen/font.npy")
    self.framebuffer = np.zeros((WIDTH, HEIGHT), dtype=np.uint32)
    self.old_framebuffer = self.framebuffer.copy()
    self.update_buffer = np.zeros(self.framebuffer.size, dtype=np.uint8)
    self.partial_update_count = 0

  def __del__(self): self.lcd.close()

  def send_command(self, command, payload=None):
    logging.debug(f"Sending command {command}")
    command = command.copy() if command != bytearray([0xff]) else bytearray()
    if payload is not None: command += payload
    padding = 0 if command[0] != 0x2c else 0x2c
    if not ((cmd_len:=len(command)) / 250).is_integer(): command += bytearray([padding] * (250 * math.ceil(cmd_len / 250) - cmd_len))
    try: self.lcd.write(command)
    except serial.SerialTimeoutException:
      logging.warning("Serial write timeout, resetting usb device and retrying")
      port, baudrate = self.lcd.port, self.lcd.baudrate
      self.lcd.close()
      subprocess.run(["usbreset", "1d6b:0106"])
      logging.warning("Waiting 5 seconds for usb device to reset")
      time.sleep(5)
      self.lcd = serial.Serial(port, baudrate, timeout=5, write_timeout=5)
      self.lcd.write(command)

  def text(self, text): return _blit_text(text, self.font)
  def clear(self):
    self.old_framebuffer = self.framebuffer.copy()
    self.framebuffer.fill(0)
  def blit(self, source, dest=(0, 0)):
    if source.ndim == 3: source = (source[:, :, 0].astype(np.uint32) << 24) | (source[:, :, 1].astype(np.uint32) << 16) | (source[:, :, 2].astype(np.uint32) << 8) | 0xff
    self.framebuffer[dest[0]:dest[0]+source.shape[0], dest[1]:dest[1]+source.shape[1]] = source

  def flip(self):
    dirty = _track_damage(self.old_framebuffer, self.framebuffer)

    if not np.any(dirty):
      logging.debug("Skipping flip because framebuffer is clean")
      return

    # check if the whole framebuffer is dirty
    if np.all(dirty):
      logging.debug("Flipping full framebuffer")
      self.send_command(PRE_UPDATE_BITMAP)
      self.send_command(START_DISPLAY_BITMAP)
      self.send_command(DISPLAY_BITMAP)
      framebuffer = self.framebuffer.transpose().tobytes()
      self.send_command(bytearray([0xff]), b"\x00".join([framebuffer[i:i+249] for i in range(0, len(framebuffer), 249)]))
      logging.debug(f"{self.lcd.read(1024)[:0x20]}")
      self.send_command(QUERY_STATUS)
      logging.debug(f"{self.lcd.read(1024)[:0x20]}")
    else:
      logging.debug("Flipping partial framebuffer")
      update, payload = _update_payload(dirty, self.framebuffer, self.update_buffer, self.partial_update_count)

      self.send_command(bytearray([0xff]), payload)
      self.send_command(bytearray([0xff]), update)
      self.send_command(QUERY_STATUS)
      res = self.lcd.read(1024)[:0x20]
      logging.debug(f"{res}")
      if res == b"\x00" or res == b"" or b"Send:1" in res:
        logging.debug("Partial update failed, full update required")
        self.send_command(PRE_UPDATE_BITMAP)
        self.send_command(START_DISPLAY_BITMAP)
        self.send_command(DISPLAY_BITMAP)
        framebuffer = self.framebuffer.transpose().tobytes()
        self.send_command(bytearray([0xff]), b"\x00".join([framebuffer[i:i+249] for i in range(0, len(framebuffer), 249)]))
        logging.debug(f"{self.lcd.read(1024)[:0x20]}")
        self.send_command(QUERY_STATUS)
        logging.debug(f"{self.lcd.read(1024)[:0x20]}")
        self.partial_update_count = 0
      else:
        self.partial_update_count += 1

@njit
def _blit_text(text, font):
  text_width = len(text) * 32
  text_height = 64
  text_surface = np.zeros((text_width, text_height), dtype=np.uint32)
  for i, char in enumerate(text):
    char_bitmap = font[ord(char) - 32]
    text_surface[i*32:(i+1)*32, :64] = char_bitmap.T * 0xffffffff
  return text_surface

@njit
def _track_damage(old:np.ndarray, new:np.ndarray): return np.where(old != new, 1, 0).T

@njit
def _build_update(dirty:np.ndarray, fb, update):
  write = 0
  for y in range(HEIGHT):
    if not np.any(dirty[y]): continue
    start = 0
    while not dirty[y][start]: start += 1
    end = WIDTH - 1
    while not dirty[y][end]: end -= 1
    update[write:write+3] = np.array([y * WIDTH + start]).view(np.uint8)[::-1][-3:]
    write += 3
    update[write:write+2] = np.array([end - start + 1]).view(np.uint8)[::-1][-2:]
    write += 2
    for x in range(start, end + 1):
      update[write:write+3] = np.array([fb[x, y]]).view(np.uint8)[-3:]
      write += 3
  return update[:write]

def _update_payload(dirty:np.ndarray, fb, update_buffer, partial_update_count):
  update = _build_update(dirty, fb, update_buffer).tobytes()
  update_size = (len(update) + 2).to_bytes(3, "big")
  payload = UPDATE_BITMAP + update_size + b"\x00\x00\x00" + partial_update_count.to_bytes(4, "big")
  update_chunks = []
  for i in range(0, len(update), 249): update_chunks.append(update[i:i+249])
  return b"\x00".join(update_chunks) + b"\xef\x69", payload
