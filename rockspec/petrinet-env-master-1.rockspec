package = "petrinet-env"
version = "master-1"
source  = {
  url    = "git+https://github.com/saucisson/petrinet.git",
  branch = "master",
}

description = {
  summary    = "Petrinet: dev dependencies",
  detailed   = [[]],
  homepage   = "https://github.com/saucisson/petrinet",
  license    = "MIT/X11",
  maintainer = "Alban Linard <alban@linard.fr>",
}

dependencies = {
  "lua >= 5.1",
  "busted",
  "cluacov",
  "luacheck",
  "luacov",
  "luacov-coveralls",
  "luasocket",
  "serpent",
}

build = {
  type    = "builtin",
  modules = {},
}
