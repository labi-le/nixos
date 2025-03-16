{ ... }:

{

  xdg = {
    configFile = { "mimeapps.list".force = true; };
    mimeApps =
      let
        discord = "vesktop.desktop";
        image-editor = "gimp.desktop";
        imv = "imv.desktop";
        mediaplayer = "mpv.desktop";
        editor = "nvim.desktop";
        filemanager = "thunar.desktop";
        archive-manager = "xarchiver.desktop";
        browser = "google-chrome.desktop";
        pdf = "org.pwmt.zathura.desktop";
        terminal = "Alacritty.desktop";
      in
      {
        enable = true;
        associations.added = {
          "x-scheme-handler/terminal" = [ terminal ];
          "application/pdf" = [ browser ];
          "application/vnd.ms-publisher" = [ editor ];
          "application/x-extension-htm" = [ browser ];
          "application/x-extension-html" = [ browser ];
          "application/x-extension-shtml" = [ browser ];
          "application/x-extension-xht" = [ browser ];
          "application/x-extension-xhtml" = [ browser ];
          "application/xhtml+xml" = [ browser ];
          "application/xml" = [ editor ];
          "audio/aac" = [ mediaplayer ];
          "audio/flac" = [ mediaplayer ];
          "audio/mp4" = [ mediaplayer ];
          "audio/mpeg" = [ mediaplayer ];
          "audio/ogg" = [ mediaplayer ];
          "audio/x-wav" = [ mediaplayer ];
          "image/gif" = [ imv ];
          "image/jpeg" = [ imv ];
          "image/png" = [ imv ];
          "image/svg+xml" = [ browser ];
          "image/webp" = [ imv ];
          "image/x-xcf" = [ image-editor ];
          "inode/directory" = [ filemanager ];
          "text/html" = [ browser ];
          "text/markdown" = [ editor ];
          "text/plain" = [ editor ];
          "text/uri-list" = [ browser ];
          "video/mp4" = [ mediaplayer ];
          "video/ogg" = [ mediaplayer ];
          "video/webm" = [ mediaplayer ];
          "video/x-flv" = [ mediaplayer ];
          "video/x-matroska" = [ mediaplayer ];
          "video/x-ms-wmv" = [ mediaplayer ];
          "video/x-ogm+ogg" = [ mediaplayer ];
          "video/x-theora+ogg" = [ mediaplayer ];
          "x-scheme-handler/about" = [ browser ];
          "x-scheme-handler/chrome" = [ browser ];
          "x-scheme-handler/discord" = [ discord ];
          "x-scheme-handler/ftp" = [ browser ];
          "x-scheme-handler/http" = [ browser ];
          "x-scheme-handler/https" = [ browser ];
          "x-scheme-handler/unknown" = [ browser ];
          "application/zip" = [ archive-manager ];
          "application/rar" = [ archive-manager ];
          "application/7z" = [ archive-manager ];
          "application/*tar" = [ archive-manager ];
        };
        defaultApplications = {
          "x-scheme-handler/terminal" = [ terminal ];
          "application/pdf" = [ pdf ];
          "application/vnd.ms-publisher" = [ editor ];
          "application/x-extension-htm" = [ browser ];
          "application/x-extension-html" = [ browser ];
          "application/x-extension-shtml" = [ browser ];
          "application/x-extension-xht" = [ browser ];
          "application/x-extension-xhtml" = [ browser ];
          "application/xhtml+xml" = [ browser ];
          "application/xml" = [ editor ];
          "audio/aac" = [ mediaplayer ];
          "audio/flac" = [ mediaplayer ];
          "audio/mp4" = [ mediaplayer ];
          "audio/mpeg" = [ mediaplayer ];
          "audio/ogg" = [ mediaplayer ];
          "audio/x-wav" = [ mediaplayer ];
          "image/gif" = [ imv ];
          "image/jpeg" = [ imv ];
          "image/png" = [ imv ];
          "image/webp" = [ imv ];
          "image/x-xcf" = [ image-editor ];
          "inode/directory" = [ filemanager ];
          "text/html" = [ browser ];
          "text/markdown" = [ editor ];
          "text/plain" = [ editor ];
          "text/uri-list" = [ browser ];
          "video/mp4" = [ mediaplayer ];
          "video/ogg" = [ mediaplayer ];
          "video/webm" = [ mediaplayer ];
          "video/x-flv" = [ mediaplayer ];
          "video/x-matroska" = [ mediaplayer ];
          "video/x-ms-wmv" = [ mediaplayer ];
          "video/x-ogm+ogg" = [ mediaplayer ];
          "video/x-theora+ogg" = [ mediaplayer ];
          "x-scheme-handler/about" = [ browser ];
          "x-scheme-handler/chrome" = [ browser ];
          "x-scheme-handler/discord" = [ discord ];
          "x-scheme-handler/ftp" = [ browser ];
          "x-scheme-handler/http" = [ browser ];
          "x-scheme-handler/https" = [ browser ];
          "x-scheme-handler/unknown" = [ browser ];

        };
      };
  };
}
