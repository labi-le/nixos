{
  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=1G
  '';
}
