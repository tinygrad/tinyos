import sys
sys.path.insert(0, "/opt/tinybox/screen/")

from display import Display

display = Display("/dev/ttyACM0")
