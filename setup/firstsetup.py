import sys
sys.path.insert(0, "/opt/tinybox/screen/")

import subprocess, random
import pygame
from display import Display

# initialize
display = Display("/dev/ttyACM1")

# logo
logo = pygame.image.load("logo.png")
logo = pygame.transform.scale(logo, (400, 240))
display.blit(logo, (200, 25))

# ip
ipa = subprocess.run(["ip", "addr", "show", "dev", "enp199s0f0"], capture_output=True, text=True).stdout
ip = ipa[ipa.index("inet ") + 5:].split("/")[0]
ip_text = display.text(f"IP: {ip}", 70, True, (255, 255, 255))
display.blit(ip_text, (400 - ip_text.get_width() // 2, 200 + (120 - ip_text.get_height() // 2)))

# random password
passwd = "".join(random.choices("abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ123456789", k=8))
p = subprocess.Popen(["chpasswd"], stdin=subprocess.PIPE, text=True)
p.communicate(input=f"tiny:{passwd}")
passwd_text = display.text(f"Password: {passwd}", 70, True, (255, 255, 255))
display.blit(passwd_text, (400 - passwd_text.get_width() // 2, 250 + (120 - passwd_text.get_height() // 2)))

display.flip()
