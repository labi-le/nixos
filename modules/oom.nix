{
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
    extraArgs = [
      "--prefer"
      "^(cc1|cc1plus|cc|gcc|g\\+\\+|clang|clang\\+\\+|ld|ld\\.lld|ld\\.gold|mold|lld|go|compile|link|gopls|rust-analyzer|rustc|cargo)$"
      "--avoid"
      "^(omp|\\.omp-wrapped|tmux:|sshd|systemd|dbus|zsh|bash|init|mariadbd|docker|containerd)"
    ];
  };

  systemd.oomd.enable = false;
}
