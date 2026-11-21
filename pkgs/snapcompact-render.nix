{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "snapcompact-render";
  version = "0.1.0";

  src = ./snapcompact-render;

  cargoLock.lockFile = ./snapcompact-render/Cargo.lock;

  meta = {
    description = "Renders conversation archives into snapcompact PNG frames";
    license = with lib.licenses; [
      mit
      publicDomain
      cc-by-40
    ];
    mainProgram = "snapcompact-render";
    platforms = lib.platforms.unix;
  };
}
