local Et     = require "etlua"
local Bit    = require "bit"
local Primes = require "primes"

local pnid = 0

return function (petrinet)

  local Marking_mt = {}
  local Marking    = setmetatable ({}, Marking_mt)
  Marking.__index  = Marking

  local names       = {}
  local places      = {}
  local transitions = {}
  for name, x in pairs (petrinet) do
    if type (x) == "table" and x.type == "place" then
      x.name    = name
      x.id      = #places+1
      x.initial = x.initial or 0
      x.bound   = x.bound   or 0
      places [x.id  ] = x
      names  [x.name] = x
    end
  end
  for name, x in pairs (petrinet) do
    if type (x) == "table" and x.type == "transition" then
      x.name     = name
      x.id       = #transitions+1
      local pre  = setmetatable ({}, { __index = function () return 0 end })
      local post = setmetatable ({}, { __index = function () return 0 end })
      for k, v in pairs (x.pre  or {}) do
        pre  [names [k]] = v
      end
      for k, v in pairs (x.post or {}) do
        post [names [k]] = v
      end
      x.pre  = pre
      x.post = post
      transitions [x.id] = x
    end
  end
  table.sort (places     , function (l, r) return l.id   < r.id   end)
  table.sort (transitions, function (l, r) return l.name < r.name end)
  for _, place in ipairs (places) do
    place.prime = Primes [place.id * math.ceil (#Primes / (#places+1))]
  end

  local unicity = {
    id = 0,
  }

  local environment = {
    Marking      = Marking,
    Bit          = Bit,
    petrinet     = petrinet,
    places       = places,
    transitions  = transitions,
    unicity      = unicity,
    getmetatable = getmetatable,
    setmetatable = setmetatable,
    require      = require,
    ipairs       = ipairs,
    pairs        = pairs,
    next         = next,
    print        = print,
    tostring     = tostring,
    pnid         = pnid,
  }

  do
    local code = Et.render ([[
      function Marking.unique (marking)
        setmetatable (marking, Marking)
        local hash = 0
        <% for i, place in ipairs (places) do %>
        marking [<%- place.id %>] = marking [<%- place.id %>] or 0
        hash = Bit.bxor (hash, marking [<%- place.id %>] * <%- place.prime %>)
        <% end %>
        local bucket = unicity [hash]
        if not bucket then
          bucket         = setmetatable ({}, { __mode = "k" })
          unicity [hash] = bucket
        end
        for m in pairs (bucket) do
          if Marking.__deepeq (m, marking) then
            return m
          end
        end
        bucket [marking] = true
        marking.__id = unicity.id
        unicity.id   = unicity.id + 1
        return marking
      end
    ]], environment)
    load (code, "Marking.unique", "t", environment) ()
  end

  do
    local code = Et.render ([[
      local Mt  = getmetatable (Marking)
      function Mt.__call (_, t)
        return Marking.unique (Marking.named (t, Marking))
      end
    ]], environment)
    load (code, "Marking_mt.__call", "t", environment) ()
  end

  do
    local code = Et.render ([[
      function Marking.__eq (lhs, rhs)
        return lhs.__id == rhs.__id
      end
    ]], environment)
    load (code, "Marking.__eq", "t", environment) ()
  end

  do
    local code = Et.render ([[
      function Marking.__deepeq (lhs, rhs)
        return true
        <% for _, place in ipairs (places) do %>
           and lhs [<%- place.id %>] == rhs [<%- place.id %>]
        <% end %>
      end
    ]], environment)
    load (code, "Marking.__deepeq", "t", environment) ()
  end

  do
    local code = Et.render ([[
      function Marking.__le (lhs, rhs)
        return true
        <% for _, place in ipairs (places) do %>
           and lhs [<%- place.id %>] <= rhs [<%- place.id %>]
        <% end %>
      end
    ]], environment)
    load (code, "Marking.__le", "t", environment) ()
  end

  do
    local code = Et.render ([[
      function Marking.__add (lhs, rhs)
        return Marking.unique {
          <% for _, place in ipairs (places) do %>
            lhs [<%- place.id %>] + rhs [<%- place.id %>],
          <% end %>
        }
      end
    ]], environment)
    load (code, "Marking.__add", "t", environment) ()
  end

  do
    local code = Et.render ([[
      function Marking.__sub (lhs, rhs)
        return Marking.unique {
          <% for _, place in ipairs (places) do %>
            lhs [<%- place.id %>] - rhs [<%- place.id %>],
          <% end %>
        }
      end
    ]], environment)
    load (code, "Marking.__sub", "t", environment) ()
  end

  do
    local code = Et.render ([[
      function Marking.__tostring (marking)
        return tostring (marking.__id)
            .. "@{"
              <% for _, place in ipairs (places) do %>
            .. " <%- place.name %>=" .. tostring (marking [<%- place.id %>])
              <% end %>
            .. " }"
      end
    ]], environment)
    load (code, "Marking.__tostring", "t", environment) ()
  end

  do
    local code = Et.render ([[
      Marking.named = function (t)
        return Marking.unique {
          <% for _, place in ipairs (places) do %>
            [<%- place.id %>] = t ["<%- place.name %>"] or 0,
          <% end %>
        }
      end
    ]], environment)
    load (code, "Marking.named", "t", environment) ()
  end

  do
    local code = Et.render ([[
      Marking.initial = Marking.named {
        <% for _, place in ipairs (places) do %>
          ["<%- place.name %>"] = <%- place.initial %>,
        <% end %>
      }
    ]], environment)
    load (code, "Marking.initial", "t", environment) ()
  end

  do
    local code = Et.render ([[
      Marking.empty = Marking.unique {}
    ]], environment)
    load (code, "Marking.empty", "t", environment) ()
  end

  for _, transition in ipairs (transitions) do
    environment.transition = transition
    local code = Et.render ([[
      function transition_<%- transition.id %> (marking)
        if false
          <% for place, value in pairs (transition.pre) do %>
        or marking [<%- place.id %>] < <%- value %>
          <% end %>
        then
          return nil
        end
        return Marking.unique {
          <% for _, place in ipairs (places) do %>
          marking [<%- place.id %>] - <%- transition.pre [place] %> + <%- transition.post [place] %>,
          <% end %>
        }
      end
      setmetatable (transitions [<%- transition.id %>], {
        __call = function (_, marking)
          return transition_<%- transition.id %> (marking)
        end,
      })
      Marking ["<%- transition.name %>"] = transition_<%- transition.id %>
    ]], environment)
    environment.transition = nil
    load (code, transition.name, "t", environment) ()
  end

  do
    local code = Et.render ([[
      Marking.reachable = function (marking)
        local explored    = {}
        local encountered = {
          [marking] = true
        }
        local marking, successor
        while next (encountered) do
          marking = next (encountered)
          encountered [marking] = nil
          explored    [marking] = true
          <% for _, transition in ipairs (transitions) do %>
          do
            successor = transition_<%- transition.id %> (marking)
            if successor then
              marking [transitions [<%- transition.id %>] ] = successor
              if not explored [successor] then
                encountered [successor] = true
              end
            end
          end
          <% end %>
        end
        return explored
      end
    ]], environment)
    load (code, "reachable", "t", environment) ()
  end

  local function reachable (from)
    local explored = Marking.reachable (from)
    local size = 0
    for _ in pairs (explored) do
      size = size + 1
    end
    local count = 0
    for _, v in pairs (unicity) do
      if type (v) == "table" then
        for _ in pairs (v) do
          count = count + 1
        end
      end
    end
    print ("count:", count)
    return explored, size
  end

  return {
    marking   = Marking.named,
    initial   = Marking.initial,
    empty     = Marking.empty,
    reachable = reachable,
  }
end
