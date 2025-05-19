{ pkgs, lib, ... }:

let
  configFilePath = "${builtins.getEnv "HOME"}/.config/gitlab-secrets.json";

  generateRandomHex =
    { name, bytes }:
    lib.strings.removeSuffix "\n" (
      builtins.readFile (
        pkgs.runCommand "gitlab-secret-gen-${name}" { } ''
          ${pkgs.openssl}/bin/openssl rand -hex "${toString bytes}" > $out
        ''
      )
    );

  generatedSecretsData = {
    databasePassword = generateRandomHex {
      name = "db-password";
      bytes = 16;
    };
    initialRootPassword = generateRandomHex {
      name = "root-password";
      bytes = 16;
    };
    secretKeyBase = generateRandomHex {
      name = "secret-key-base";
      bytes = 64;
    };
    otpKeyBase = generateRandomHex {
      name = "otp-key-base";
      bytes = 64;
    };
    dbKeyBase = generateRandomHex {
      name = "db-key-base";
      bytes = 64;
    };
    activeRecordPrimaryKey = generateRandomHex {
      name = "ar-primary-key";
      bytes = 32;
    };
    activeRecordDeterministicKey = generateRandomHex {
      name = "ar-deterministic-key";
      bytes = 32;
    };
    activeRecordSalt = generateRandomHex {
      name = "ar-salt";
      bytes = 32;
    };

    runnerToken = { };
  };

  secretsData =
    if builtins.pathExists configFilePath then
      builtins.fromJSON (builtins.readFile configFilePath)
    else
      let
        generatedSecretsJSONContent = builtins.readFile (
          (pkgs.formats.json { }).generate "gitlab-secrets-template.json" generatedSecretsData
        );
      in
      throw (''
        GitLab secrets JSON file not found at: ${configFilePath}.
        To generate it, first ensure the directory exists:

          mkdir -p "$(dirname "${configFilePath}")"

        Then, create the file with the following content by running this command:

          echo '${generatedSecretsJSONContent}' > "${configFilePath}"

        Aborting Nix evaluation. The secrets file must exist to proceed.
      '');

  getRequiredSecret =
    keyName:
    let
      value = secretsData.${keyName} or null;
    in
    if value == null then
      throw "Secret key '${keyName}' is missing in evaluated secrets data from '${configFilePath}'. Ensure the file is correctly formatted JSON and contains the key."
    else if builtins.isString value then
      value
    else
      throw "Secret key '${keyName}' in '${configFilePath}' is not a string. Ensure the JSON format is correct and the value is a string. Found: ${builtins.toJSON value}";

  dbPassword = getRequiredSecret "databasePassword";
  initialRootPassword = getRequiredSecret "initialRootPassword";
  secretKeyBaseValue = getRequiredSecret "secretKeyBase";
  otpKeyBaseValue = getRequiredSecret "otpKeyBase";
  dbKeyBaseValue = getRequiredSecret "dbKeyBase";
  activeRecordPrimaryKeyValue = getRequiredSecret "activeRecordPrimaryKey";
  activeRecordDeterministicKeyValue = getRequiredSecret "activeRecordDeterministicKey";
  activeRecordSaltValue = getRequiredSecret "activeRecordSalt";

  runnerToken = getRequiredSecret "runnerToken";

  host = "gitlab.labile.cc";
in
{
  services.gitlab = {
    inherit host;
    enable = true;
    https = true;
    port = 443;
    databasePasswordFile = pkgs.writeText "dbPassword" dbPassword;
    initialRootPasswordFile = pkgs.writeText "rootPassword" initialRootPassword;
    secrets = {
      secretFile = pkgs.writeText "secret" secretKeyBaseValue;
      otpFile = pkgs.writeText "otpsecret" otpKeyBaseValue;
      dbFile = pkgs.writeText "dbsecret" dbKeyBaseValue;
      jwsFile = pkgs.runCommand "oidcKeyBase" { } "${pkgs.openssl}/bin/openssl genrsa 2048 > $out";
      activeRecordPrimaryKeyFile = pkgs.writeText "activeRecordPrimaryKey" activeRecordPrimaryKeyValue;
      activeRecordDeterministicKeyFile = pkgs.writeText "activeRecordDeterministicKey" activeRecordDeterministicKeyValue;
      activeRecordSaltFile = pkgs.writeText "activeRecordSalt" activeRecordSaltValue;
    };
  };

  environment.etc."gitlab-runner/nix-service.env" = {
    text = ''
      CI_SERVER_URL="https://${host}"
      CI_SERVER_TOKEN=${runnerToken}
    '';
    mode = "0440";
    user = "root";
  };

  services.gitlab-runner = {
    enable = true;
    settings = {
      url = host;
    };
    gracefulTimeout = "1h";
    services = {
      nix = {
        authenticationTokenConfigFile = "/etc/gitlab-runner/nix-service.env";
        dockerImage = "alpine";
        dockerVolumes = [
          "/nix/store:/nix/store:ro"
          "/nix/var/nix/db:/nix/var/nix/db:ro"
          "/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket:ro"
        ];
        dockerDisableCache = false;
        environmentVariables = {
          ENV = "/etc/profile";
          USER = "root";
          NIX_REMOTE = "daemon";
          PATH = "/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/bin:/sbin:/usr/bin:/usr/sbin";
          NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt";
        };
      };
    };
  };
}
