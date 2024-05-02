import sys
sys.path.insert(0, "/opt/tinybox/screen/")

from display import Display
import pygame

# initialize
display = Display("/dev/ttyACM0")

# logo
logo = pygame.image.load("/opt/tinybox/screen/logo.png")
logo = pygame.transform.scale(logo, (400, 240))
display.blit(logo, (200, 25))

# text
text = display.text("Rebooting...", 100, True, (255, 255, 255))
display.blit(text, (400 - text.get_width() // 2, 220 + (120 - text.get_height() // 2)))

display.flip()
