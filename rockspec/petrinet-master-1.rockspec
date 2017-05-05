package = "petrinet"
version = "master-1"
source  = {
  url    = "git+https://github.com/saucisson/petrinet.git",
  branch = "master",
}

description = {
  summary    = "Petrinet",
  detailed   = [[]],
  homepage   = "https://github.com/saucisson/petrinet",
  license    = "MIT/X11",
  maintainer = "Alban Linard <alban@linard.fr>",
}

dependencies = {
  "lua >= 5.1",
  "etlua",
  "xml",
}

build = {
  type    = "builtin",
  modules = {
    ["petrinet"       ] = "src/petrinet.lua",
    ["petrinet.pnml"  ] = "src/petrinet/pnml.lua",
    ["petrinet.primes"] = "src/petrinet/primes.lua",
  },
}
