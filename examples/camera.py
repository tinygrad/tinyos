import logging, time
logging.basicConfig(level=logging.INFO)

from tinyturing.display import Display, WIDTH, HEIGHT
import cv2

# initialize
display = Display()
display.clear()
display.flip(force=True)

video = cv2.VideoCapture(1)

while True:
  st = time.perf_counter()
  display.clear()

  ret, frame = video.read()
  frame = cv2.resize(frame, (160, 90))
  frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

  np_frame = frame.transpose(1, 0, 2)
  display.blit(np_frame, ((WIDTH - frame.shape[1]) // 2, (HEIGHT - frame.shape[0]) // 2))

  display.flip()
  flip_time = time.perf_counter() - st

  if (sleep_time := 0.03 - flip_time) > 0: time.sleep(sleep_time)
