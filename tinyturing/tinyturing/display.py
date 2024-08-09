import math, subprocess, time, logging
from pathlib import Path
import serial
from serial.tools.list_ports import comports
import numpy as np
from numba import njit

# commands
HELLO = bytearray([0x01, 0xef, 0x69, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0xc5, 0xd3])
OPTIONS = bytearray([0x7d, 0xef, 0x69, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x2d])
SET_BRIGHTNESS = bytearray([0x7b, 0xef, 0x69, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00])
PRE_UPDATE_BITMAP = bytearray([0x86, 0xef, 0x69, 0x00, 0x00, 0x00, 0x01])
START_DISPLAY_BITMAP = bytearray([0x2c])
DISPLAY_BITMAP = bytearray([0xc8, 0xef, 0x69, 0x00, 0x17, 0x70])
UPDATE_BITMAP = bytes([0xcc, 0xef, 0x69])
QUERY_STATUS = bytearray([0xcf, 0xef, 0x69, 0x00, 0x00, 0x00, 0x01])

WIDTH, HEIGHT = 800, 480
class Display:
  def __init__(self):
    self._connect()

    # initialize display
    self.send_command(HELLO)
    logging.debug(self.lcd.read(22))
    self.send_command(OPTIONS, bytearray([0x00, 0x00, 0x00, 0x00]))
    self.send_command(SET_BRIGHTNESS, bytearray([0xff]))

    self.width, self.height = WIDTH, HEIGHT

    self.font = np.load(Path(__file__).parent / "font.npy")
    self.font_mono = np.load(Path(__file__).parent / "font_mono.npy")
    self.framebuffer = np.full((WIDTH, HEIGHT), 0xff, dtype=np.uint32)
    self.old_framebuffer = self.framebuffer.copy()
    self.update_buffer = np.zeros(self.framebuffer.size * self.framebuffer.itemsize, dtype=np.uint8)
    self.partial_update_count = 0
  def __del__(self): self.lcd.close()

  def _connect(self):
    # auto detect com port
    for port in comports():
      if port.serial_number == "20080411":
        logging.info(f"Found display at {port.device}")
        break
    else:
      logging.error("Display not found")
      raise RuntimeError("Display not found")
    self.lcd = serial.Serial(port.device, 1825200 * 2, timeout=1, write_timeout=1)

  def send_command(self, command, payload=None):
    logging.debug(f"Sending command {command}")
    command = command.copy() if command != bytearray([0xff]) else bytearray()
    if payload is not None: command += payload
    padding = 0 if command[0] != 0x2c else 0x2c
    if not ((cmd_len:=len(command)) / 250).is_integer(): command += bytearray([padding] * (250 * math.ceil(cmd_len / 250) - cmd_len))
    try: self.lcd.write(command)
    except serial.SerialTimeoutException:
      logging.warning("Serial write timeout, resetting usb device and retrying")
      self.lcd.close()
      subprocess.run(["usbreset", "1d6b:0106"])
      logging.warning("Waiting 2 seconds for usb device to reset")
      time.sleep(2)
      self._connect()
      self.lcd.write(command)

  def text(self, text, style="sans"):
    if style == "sans": return _blit_text(text, self.font)
    elif style == "mono": return _blit_text(text, self.font_mono)
    else: raise ValueError("Invalid style")
  def clear(self):
    self.old_framebuffer = self.framebuffer.copy()
    self.framebuffer.fill(0xff)
  def blit(self, source, dest=(0, 0)):
    if source.ndim == 3:
      # check if alpha channel is present
      if source.shape[2] == 4:
        source = (source[:, :, 0].astype(np.uint32) << 24) | (source[:, :, 1].astype(np.uint32) << 16) | (source[:, :, 2].astype(np.uint32) << 8) | (source[:, :, 3].astype(np.uint32) & 0xff)
      else:
        source = (source[:, :, 0].astype(np.uint32) << 24) | (source[:, :, 1].astype(np.uint32) << 16) | (source[:, :, 2].astype(np.uint32) << 8) | 0xff
    # clip source to framebuffer
    if dest[0] >= self.framebuffer.shape[0] or dest[1] >= self.framebuffer.shape[1]: return
    if dest[0] + source.shape[0] > self.framebuffer.shape[0]: source = source[:self.framebuffer.shape[0] - dest[0]]
    if dest[1] + source.shape[1] > self.framebuffer.shape[1]: source = source[:, :self.framebuffer.shape[1] - dest[1]]
    if dest[0] < 0:
      source = source[-dest[0]:]
      dest = (0, dest[1])
    if dest[1] < 0:
      source = source[:, -dest[1]:]
      dest = (dest[0], 0)
    # blit with alpha mixing
    _blit_alpha(source, dest, self.framebuffer)

  def flip(self, force=False):
    dirty = _track_damage(self.old_framebuffer, self.framebuffer)

    if not np.any(dirty) and not force:
      logging.debug("Skipping flip because framebuffer is clean")
      return

    # check if the whole framebuffer is dirty
    if np.all(dirty) or force:
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
      try: res = self.lcd.read(1024)[:0x20]
      except serial.SerialTimeoutException: res = b""
      logging.debug(f"{res}")
      if res == b"\x00" or res == b"" or b"Send:1" in res:
        logging.warning("Partial update failed, full update required")
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

