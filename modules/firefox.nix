{ ... }:

{
  programs.firefox = {
    enable = true;
    preferences = {
      "signon.rememberSignons" = false;
      "datareporting.healthreport.uploadEnabled" = false;
      "datareporting.policy.dataSubmissionEnabled" = false;
      "toolkit.telemetry.enabled" = false;
      "toolkit.telemetry.rejected" = true;
      "toolkit.telemetry.updatePing.enabled" = false;
      "toolkit.telemetry.unified" = false;
      "toolkit.telemetry.server" = "";

      "browser.contentblocking.enabled" = false;
      "privacy.donottrackheader.enabled" = true;
      "privacy.donottrackheader.value" = 1;
      "privacy.trackingprotection.enabled" = true;
      "privacy.trackingprotection.cryptomining.enabled" = true;
      "privacy.trackingprotection.fingerprinting.enabled" = true;
      "privacy.trackingprotection.socialtracking.enabled" = true;
      "privacy.trackingprotection.socialtracking.annotate.enabled" = true;
      "extensions.fxmonitor.enabled" = false;
    };
    policies = {
      DisablePocket = true;
      DisableTelemetry = true;
      DisableFirefoxStudies = true;

      # nix run github:tupakkatapa/mozid -- ''
      ExtensionSettings =
        with builtins;
        let
          extension = shortId: uuid: {
            name = uuid;
            value = {
              install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
              installation_mode = "normal_installed";
            };
          };
        in
        listToAttrs [
          (extension "uBlock Origin" "uBlock0@raymondhill.net")
          (extension "Bitwarden Password Manager" "{446900e4-71c2-419f-a6a7-df9c091e268b}")
          (extension "ClearURLs" "{74145f27-f039-47ce-a470-a662b129930a}")
          (extension "Return YouTube Dislike" "{762f9885-5a13-4abd-9c77-433dcd38b8fd}")
          (extension "Buster: Captcha Solver for Humans" "{e58d3966-3d76-4cd9-8552-1582fbc800c1}")
          (extension "DeepL" "{ea41402b-23b4-4ad1-97fb-7b6396789243}")
          (extension "Botnadzor" "extension@botnadzor.org")
          (extension "Github Repository Size" "github-repo-size@mattelrah.com")
          (extension "SteamDB" "firefox-extension@steamdb.info")
          (extension "SponsorBlock" "sponsorBlocker@ajay.app")
          (extension "GitHub Account Switcher" "{4f24a46e-2eb9-42d6-a842-60c410b28b74}")
          (extension "JSON Formatter" "{db8ff575-504f-4f3d-a910-07702998d21d}
")

        ];
    };
  };

}
