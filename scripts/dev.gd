extends RefCounted
## The one developer gate. Everything that exists only for testing hangs off DEV.on:
##   · the test keys (F2–F12 and their Shift / Ctrl / Alt variants, Insert, Home, End, Page Down, Page Up = every costume)
##   · the window.* hooks for browser checks (cvaTest, cvFame, cvaP1, cvaTrain, cvaTS / cvaT, cvaBook, cvaX, __ts / __gs / __train)
##   · the URL switches (?tsctl, ?slowtx, ?uiclock)
##   · the build stamp (bottom left in play, bottom right on the title)
## It is open in debug builds only: the editor binary, the tests (`-s`) and --export-debug.
## Every --export-release has it shut, and nothing at run time (arguments, URL, save, settings) can open it.

static var on: bool = OS.is_debug_build()
