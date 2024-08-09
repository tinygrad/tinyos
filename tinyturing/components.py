from enum import Enum
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import PIL.Image
from numba import njit

from tinyturing.display import Display

class Anchor(Enum):
  """An enum to represent the anchor points of a component."""
  TOP_LEFT = 0
  TOP_CENTER = 1
  TOP_RIGHT = 2
  MIDDLE_LEFT = 3
  MIDDLE_CENTER = 4
  MIDDLE_RIGHT = 5
  BOTTOM_LEFT = 6
  BOTTOM_CENTER = 7
  BOTTOM_RIGHT = 8

  def offset(self, component):
    """
    Return the offset of the anchor point for the given component.
    """
    if self == Anchor.TOP_LEFT: return 0, 0
    elif self == Anchor.TOP_CENTER: return -component.width // 2, 0
    elif self == Anchor.TOP_RIGHT: return -component.width, 0
    elif self == Anchor.MIDDLE_LEFT: return 0, -component.height // 2
    elif self == Anchor.MIDDLE_CENTER: return -component.width // 2, -component.height // 2
    elif self == Anchor.MIDDLE_RIGHT: return -component.width, -component.height // 2
    elif self == Anchor.BOTTOM_LEFT: return 0, -component.height
    elif self == Anchor.BOTTOM_CENTER: return -component.width // 2, -component.height
    elif self == Anchor.BOTTOM_RIGHT: return -component.width, -component.height
    else: raise ValueError(f"Unknown anchor: {self}")

class Component:
  """
  A base class for all components.
  """
  def __init__(self, x:int=0, y:int=0, anchor=Anchor.MIDDLE_CENTER, parent=None):
    self.anchor: Anchor = anchor
    self.parent: ComponentParent | None = parent

    self.x, self.y = x, y
    self.width: int = 0
    self.height: int = 0

  def _pre_blit(self, display:Display): pass
  def blit(self, display:Display):
    """
    Draw the component to the display.
    """
    self._pre_blit(display)
    x, y = self.x, self.y

    # first calculate x and y
    # if we have a parent we draw relative to it
    if self.parent is not None:
      parent = self.parent
      while parent is not None:
        x += parent.component.x
        y += parent.component.y
        offset = parent.component.anchor.offset(parent.component)
        x += offset[0]
        y += offset[1]
        offset = parent.anchor.offset(parent.component)
        x -= offset[0]
        y -= offset[1]
        parent = parent.component.parent

    # add anchor offset
    offset = self.anchor.offset(self)
    x += offset[0]
    y += offset[1]

    # finally draw
    self._blit(display, x, y)
  def _blit(self, display:Display, x:int, y:int): raise NotImplementedError()

@dataclass(frozen=True)
class ComponentParent:
  """
  A dataclass to represent a parent pointer along with where it's child anchor point should be.
  """
  component: Component
  anchor: Anchor

class SimpleComponent(Component):
  """
  A simple component with a single blittable surface.
  """
  def __init__(self, x:int=0, y:int=0, anchor=Anchor.MIDDLE_CENTER, parent=None):
    super().__init__(x, y, anchor, parent)
    self.surface = None

  def _draw(self, display:Display): raise NotImplementedError()
  def _pre_blit(self, display:Display):
    self.surface = self._draw(display)
    self.width, self.height = self.surface.shape[0], self.surface.shape[1]
  def _blit(self, display: Display, x:int, y:int):
    display.blit(self.surface, (x, y))

class Text(SimpleComponent):
  """
  A component that represents text.
  """
  def __init__(self, text:str, style:str, x:int=0, y:int=0, anchor=Anchor.MIDDLE_CENTER, parent=None):
    super().__init__(x, y, anchor, parent)
    self.text: str = text
    self.style: str = style

  def _draw(self, display:Display):
    return display.text(self.text, style=self.style)

class AnimatedText(SimpleComponent):
  """
  A component that cycles through a list of texts.
  """
  def __init__(self, texts:list[str], style:str, x:int=0, y:int=0, anchor=Anchor.MIDDLE_CENTER, parent=None):
    super().__init__(x, y, anchor, parent)
    self.texts: list[str] = texts
    self.style: str = style
    self.index = -1 # this gets incremented on the first draw

  def _draw(self, display:Display):
    self.index = (self.index + 1) % len(self.texts)
    return display.text(self.texts[self.index], style=self.style)

