{ writers }:

writers.writePython3Bin "keychron-backlight" { flakeIgnore = [ "E501" ]; } ''
  import os
  import select
  import sys

  HIDRAW_CLASS = "/sys/class/hidraw"
  HID_ID = "HID_ID=0003:00003434:00000860"
  DESCRIPTOR_PREFIX = bytes([0x06, 0x60, 0xFF])
  REPORT_SIZE = 32
  READ_TIMEOUT = 1.0
  CHANNEL_RGB_MATRIX = 0x03
  VALUE_ID_EFFECT = 0x02
  VALUE_ID_COLOR = 0x04
  CUSTOM_SET_VALUE = 0x07
  EFFECT_OFF = 0
  EFFECT_SOLID = 1
  COLOR_RED_HUE = 0
  COLOR_RED_SAT = 255


  def find_node():
      try:
          names = sorted(os.listdir(HIDRAW_CLASS))
      except OSError:
          return None
      for name in names:
          device = os.path.join(HIDRAW_CLASS, name, "device")
          try:
              with open(os.path.join(device, "uevent")) as handle:
                  lines = handle.read().splitlines()
          except OSError:
              continue
          if HID_ID not in [line.strip() for line in lines]:
              continue
          try:
              with open(os.path.join(device, "report_descriptor"), "rb") as handle:
                  prefix = handle.read(len(DESCRIPTOR_PREFIX))
          except OSError:
              continue
          if prefix != DESCRIPTOR_PREFIX:
              continue
          return os.path.join("/dev", name)
      return None


  def request(node, payload):
      frame = bytes([0x00]) + bytes(payload)
      frame += bytes(REPORT_SIZE + 1 - len(frame))
      try:
          fd = os.open(node, os.O_RDWR)
      except OSError:
          return None
      try:
          os.write(fd, frame)
          readable, _, _ = select.select([fd], [], [], READ_TIMEOUT)
          if not readable:
              return None
          return os.read(fd, REPORT_SIZE)
      except OSError:
          return None
      finally:
          os.close(fd)


  def set_effect(node, effect):
      request(node, [CUSTOM_SET_VALUE, CHANNEL_RGB_MATRIX, VALUE_ID_EFFECT, effect])


  def set_color(node, hue, sat):
      request(node, [CUSTOM_SET_VALUE, CHANNEL_RGB_MATRIX, VALUE_ID_COLOR, hue, sat])


  def main():
      argv = sys.argv[1:]
      if len(argv) != 1 or argv[0] not in ("on", "off"):
          print("usage: keychron-backlight on|off", file=sys.stderr)
          return 2
      node = find_node()
      if node is None:
          return 0
      if argv[0] == "off":
          set_effect(node, EFFECT_OFF)
      else:
          set_color(node, COLOR_RED_HUE, COLOR_RED_SAT)
          set_effect(node, EFFECT_SOLID)
      return 0


  if __name__ == "__main__":
      sys.exit(main())
''
