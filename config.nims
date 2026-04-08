# Project config.nims — add src to search path for `nim c` convenience
--path:src
--path:tests
# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config