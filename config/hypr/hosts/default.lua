-- Any machine without its own profile: assumed to be a laptop with integrated
-- (Intel/AMD) graphics and a built-in screen. To customize a machine, copy this
-- file to hosts/<hostname>.lua (hostname: `hostnamectl hostname`).
return {
    laptop = true,

    -- Built-in screen. External screens get automatic placement/scale (and
    -- show whichever workspaces you open on them).
    monitors = {
        { output = "eDP-1", mode = "preferred", position = "0x0", scale = "auto", workspaces = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 } },
    },

    env = {},
}
