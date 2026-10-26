{ pkgs, ... }:

let
  root = "/drive/sync/music";
  out = "/var/lib/music-covers";
in
{
  systemd.tmpfiles.rules = [
    "d ${out} 0755 labile users -"
  ];

  systemd.services.music-covers = {
    description = "Extract embedded album art from the synced music library";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = with pkgs; [
      coreutils
      findutils
      gnused
      gawk
      ffmpeg
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "labile";
      Group = "users";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
    script = ''
      set -u
      root=${root}
      out=${out}
      index="$out/index.tsv"
      tmp="$index.tmp"
      : > "$tmp"
      find "$root" -mindepth 2 -maxdepth 2 -type d -print0 | while IFS= read -r -d "" album; do
        key="''${album#"$root"/}"
        hash=$(printf '%s' "$key" | sha1sum | cut -c1-16)
        dst="$out/$hash.jpg"
        if [ ! -s "$dst" ]; then
          src=$(find "$album" -maxdepth 1 -type f -name '*.flac' | sort | head -n 1)
          if [ -n "$src" ]; then
            ffmpeg -v error -y -i "$src" -map 0:v:0 -frames:v 1 \
              -vf "scale=512:512:force_original_aspect_ratio=decrease" "$dst" || rm -f "$dst"
          fi
        fi
        if [ -s "$dst" ]; then
          printf '%s\t%s\n' "$key" "$hash" >> "$tmp"
        fi
      done
      mv "$tmp" "$index"
      chmod 0644 "$index"
    '';
  };

  systemd.timers.music-covers = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
