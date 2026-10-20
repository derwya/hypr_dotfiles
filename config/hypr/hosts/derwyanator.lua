-- Laptop (derwyanator): Lenovo, Intel UHD (CometLake-U), 2560x1600 built-in panel.
return {
    laptop = true,

    -- Scale 5/3 divides 2560x1600 exactly (1536x960 logical), same look as the
    -- old config's 1.67. External screens get automatic placement/scale.
    monitors = {
        { output = "eDP-1", mode = "2560x1600@60", position = "0x0", scale = "1.666667", workspaces = { 1, 2, 3, 4, 5 } },
    },

    -- The shared -0.5 suits the desktop mouse; the touchpad/TrackPoint need more (range -1..1).
    input = {
        sensitivity = 0,
    },

    env = {},
}
