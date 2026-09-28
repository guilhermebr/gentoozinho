-- Adapted from Omarchy v3.8.4 (MIT)
-- Browser types
gz.window("((google-)?[cC]hrom(e|ium)|[bB]rave-browser|[mM]icrosoft-edge|Vivaldi-stable|helium)", { tag = "+chromium-based-browser" })
gz.window("([fF]irefox|zen|librewolf)", { tag = "+firefox-based-browser" })
gz.window({ tag = "chromium-based-browser" }, { tag = "-default-opacity" })
gz.window({ tag = "firefox-based-browser" }, { tag = "-default-opacity" })

-- Video apps: remove chromium browser tag so they don't get opacity applied
gz.window("(chrome-youtube.com__-Default|chrome-app.zoom.us__wc_home-Default)", { tag = "-chromium-based-browser" })
gz.window("(chrome-youtube.com__-Default|chrome-app.zoom.us__wc_home-Default)", { tag = "-default-opacity" })

-- Force chromium-based browsers into a tile to deal with --app bug
gz.window({ tag = "chromium-based-browser" }, { tile = true })

-- Only a subtle opacity change, but not for video sites
gz.window({ tag = "chromium-based-browser" }, { opacity = "1.0 0.97" })
gz.window({ tag = "firefox-based-browser" }, { opacity = "1.0 0.97" })

-- Hide the screen-sharing notification bar (the "Hide" button on it is broken on Wayland)
gz.window({ title = ".*is sharing.*" }, { workspace = "special silent" })
