import pygame
import subprocess, random
from display import Display

# initialize
display = Display("/dev/ttyACM1")

# put logo
logo = pygame.image.load("logo.png")
logo = pygame.transform.scale(logo, (400, 240))
display.blit(logo, (200, 20))

# ip
ipa = subprocess.run(["ip", "addr", "show", "dev", "wlan0"], capture_output=True, text=True).stdout
ip = ipa[ipa.index("inet ") + 5:].split("/")[0]
ip_text = display.text(f"IP: {ip}", 70, True, (255, 255, 255))
display.blit(ip_text, (400 - ip_text.get_width() // 2, 190 + (120 - ip_text.get_height() // 2)))

# random password
passwd = random.choices("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", k=8)
passwd_text = display.text(f"Password: {''.join(passwd)}", 70, True, (255, 255, 255))
display.blit(passwd_text, (400 - passwd_text.get_width() // 2, 260 + (120 - passwd_text.get_height() // 2)))

display.flip()