class Image(SimpleComponent):
  """
  A component that represents an image.
  """
  def __init__(self, path:str|Path, size:tuple[int, int], rotation:float=0, x:int=0, y:int=0, anchor=Anchor.MIDDLE_CENTER, parent=None):
    super().__init__(x, y, anchor, parent)
    self.image = PIL.Image.open(path).convert("RGBA").resize(size)
    self.rotation = rotation
  def _draw(self, display:Display):
    image = self.image
    if self.rotation != 0: image = image.rotate(self.rotation, resample=PIL.Image.BICUBIC, expand=True)
    return np.array(image).transpose(1, 0, 2)

class DVDImage(SimpleComponent):
  """
  A component that represents a bouncing DVD logo.
  """
  def __init__(self, path:str|Path, size:tuple[int, int], x:int=0, y:int=0):
    super().__init__(x, y, Anchor.MIDDLE_CENTER, None)
    self.image = np.array(PIL.Image.open(path).convert("RGBA").resize(size)).transpose(1, 0, 2)
    self.dx, self.dy = 1, 1
    self.x, self.y = 0, 0
  def _draw(self, display:Display):
    self.x += self.dx
    self.y += self.dy
    if self.x < 0 or self.x + self.image.shape[0] >= display.width: self.dx *= -1
    if self.y < 0 or self.y + self.image.shape[1] >= display.height: self.dy *= -1
    return self.image

class Rectangle(SimpleComponent):
  """
  A component that represents a rectangle.
  """
  def __init__(self, width:int, height:int, color:int=0xffffffff, x:int=0, y:int=0, anchor=Anchor.MIDDLE_CENTER, parent=None):
    super().__init__(x, y, anchor, parent)
    self._width, self._height = width, height
    self.color = color
  def _draw(self, display:Display):
    return np.full((self._width, self._height), self.color, dtype=np.uint32)

class VerticalProgressBar(SimpleComponent):
  """
  A component that represents a vertical progress bar.
  """
  def __init__(self, width:int, height:int, value:float=0, max_value:float=100, x:int=0, y:int=0, anchor=Anchor.MIDDLE_CENTER, parent=None):
    super().__init__(x, y, anchor, parent)
    self._width, self._height = width, height
    self.value, self.max_value = value, max_value

  def _draw(self, display:Display):
    filled = int(self._height * self.value // self.max_value)
    return np.full((self._width, filled), 0xffffffff, dtype=np.uint32)

class HorizontalProgressBar(SimpleComponent):
  """
  A component that represents a horizontal progress bar.
  """
  def __init__(self, width:int, height:int, value:float=0, max_value:float=100, x:int=0, y:int=0, anchor=Anchor.MIDDLE_CENTER, parent=None):
    super().__init__(x, y, anchor, parent)
    self._width, self._height = width, height
    self.value, self.max_value = value, max_value

  def _draw(self, display:Display):
    filled = int(self._width * self.value // self.max_value)
    return np.full((filled, self._height), 0xffffffff, dtype=np.uint32)

@njit
def _line(x1: int, y1: int, x2: int, y2: int) -> list[tuple[int, int]]:
  points = []
  dx, dy = abs(x2 - x1), abs(y2 - y1)
  sx, sy = 1 if x1 < x2 else -1, 1 if y1 < y2 else -1
  err = dx - dy
  while True:
    points.append((x1, y1))
    if x1 == x2 and y1 == y2: break
    e2 = 2 * err
    if e2 > -dy:
      err -= dy
      x1 += sx
    if e2 < dx:
      err += dx
      y1 += sy
  return points

class LineGraph(SimpleComponent):
  """
  A component that represents a scrolling line graph.
  """
  def __init__(self, width:int, height:int, max_points:int=20, x:int=0, y:int=0, anchor=Anchor.MIDDLE_CENTER, parent=None):
    super().__init__(x, y, anchor, parent)
    self._width, self._height = width, height
    self.max_points, self.data = max_points, []

  def add_data(self, point: float):
    self.data.append(point)
    if len(self.data) > self.max_points: self.data.pop(0)

  def _draw(self, display:Display):
    min_data, max_data = min(self.data), max(self.data)
    data_range = max_data - min_data
    if data_range == 0: data_range = 1
    surface = np.zeros((self._width, self._height), dtype=np.uint32)
    if len(self.data) < 2: return surface
    for i in range(len(self.data) - 1):
      x1, y1 = int(self._width * i / (self.max_points - 1)), self._height - int(self._height * (self.data[i] - min_data) / data_range)
      x2, y2 = int(self._width * (i + 1) / (self.max_points - 1)), self._height - int(self._height * (self.data[i + 1] - min_data) / data_range)
      # draw line
      for point in _line(x1, y1, x2, y2):
        # clamp point to graph bounds
        point = (max(0, min(self._width - 1, point[0])), max(0, min(self.height - 1, point[1])))
        surface[point[0], point[1]] = 0xffffffff
    return surface

