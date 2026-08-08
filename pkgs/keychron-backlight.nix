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
  CUSTOM_SET_VALUE = 0x07
  CUSTOM_GET_VALUE = 0x08
  EFFECT_OFF = 0
  EFFECT_FALLBACK = 7
  STASH_NAME = "keychron-backlight.effect"


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


  def get_effect(node):
      header = [CUSTOM_GET_VALUE, CHANNEL_RGB_MATRIX, VALUE_ID_EFFECT]
      response = request(node, header)
      if response is None or len(response) < 4:
          return None
      if list(response[:3]) != header:
          return None
      return response[3]


  def set_effect(node, effect):
      request(node, [CUSTOM_SET_VALUE, CHANNEL_RGB_MATRIX, VALUE_ID_EFFECT, effect])


  def stash_path():
      directory = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
      return os.path.join(directory, STASH_NAME)


  def read_stash():
      try:
          with open(stash_path()) as handle:
              effect = int(handle.read().strip())
      except (OSError, ValueError):
          return EFFECT_FALLBACK
      if 0 <= effect <= 255:
          return effect
      return EFFECT_FALLBACK


  def write_stash(effect):
      try:
          with open(stash_path(), "w") as handle:
              handle.write(str(effect))
      except OSError:
          pass


  def main():
      argv = sys.argv[1:]
      if len(argv) != 1 or argv[0] not in ("on", "off"):
          print("usage: keychron-backlight on|off", file=sys.stderr)
          return 2
      node = find_node()
      if node is None:
          return 0
      if argv[0] == "off":
          current = get_effect(node)
          if current is not None and current != EFFECT_OFF:
              write_stash(current)
          set_effect(node, EFFECT_OFF)
      else:
          set_effect(node, read_stash())
      return 0


  if __name__ == "__main__":
      sys.exit(main())
''
