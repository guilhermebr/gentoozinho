-- Adapted from Omarchy v3.8.4 (MIT)
hl.on("hyprland.start", function()
  -- Slow app launch fix: hand the session environment to systemd and dbus first.
  hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")

  hl.exec_cmd(gz.launch("hypridle"))
  hl.exec_cmd(gz.launch("mako"))
  hl.exec_cmd(gz.launch("waybar"))
  hl.exec_cmd(gz.launch("swaybg -i " .. os.getenv("HOME") .. "/.config/gentoozinho/current/background -m fill"))
  hl.exec_cmd(gz.launch("/usr/libexec/polkit-gnome-authentication-agent-1"))
end)
