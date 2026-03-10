{
  pkgs,
  config,
  user,
  ...
}:

let

  username = user.name;
  homeDirectory = "/home/${username}";

in
{
  imports = [ ./modules ];
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = username;
  home.homeDirectory = homeDirectory;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.11"; # Please read the comment before changing.

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file."Downloads" = {
    source = config.lib.file.mkOutOfStoreSymlink "/tmp";
  };

  programs.home-manager.enable = true;
  home.enableNixpkgsReleaseCheck = false;
}
