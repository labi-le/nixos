{ pkgs, ... }:

let
  # Freeze forensics: the machine dies without leaving a single kernel line, so
  # the only way to learn anything is to have a thermal/power trace already on
  # disk when it happens. journald syncs every 1s (modules/journald.nix), so the
  # last sample before death survives. Deliberately limited to sysfs hwmon:
  # probing the Super-I/O (nct6775) or SMBus for VRM/+12V rails would poke the
  # very buses under suspicion.
  script = pkgs.writeShellScript "sensor-log" ''
    set -u
    cat=${pkgs.coreutils}/bin/cat

    find_hwmon() {
      for h in /sys/class/hwmon/hwmon*; do
        [ -r "$h/name" ] || continue
        if [ "$($cat "$h/name")" = "$1" ]; then
          echo "$h"
        fi
      done
    }

    read_milli() {
      if [ -r "$1" ]; then
        expr "$($cat "$1")" / 1000
      else
        echo "?"
      fi
    }

    read_micro() {
      if [ -r "$1" ]; then
        expr "$($cat "$1")" / 1000000
      else
        echo "?"
      fi
    }

    # Resolved every tick, not once: hwmon indices shuffle across boots and
    # amdgpu registers its hwmon later than this unit starts.
    while :; do
      cpu=$(find_hwmon k10temp | ${pkgs.coreutils}/bin/head -1)
      gpu=$(find_hwmon amdgpu | ${pkgs.coreutils}/bin/head -1)
      set -- $(find_hwmon spd5118)
      dimm0=''${1:-}
      dimm1=''${2:-}

      out="cpu=$(read_milli "$cpu/temp1_input")C ccd=$(read_milli "$cpu/temp3_input")C"
      out="$out dimm0=$(read_milli "$dimm0/temp1_input")C dimm1=$(read_milli "$dimm1/temp1_input")C"
      out="$out gpu=$(read_milli "$gpu/temp1_input")C hotspot=$(read_milli "$gpu/temp2_input")C vram=$(read_milli "$gpu/temp3_input")C"
      out="$out gpu_pwr=$(read_micro "$gpu/power1_average")W gpu_mv=$($cat "$gpu/in0_input" 2>/dev/null || echo '?')"
      out="$out gpu_busy=$($cat "$gpu/device/gpu_busy_percent" 2>/dev/null || echo '?')%"
      out="$out load=$(${pkgs.gawk}/bin/awk '{print $1}' /proc/loadavg)"
      echo "$out"
      ${pkgs.coreutils}/bin/sleep 10
    done
  '';
in
{
  systemd.services.sensor-log = {
    description = "Sensor trace for freeze forensics";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = script;
      Restart = "always";
      RestartSec = 5;
      Nice = 19;
      IOSchedulingClass = "idle";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateNetwork = true;
      NoNewPrivileges = true;
      SystemCallFilter = [ "@system-service" ];
    };
  };
}
