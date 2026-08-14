{ config, pkgs, ... }:
{
  # game-performance 依赖 power-profiles-daemon 提供的 powerprofilesctl
  services.power-profiles-daemon.enable = true;

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "game-performance" ''
      set -e
      if ! command -v powerprofilesctl &>/dev/null; then
        echo "Error: powerprofilesctl not found" >&2
        exit 1
      fi

      if ! powerprofilesctl list | grep -q 'performance:'; then
        exec "$@"
      fi

      if [ -n "$GAME_PERFORMANCE_SCREENSAVER_ON" ]; then
        exec powerprofilesctl launch -p performance \
          -r "Launched with CachyOS game-performance utility" -- "$@"
      else
        exec systemd-inhibit --why "CachyOS game-performance is running" \
          powerprofilesctl launch -p performance \
          -r "Launched with CachyOS game-performance utility" -- "$@"
      fi
    '')
    (pkgs.writeShellScriptBin "dlss-swapper" ''
      export PROTON_ENABLE_NGX_UPDATER=1
      export DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE=on
      export DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE=on
      export DXVK_NVAPI_DRS_NGX_DLSS_FG_OVERRIDE=on
      export DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest
      export DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest
      exec "$@"
    '')
    (pkgs.writeShellScriptBin "dlss-swapper-dll" ''
      export DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE=on
      export DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE=on
      export DXVK_NVAPI_DRS_NGX_DLSS_FG_OVERRIDE=on
      export DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest
      export DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest
      exec "$@"
    '')
  ];
}
