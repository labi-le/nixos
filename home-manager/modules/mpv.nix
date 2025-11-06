{ pkgs, ... }:

let

  # mpvShadersUnstable = pkgs.stdenv.mkDerivation rec {
  #   pname = "mpv-shim-default-shaders";
  #   version = "unstable-2025-03-17";
  #
  #   src = pkgs.fetchFromGitHub {
  #     owner = "iwalton3";
  #     repo = "default-shader-pack";
  #     rev = "0fdea2adb33ae7112fac190eb826615622b08333";
  #     sha256 = "16a9c3pqqa45fdvri694xikqka7n0hzs5ykyawlvgywj91i9z9nw";
  #   };
  #
  #   installPhase = ''
  #     mkdir -p $out/share/${pname}
  #     cp -r shaders *.json $out/share/${pname}
  #   '';
  # };

  mpvShaders = pkgs.stdenv.mkDerivation rec {
    pname = "mpv-prescalers";
    version = "2024-01-11";

    src = pkgs.fetchFromGitHub {
      owner = "bjin";
      repo = "mpv-prescalers";
      rev = "b3f0a59d68f33b7162051ea5970a5169558f0ea2";
      sha256 = "1vi233fjjglzgajbsqqc6v6l28p4nyjaimcw3gwmmw6sfx9qbw19";
    };

    installPhase = ''
      mkdir -p $out/share/${pname}
      cp -r ./* $out/share/${pname}/
    '';
  };

  ravuShadersDir = "${mpvShaders}/share/mpv-prescalers/compute/";

  # shadersDir = "${mpvShadersUnstable}/share/mpv-shim-default-shaders/shaders/";

  # anime4kShaders =
  #   "${pkgs.anime4k}/Anime4K_Clamp_Highlights.glsl:"
  #   + "${pkgs.anime4k}/Anime4K_Restore_CNN_VL.glsl:"
  #   + "${pkgs.anime4k}/Anime4K_Upscale_CNN_x2_VL.glsl:"
  #   + "${pkgs.anime4k}/Anime4K_AutoDownscalePre_x2.glsl:"
  #   + "${pkgs.anime4k}/Anime4K_AutoDownscalePre_x4.glsl:"
  #   + "${pkgs.anime4k}/Anime4K_Upscale_CNN_x2_M.glsl";
  # fsrcnnxShader = "${shadersDir}FSRCNNX_x2_16-0-4-1.glsl";
  # nnedi3Shader = "${shadersDir}nnedi3-nns64-win8x6.hook";
  ravuZoom = "${ravuShadersDir}ravu-zoom-ar-r3.hook";
  ravuYuv = "${ravuShadersDir}ravu-zoom-r3-yuv.hook";

  # combinedShaders = "${nnedi3Shader}:${fsrcnnxShader}:${anime4kShaders}";
in
{
  programs.mpv = {
    enable = true;
    scripts = with pkgs.mpvScripts; [
      sponsorblock-minimal
      videoclip
      thumbfast
      youtube-chat
    ];
    scriptOpts = {
      mpv-youtube-chat = {
        auto-load = "no";
        anchor = 9;
      };
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
        hwdec = "yes";
      };
    };
    config = {
      save-position-on-quit = "yes";

      cache = "yes";
      cache-secs = "600";
      cache-pause = "no";

      demuxer-max-bytes = "512M";

      # gpu-context = "wayland";
      # hwdec = "auto-safe";
      # vo = "vaapi";
      # hwdec-codecs = "all";
      # profile = "gpu-hq";

      fs = "no";
      osc = "yes";
      osd-bar = "yes";
      # glsl-shaders = combinedShaders;
    };
    bindings = {
      "Ctrl+j" = "script-message load-chat";

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
      CTRL+1 no-osd change-list glsl-shaders set "${ravuZoom}"; show-text "Upscaler: ravu zoom Only"
      CTRL+2 no-osd change-list glsl-shaders set "${ravuYuv}"; show-text "Upscaler: ravu yuv Only"
      CTRL+0 no-osd change-list glsl-shaders clr ""; show-text "Upscalers: OFF"
    '';
  };
}
