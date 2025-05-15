{ ... }:
{

  programs.yt-dlp = {
    enable = true;
    settings = {
      downloader = "aria2c";
      extractor-args = "youtube:player-client=default,-tv,web_safari,web_embedded";
    };
  };
}
