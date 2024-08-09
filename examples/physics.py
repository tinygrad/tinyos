from tinyturing.display import Display, WIDTH, HEIGHT
from PIL import Image
import numpy as np
import logging, time, math, random
from pathlib import Path
import pymunk
logging.basicConfig(level=logging.INFO)

# initialize
display = Display()
display.clear()
display.flip(force=True)

space = pymunk.Space()
space.gravity = 0, 981

tracked_logos = []
def spawn_logo():
  logo = Image.open(Path(__file__).parent / "logo.png").convert("RGBA")
  logo = logo.resize((50, 19))
  logo_body = pymunk.Body(1, pymunk.moment_for_box(1, logo.size))
  logo_shape = pymunk.Poly.create_box(logo_body, logo.size)
  logo_shape.friction = 0.5
  logo_body.position = WIDTH // 4, random.randint(-HEIGHT, 0)
  space.add(logo_body, logo_shape)
  tracked_logos.append((logo, logo_body))

floor = Image.new("RGBA", (WIDTH, 10), (255, 255, 255, 255))
floor_body = pymunk.Body(body_type=pymunk.Body.STATIC)
floor_shape = pymunk.Poly.create_box(floor_body, (WIDTH, 10))
floor_shape.friction = 0.5
floor_body.position = 0, HEIGHT - 5
space.add(floor_body, floor_shape)

for i in range(150):
  spawn_logo()

while True:
  st = time.perf_counter()
  display.clear()

  space.step(0.01)

  for logo, logo_body in tracked_logos:
    if logo_body.position.y > HEIGHT + 200:
      logo_body.position = WIDTH // 4, 0
      logo_body.velocity = 0, 0

    logo_rotated = logo.rotate(-math.degrees(logo_body.angle), resample=Image.BICUBIC, expand=True)
    np_logo = np.array(logo_rotated).transpose(1, 0, 2)
    display.blit(np_logo, (int(logo_body.position.x) - logo_rotated.size[0] // 2, int(logo_body.position.y) - logo_rotated.size[1] // 2))

  np_floor = np.array(floor).transpose(1, 0, 2)
  display.blit(np_floor, (int(floor_body.position.x) - WIDTH // 2, int(floor_body.position.y) - 5))

  display.flip()
  flip_time = time.perf_counter() - st

  if (sleep_time := 0.05 - flip_time) > 0: time.sleep(sleep_time)
