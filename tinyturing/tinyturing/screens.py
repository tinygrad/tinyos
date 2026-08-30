import math

from tinyturing.display import Display, WIDTH, HEIGHT
from tinyturing.components import Anchor, Component, ComponentParent
from tinyturing.components import Text, Image, MultiCollidingDVDImage, Rectangle, LineGraph, VerticalProgressBar, HorizontalProgressBar

class StatusScreen(Component):
  def __init__(self, gpu_count:int):
    self.gpu_count = gpu_count
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

class SleepScreen(Component):
  def __init__(self, logo_path, bmc_password:str|None=None, bmc_ip:str="N/A", ip:str="N/A"):
    if bmc_password is not None:
      self.bmc_password = Text(f"BMC PW: {bmc_password}", "mono", x=WIDTH//2, y=HEIGHT, anchor=Anchor.BOTTOM_CENTER)

    if hasattr(self, "bmc_password"): self.bmc_ip = Text(f"BMC: {bmc_ip}", "mono", anchor=Anchor.BOTTOM_CENTER, parent=ComponentParent(self.bmc_password, Anchor.TOP_CENTER))
    else: self.bmc_ip = Text(f"BMC: {bmc_ip}", "mono", x=WIDTH//2, y=HEIGHT, anchor=Anchor.BOTTOM_CENTER)

    self.ip = Text(f"IP: {ip}", "mono", anchor=Anchor.BOTTOM_CENTER, parent=ComponentParent(self.bmc_ip, Anchor.TOP_CENTER))

    # seperator line
    self.line = Rectangle(WIDTH - WIDTH // 5, 2, y=-8, anchor=Anchor.BOTTOM_CENTER, parent=ComponentParent(self.ip, Anchor.TOP_CENTER))

    # bouncing logo
    offset = -2 if hasattr(self, "bmc_password") else 62
    self.logo = MultiCollidingDVDImage([
      logo_path,
    ], [
      (400, 154),
    ], width=WIDTH, height=HEIGHT - (196 - offset), y=-2)

  def blit(self, display:Display):
    self.logo.blit(display)
    if hasattr(self, "bmc_password"):
      self.bmc_password.blit(display)
    self.bmc_ip.blit(display)
    self.ip.blit(display)
    self.line.blit(display)

class WelcomeScreen(Component):
  def __init__(self, qr_path, bmc_password:str|None=None, bmc_ip:str="N/A"):
    self.qr = Image(qr_path, (300, 300), y=HEIGHT // 2, anchor=Anchor.MIDDLE_LEFT)
    self.desc1 = Text("Scan for Docs", "sans", anchor=Anchor.TOP_LEFT, parent=ComponentParent(self.qr, Anchor.TOP_RIGHT))

    if bmc_password is not None:
      self.bmc_password = Text(bmc_password, "mono", anchor=Anchor.BOTTOM_LEFT, parent=ComponentParent(self.qr, Anchor.BOTTOM_RIGHT))

    self.bmc_ip = Text(bmc_ip, "mono", anchor=Anchor.BOTTOM_LEFT, parent=ComponentParent(self.qr, Anchor.BOTTOM_RIGHT))
    if hasattr(self, "bmc_password"):
      self.bmc_ip.parent = ComponentParent(self.bmc_password, Anchor.TOP_LEFT)
      self.desc2 = Text("BMC IP & Passwd", "sans", anchor=Anchor.BOTTOM_LEFT, parent=ComponentParent(self.bmc_ip, Anchor.TOP_LEFT))
    else: self.desc2 = Text("BMC IP", "sans", anchor=Anchor.BOTTOM_LEFT, parent=ComponentParent(self.bmc_ip, Anchor.TOP_LEFT))

  def blit(self, display:Display):
    self.qr.blit(display)
    self.desc1.blit(display)
    if hasattr(self, "bmc_password"): self.bmc_password.blit(display)
    self.bmc_ip.blit(display)
    self.desc2.blit(display)
