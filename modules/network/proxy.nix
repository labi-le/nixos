{ lib, config, ... }:

lib.mkIf config.network.enableProxy { }
