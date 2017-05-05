local Pnml = require "petrinet.pnml"
local Yaml = require "yaml"

local function show (pn)
  local result = pn.analysis ()
  local ps = {}
  local ts = {}
  for _, place in ipairs (pn.places) do
    ps [place.name] = {
      initial = place.initial,
      bound   = place.bound,
    }
  end
  for _, transition in ipairs (pn.transitions) do
    ts [transition.name] = transition.liveness
  end
  print (Yaml.dump {
    durations = {
      reachability = result.reachability.duration,
      bound        = result.bound.duration,
      liveness     = result.liveness.duration,
    },
    markings = {
      size = result.reachability.size,
    },
    bound    = ps,
    liveness = ts,
  })
end

for _, what in ipairs { "petrinet" --[[, "petrinet.struct"]] } do
  local Petrinet = require (what)

  describe ("#" .. what, function ()

    it ("works", function ()
      local pn = Petrinet {
        p1 = {
          type = "place",
          initial = 1,
        },
        p2 = {
          type = "place",
          initial = 0,
        },
        t = {
          type = "transition",
          pre = {
            p1 = 1,
          },
          post = {
            p2 = 1,
          },
        },
      }
      assert (pn.initial + pn.empty   == pn.initial)
      assert (pn.initial - pn.empty   == pn.initial)
      assert (pn.initial + pn.initial == pn.marking { p1 = 2 })
      assert (pn.initial:t ()         == pn.marking { p2 = 1 })
      local result = pn.analysis ()
      assert (result.reachability.size == 2, result.reachability.size)
    end)

    it ("loads models", function ()
      local model  = Pnml "models/dekker-10.pnml"
      local pn     = Petrinet (model)
      local result = pn.analysis ()
      assert (result.reachability.size == 6144, result.reachability.size)
    end)

    it ("loads models", function ()
      local model  = Pnml "models/G-PPP-1-1.pnml"
      local pn     = Petrinet (model)
      local result = pn.analysis ()
      assert (result.reachability.size == 10380, result.reachability.size)
    end)

    it ("works also with #Philosophers", function ()
      local n    = 10
      local data = {}
      for i = 1, n do
        local id = tostring (i)
        data ["fork-"     .. id] = {
          type    = "place",
          initial = 1,
        }
        data ["thinking-" .. id] = {
          type    = "place",
          initial = 1,
        }
        data ["waiting-"  .. id] = {
          type    = "place",
          initial = 0,
        }
        data ["eating-"   .. id] = {
          type    = "place",
          initial = 0,
        }
      end
      for i = 1, n do
        local id   = tostring (i)
        local next = tostring (i < n and i + 1 or 1)
        data ["t1-" .. id] = {
          type = "transition",
          pre  = {
            ["fork-"     .. id] = 1,
            ["thinking-" .. id] = 1,
          },
          post = {
            ["waiting-"  .. id] = 1,
          },
        }
        data ["t2-" .. id] = {
          type = "transition",
          pre  = {
            ["waiting-" .. id  ] = 1,
            ["fork-"    .. next] = 1,
          },
          post = {
            ["eating-"  .. id  ] = 1,
          },
        }
        data ["t3-" .. id] = {
          type = "transition",
          pre  = {
            ["eating-"   .. id  ] = 1,
          },
          post = {
            ["fork-"     .. id  ] = 1,
            ["fork-"     .. next] = 1,
            ["thinking-" .. id  ] = 1,
          },
        }
      end
      -- local profi = require 'profi'
      -- profi:start()
      local pn     = Petrinet (data)
      local result = pn.analysis ()
      -- profi:stop()
      -- profi:writeReport ("report.txt")
      assert (result.reachability.size == 6726, result.reachability.size)
    end)

    it ("can analyze liveness", function ()
      local pn = Petrinet {
        p1 = {
          type = "place",
          initial = 1,
        },
        p2 = {
          type = "place",
          initial = 0,
        },
        t1 = {
          type = "transition",
          pre = {
            p1 = 1,
          },
          post = {
            p2 = 1,
          },
        },
        t2 = {
          type = "transition",
          pre = {
            p2 = 1,
          },
          post = {
            p1 = 1,
          },
        },
      }
      local result = pn.analysis ()
      assert (result.reachability.size == 2, result.reachability.size)
    end)

  end)
end
