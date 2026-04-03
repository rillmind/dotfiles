require("git"):setup {
  order = 1500,
}

th.git = th.git or {}
th.git.modified  = ui.Style():fg("yellow")
th.git.added     = ui.Style():fg("green")
th.git.deleted   = ui.Style():fg("red"):bold()
th.git.untracked = ui.Style():fg("cyan")
th.git.ignored   = ui.Style():fg("gray")
th.git.clean     = ui.Style():fg("white")

th.git.modified_sign  = "M"
th.git.added_sign     = "A"
th.git.deleted_sign   = "D"
th.git.untracked_sign = "?"
th.git.clean_sign     = "✔"
