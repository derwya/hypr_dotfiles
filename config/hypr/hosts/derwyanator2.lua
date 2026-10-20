-- Desktop (derwyanator2): Ryzen 5 3600 + RTX 4070 SUPER, DP-2 main + HDMI-A-1 left.
return {
    laptop = false,

    -- First entry is the main monitor (top bar, workspace 1 at login).
    -- Scale 5/3 divides both resolutions exactly; DP-2 starts where HDMI ends (1152).
    monitors = {
        { output = "DP-2",     mode = "2560x1440@143.86", position = "1152x0", scale = "1.666667", workspaces = { 1, 2, 3, 4, 5 } },
        { output = "HDMI-A-1", mode = "1920x1080@60",     position = "0x340",  scale = "1.666667", workspaces = { 6, 7, 8, 9, 10 } },
    },

    -- NVIDIA
    env = {
        NVD_BACKEND               = "direct",
        __GLX_VENDOR_LIBRARY_NAME = "nvidia",
        GBM_BACKEND               = "nvidia-drm",
        LIBVA_DRIVER_NAME         = "nvidia",
        __VK_LAYER_NV_optimus     = "NVIDIA_only",
    },
}
