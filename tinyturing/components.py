from enum import Enum
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import PIL.Image

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
  def _blit(self, display:Display): raise NotImplementedError()

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

class Image(SimpleComponent):
  """
  A component that represents an image.
  """
  def __init__(self, path:str|Path, size:tuple[int, int], x:int=0, y:int=0, anchor=Anchor.MIDDLE_CENTER, parent=None):
    super().__init__(x, y, anchor, parent)
    self.image = np.array(PIL.Image.open(path).convert("RGBA").resize(size)).transpose(1, 0, 2)
  def _draw(self, display:Display): return self.image
