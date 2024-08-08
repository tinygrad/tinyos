import logging, time
logging.basicConfig(level=logging.INFO)

from tinyturing.display import Display, WIDTH

# initialize
display = Display()
display.clear()
display.flip(force=True)

style = "sans"
while True:
  display.clear()
  text = display.text(" !\"#$%&'()*+,-./012", style=style)
  display.blit(text, ((WIDTH - text.shape[0]) // 2, (text.shape[1] // 2) - 72 * 0))
  text = display.text("3456789:;<=>?@ABCDE", style=style)
  display.blit(text, ((WIDTH - text.shape[0]) // 2, (text.shape[1] // 2) + 72 * 1))
  text = display.text("FGHIJKLMNOPQRSTUVWX", style=style)
  display.blit(text, ((WIDTH - text.shape[0]) // 2, (text.shape[1] // 2) + 72 * 2))
  text = display.text("YZ[\\]^_`abcdefghijk", style=style)
  display.blit(text, ((WIDTH - text.shape[0]) // 2, (text.shape[1] // 2) + 72 * 3))
  text = display.text("lmnopqrstuvwxyz{|}~", style=style)
  display.blit(text, ((WIDTH - text.shape[0]) // 2, (text.shape[1] // 2) + 72 * 4))
  display.flip()

  if input() == "q": break
  if style == "sans": style = "mono"
  else: style = "sans"