@njit(cache=True)
def _blit_text(text, font):
  # split on newlines
  text_chunks = text.split("\n")
  # the width is the max width
  text_width = max([len(chunk) for chunk in text_chunks]) * 32
  # the height is the number of chunks
  text_height = len(text_chunks) * 64
  # create a surface to blit to
  text_surface = np.zeros((text_width, text_height), dtype=np.uint32)
  # blit each character from the bitmap font
  for y, chunk in enumerate(text_chunks):
    for i, char in enumerate(chunk):
      char_bitmap = font[ord(char) - 32]
      text_surface[i*32:(i+1)*32, y*64:(y+1)*64] = 0xffffff00 | char_bitmap.T
  return text_surface

@njit(cache=True)
def _blit_alpha(source, dest, framebuffer):
  # extract alpha channel
  alpha = source & 0xff
  # blend source with framebuffer using alpha channel
  source = source & 0xffffff00
  fbuf = framebuffer[dest[0]:dest[0]+source.shape[0], dest[1]:dest[1]+source.shape[1]] & 0xffffff00
  framebuffer[dest[0]:dest[0]+source.shape[0], dest[1]:dest[1]+source.shape[1]] = ((fbuf * ((0xff - alpha) / 0xff)).astype(np.uint32)) + (source * (alpha / 0xff)).astype(np.uint32)

@njit(cache=True)
def _track_damage(old:np.ndarray, new:np.ndarray): return np.where(old != new, 1, 0).T

@njit(cache=True)
def _build_update(dirty:np.ndarray, fb, update):
  write = 0
  for y in range(HEIGHT):
    if not np.any(dirty[y]): continue

    # find all dirty segments
    segments = []
    i = 0
    while i < WIDTH:
      if dirty[y][i]:
        segment_start, segment_length = i, 1
        j = i + 1
        while j < WIDTH and dirty[y][j]:
          segment_length += 1
          j += 1
        i = j
        segments.append((segment_start, segment_length))
      i += 1

    for segment in segments:
      if segment[1] > 1:
        update[write:write+3] = np.array([y * WIDTH + segment[0]]).view(np.uint8)[::-1][-3:]
        write += 3
        update[write:write+2] = np.array([segment[1]]).view(np.uint8)[::-1][-2:]
        write += 2
        for x in range(segment[0], segment[0] + segment[1]):
          update[write:write+3] = np.array([fb[x, y]]).view(np.uint8)[-3:]
          write += 3
      else:
        update[write:write+3] = np.array([y * WIDTH + segment[0] + 0x800000]).view(np.uint8)[::-1][-3:]
        write += 3
        update[write:write+3] = np.array([fb[segment[0], y]]).view(np.uint8)[-3:]
        write += 3
  return update[:write]

def _update_payload(dirty:np.ndarray, fb, update_buffer, partial_update_count):
  update = _build_update(dirty, fb, update_buffer).tobytes()
  if len(update) % 249 == 0 or len(update) % 249 == 248 or len(update) % 249 == 247: update = update + b"\x80\x00\x00\x00\x00\x00"
  update_size = (len(update) + 2).to_bytes(4, "big")
  payload = UPDATE_BITMAP + update_size + b"\x00\x00\x00" + partial_update_count.to_bytes(4, "big")
  update_chunks = []
  for i in range(0, len(update), 249): update_chunks.append(update[i:i+249])
  return b"\x00".join(update_chunks) + b"\xef\x69", payload
