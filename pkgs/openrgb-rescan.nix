{ writers }:

writers.writePython3Bin "openrgb-rescan" { } ''
  import socket
  import struct
  import sys
  import time

  HOST = "127.0.0.1"
  PORT = 6742
  REQUEST_RESCAN = 140
  DEBOUNCE = 1.0


  def main():
      time.sleep(DEBOUNCE)
      header = struct.pack("<4sIII", b"ORGB", 0, REQUEST_RESCAN, 0)
      try:
          with socket.create_connection((HOST, PORT), timeout=5) as sock:
              sock.sendall(header)
      except OSError:
          pass
      return 0


  if __name__ == "__main__":
      sys.exit(main())
''
