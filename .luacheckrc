std = "luajit"
self = false
unused_args = false
max_line_length = 120

globals = {
    "G_reader_settings",
    "G_defaults",
}

files["spec/**"].std = "+busted"
