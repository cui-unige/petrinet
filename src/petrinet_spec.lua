local Pnml    = require "pnml"
local Gettime = require "socket".gettime

for _, what in ipairs { "petrinet" --[[, "petrinet.struct" ]] } do
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
      local start   = Gettime ()
      local _, size = pn.reachable (pn.initial)
      print (Gettime () - start)
      assert (size == 2, size)
    end)

    it ("loads models", function ()
      local model   = Pnml ("models/dekker-10.pnml")
      local pn      = Petrinet (model)
      local start   = Gettime ()
      local _, size = pn.reachable (pn.initial)
      print (Gettime () - start)
      assert (size == 6144, size)
    end)

    it ("loads models", function ()
      local model   = Pnml ("models/G-PPP-1-1.pnml")
      local pn      = Petrinet (model)
      local start   = Gettime ()
      local _, size = pn.reachable (pn.initial)
      print (Gettime () - start)
      assert (size == 10380, size)
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
      local pn    = Petrinet (data)
      -- local profi = require 'profi'
      -- profi:start()
      local start = Gettime ()
      local _, size = pn.reachable (pn.initial)
      print (Gettime () - start)
      -- profi:stop()
      -- profi:writeReport ("report.txt")
      print (size)
      assert (size == 6726, size)
    end)

  end)
end
