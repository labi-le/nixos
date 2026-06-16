{
  environment.sessionVariables = {
    SDL_VIDEODRIVER = "wayland";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    MOZ_ENABLE_WAYLAND = "1";

    # Force uv/uvx to always use python-build-standalone instead of NixOS
    # system Python. PB-S binaries use the FHS dynamic linker at
    # /lib64/ld-linux-x86-64.so.2, which nix-ld intercepts to provide
    # system libraries (libstdc++, libz, etc.) needed by prebuilt wheels.
    # Without this, uv picks NixOS Python whose ld.so bypasses nix-ld,
    # breaking numpy/onnxruntime imports in tools like chroma-mcp.
    UV_PYTHON_PREFERENCE = "only-managed";
  };
}
