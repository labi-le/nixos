{
  pkgs,
  ...
}:

{
  programs.wofi.enable = true;

  programs.wofi.settings = {
    hide_scroll = "true";
    show = "drun";
    width = "25%";
    line_wrap = "word";
    term = "$TERM";
    allow_markup = "true";
    always_parse_args = "true";
    show_all = "true";
    print_command = "true";
    layer = "overlay";
    allow_images = "true";
    insensitive = "true";
    prompt = "";
    image_size = "15";
    display_generic = "true";
    location = "center";
  };

  home.packages = [
    (pkgs.writeShellScriptBin "wofi-powermenu" ''
      #!/bin/bash

      entries="Logout Suspend Reboot Shutdown"

      selected=$(printf '%s\n' $entries |  wofi -i --dmenu --hide-search --hide-scroll | awk '{print tolower($1)}')

      case $selected in
        logout)
          swaymsg exit;;
        suspend)
          exec systemctl suspend;;
        reboot)
          exec systemctl reboot;;
        shutdown)
          exec systemctl poweroff -i;;
      esac
    '')
  ];

  programs.wofi.style = ''
    * {
    	font-family: "Hack", monospace;
    }

    window {
    	background-color: #3B4252;
    }

    #input {
    	margin: 5px;
    	border-radius: 0px;
    	border: none;
    	background-color: #3B4252;
    	color: white;
    }

    #inner-box {
    	background-color: #383C4A;
    }

    #outer-box {
    	margin: 2px;
    	padding: 10px;
    	background-color: #383C4A;
    }

    #scroll {
    	margin: 5px;
    }

    #text {
    	padding: 4px;
    	color: white;
    }

    #entry:nth-child(even){
    	background-color: #404552;
    }

    #entry:selected {
    	background-color: #4C566A;
    }

    #text:selected {
    	background: transparent;
    }


  '';
}
