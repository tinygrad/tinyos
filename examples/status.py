import logging, time, random, math
logging.basicConfig(level=logging.INFO)

from pathlib import Path

from tinyturing.display import Display, WIDTH, HEIGHT
from tinyturing.components import Anchor, ComponentParent, Component
from tinyturing.components import Text, HorizontalProgressBar, VerticalProgressBar, Rectangle, LineGraph

# initialize
display = Display()
display.clear()
display.flip(force=True)

display.clear()

class StatusScreen(Component):
  def __init__(self, gpu_count:int):
    gpu_bars_space = (6 - gpu_count) * 64
    self.gpu_bars = [VerticalProgressBar(50, 430, x=30 + 64 * i, y=HEIGHT // 2) for i in range(gpu_count)]
    self.gpu_mem_bars = [HorizontalProgressBar(160, 5, x=425 - gpu_bars_space, y=100 + 7 * i, anchor=Anchor.MIDDLE_LEFT) for i in range(gpu_count)]
    self.gpu_mem_bar_backgrounds = [Rectangle(160, 5, color=0x323232ff, x=425 - gpu_bars_space, y=100 + 7 * i, anchor=Anchor.MIDDLE_LEFT) for i in range(gpu_count)]

    self.vertical_separator = Rectangle(1, 280, x=WIDTH // 2 - gpu_bars_space, y=HEIGHT // 2)
    self.horizontal_separator = Rectangle(280 + gpu_bars_space, 1, x=WIDTH // 2 + WIDTH // 4  - gpu_bars_space // 2, y=HEIGHT // 2)

    bar_width = (6 - gpu_count) + 2
    self.cpu_bars = [VerticalProgressBar(bar_width, 117, x=604 + (bar_width + 1) * i - gpu_bars_space, y=84) for i in range(64)]

    self.rolling_power_draw = 0
    self.power_draw_text = Text("0W", style="mono", x=425 - gpu_bars_space, y=57, anchor=Anchor.MIDDLE_LEFT)
    self.rolling_disk_io = 0
    self.disk_io_text = Text("0MB/s", style="mono", x=WIDTH - 5, y=190, anchor=Anchor.MIDDLE_RIGHT)

    self.line_graph = LineGraph(370 + gpu_bars_space, 190, x=610 - gpu_bars_space // 2, y=360)

  def update(self, gpu_utilizations: list[float], gpu_memory_utilizations: list[float], cpu_utilizations: list[float], gpu_power_draws: list[float], cpu_power_draw: float, disk_io: tuple[int, int]):
    for i, bar in enumerate(self.gpu_bars): bar.value = gpu_utilizations[i]
    for i, bar in enumerate(self.gpu_mem_bars): bar.value = gpu_memory_utilizations[i]
    for i, bar in enumerate(self.cpu_bars): bar.value = cpu_utilizations[i]

    self.rolling_power_draw = math.floor(0.8 * self.rolling_power_draw + 0.2 * sum(gpu_power_draws, cpu_power_draw))
    self.power_draw_text.text = f"{self.rolling_power_draw}W"

    self.rolling_disk_io = math.floor(0.8 * self.rolling_disk_io + 0.2 * sum(disk_io))
    self.disk_io_text.text = f"{self.rolling_disk_io}MB/s"

    self.line_graph.add_data(self.rolling_power_draw)

  def blit(self, display:Display):
    for bar in self.gpu_bars: bar.blit(display)
    for bar in self.gpu_mem_bar_backgrounds: bar.blit(display)
    for bar in self.gpu_mem_bars: bar.blit(display)
    self.vertical_separator.blit(display)
    self.horizontal_separator.blit(display)
    for bar in self.cpu_bars: bar.blit(display)
    self.power_draw_text.blit(display)
    self.disk_io_text.blit(display)
    self.line_graph.blit(display)

status_screen = StatusScreen(4)

while True:
  display.clear()
  status_screen.update(
    [random.uniform(50, 100) for _ in range(6)],
    [random.uniform(50, 100) for _ in range(6)],
    [random.uniform(90, 100) for _ in range(64)],
    [random.uniform(50, 450) for _ in range(6)],
    random.uniform(50, 300),
    (random.randint(0, 10000), random.randint(0, 10000))
  )
  status_screen.blit(display)
  display.flip()

  time.sleep(0.01)
