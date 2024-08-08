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
    };
  };
}
