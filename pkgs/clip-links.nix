{
  writeShellApplication,
  curl,
  jq,
  openssh,
}:

writeShellApplication {
  name = "clip-links";

  runtimeInputs = [
    curl
    jq
    openssh
  ];

  text = builtins.readFile ./clip-links.sh;

  meta = {
    description = "Forwards TikTok and YouTube links from the pc and notebook clipboards to a Telegram chat";
    mainProgram = "clip-links";
  };
}
