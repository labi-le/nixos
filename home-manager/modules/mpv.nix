{ pkgs, ... }:
{
  programs.mpv = {
    enable = true;
    scripts = with pkgs.mpvScripts; [
      sponsorblock-minimal
      videoclip
      thumbfast
      uosc
    ];
    scriptOpts = {
      sponsorblock-minimal = {
        sponsorblock_minimal-server = "https://sponsor.ajay.app/api/skipSegments";
        sponsorblock_minimal-categories = [ "sponsor" ];
      };
      videoclip = {
        video_quality = 1;
        video_height = -2;
        video_width = -2;
        video_folder_path = "/tmp";
        audio_folder_path = "/tmp";
        clean_filename = "yes";
      };

      thumbfast = {
        network = "yes";
        autogenerate = "yes";
        hwdec = "yes";
        direct_io = "yes";
        worker_count = "8";
      };
    };
    config = {
      save-position-on-quit = "yes";

      cache = "yes";
      cache-secs = "600";
      cache-pause = "no";

      hwdec = "auto-safe";
      hwdec-codecs = "vulkan";

      vo = "gpu-next";
      gpu-api = "vulkan";
      gpu-context = "waylandvk";

      fs = "yes";
      osc = "no";
      osd-bar = "no";

      glsl-shaders = "${pkgs.anime4k}/Anime4K_Clamp_Highlights.glsl:${pkgs.anime4k}/Anime4K_Restore_CNN_VL.glsl:${pkgs.anime4k}/Anime4K_Upscale_CNN_x2_VL.glsl:${pkgs.anime4k}/Anime4K_AutoDownscalePre_x2.glsl:${pkgs.anime4k}/Anime4K_AutoDownscalePre_x4.glsl:${pkgs.anime4k}/Anime4K_Upscale_CNN_x2_M.glsl";
    };
    bindings = {
      WHEEL_UP = "add volume 1";
      WHEEL_DOWN = "add volume -1";
      "Shift+WHEEL_UP" = "add volume 5";
      "Shift+WHEEL_DOWN" = "add volume -5";

      RIGHT = "seek 5";
      LEFT = "seek -5";
      UP = "add volume 2";
      DOWN = "add volume -2";

      "Shift+RIGHT" = "seek 10";
      "Shift+LEFT" = "seek -10";

      "Shift+UP" = "add volume 5";
      "Shift+DOWN" = "add volume -5";

      q = "quit";
      "й" = "quit";
      Q = "quit-watch-later";

      SPACE = "cycle pause";

      m = "cycle mute";
      "ь" = "cycle mute";

      p = "show-progress";
      "з" = "show-progress";

      f = "cycle fullscreen";
      "а" = "cycle fullscreen";

      c = "script-binding videoclip-menu-open";
    };
    extraInput = ''
      			CTRL+1 no-osd change-list glsl-shaders set "${pkgs.anime4k}/Anime4K_Clamp_Highlights.glsl:${pkgs.anime4k}/Anime4K_Restore_CNN_VL.glsl:${pkgs.anime4k}/Anime4K_Upscale_CNN_x2_VL.glsl:${pkgs.anime4k}/Anime4K_AutoDownscalePre_x2.glsl:${pkgs.anime4k}/Anime4K_AutoDownscalePre_x4.glsl:${pkgs.anime4k}/Anime4K_Upscale_CNN_x2_M.glsl"; show-text "Anime4K: Mode A (HQ)"
      			CTRL+0 no-osd change-list glsl-shaders clr ""; show-text "GLSL shaders cleared"
          	'';
  };
}
