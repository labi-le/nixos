{
  user,
  ...
}:
{
  systemd.settings.Manager.DefaultLimitNOFILE = "524288";
  security.pam.loginLimits = [
    {
      domain = user.name;
      type = "hard";
      item = "nofile";
      value = "524288";
    }
  ];
}
