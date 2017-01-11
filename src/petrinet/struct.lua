local Et     = require "etlua"
local Bit    = require "bit"
local Ffi    = require "ffi"
local Primes = require "primes"

local pnid = 0

return function (petrinet)

  pnid = pnid + 1
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
      x.name = name
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
      transitions [#transitions+1] = x
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
    Ffi          = Ffi,
    petrinet     = petrinet,
    places       = places,
    transitions  = transitions,
    unicity      = unicity,
    getmetatable = getmetatable,
    setmetatable = setmetatable,
    require      = require,
    ipairs       = ipairs,
    pairs        = pairs,
    print        = print,
    tostring     = tostring,
    pnid         = pnid,
  }

  Ffi.cdef (Et.render ([[
    typedef struct {
      unsigned long long __id;
      <% for i in ipairs (places) do %>
        unsigned char place_<%- i %>;
      <% end %>
    } marking_<%- pnid %>_t;
  ]], environment))
  Ffi.metatype (Et.render ("marking_<%- pnid %>_t", environment), Marking)

  do
    local code = Et.render ([[
      function Marking.unique (marking)
        local hash = 0
        <% for i, place in ipairs (places) do %>
        marking.place_<%- i %> = marking.place_<%- i %> or 0
        hash = Bit.bxor (hash, marking.place_<%- i %> * <%- place.prime %>)
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
      local Ffi = require "ffi"
      local Mt  = getmetatable (Marking)
      function Mt.__call (_, marking)
        return Marking.unique (Marking.named (marking))
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
        <% for i in ipairs (places) do %>
           and lhs.place_<%- i %> == rhs.place_<%- i %>
        <% end %>
      end
    ]], environment)
    load (code, "Marking.__deepeq", "t", environment) ()
  end

  do
    local code = Et.render ([[
      function Marking.__le (lhs, rhs)
        return true
        <% for i in ipairs (places) do %>
           and lhs.place_<%- i %> <= rhs.place_<%- i %>
        <% end %>
      end
    ]], environment)
    load (code, "Marking.__le", "t", environment) ()
  end

  do
    local code = Et.render ([[
      function Marking.__add (lhs, rhs)
        local result = Ffi.new "marking_<%- pnid %>_t"
        <% for i, place in ipairs (places) do %>
        result.place_<%- i %> = lhs.place_<%- i %> + rhs.place_<%- i %>
        <% end %>
        return Marking.unique (result)
      end
    ]], environment)
    load (code, "Marking.__add", "t", environment) ()
  end

  do
    local code = Et.render ([[
      function Marking.__sub (lhs, rhs)
        local result = Ffi.new "marking_<%- pnid %>_t"
        <% for i, place in ipairs (places) do %>
        result.place_<%- i %> = lhs.place_<%- i %> - rhs.place_<%- i %>
        <% end %>
        return Marking.unique (result)
      end
    ]], environment)
    load (code, "Marking.__sub", "t", environment) ()
  end

  do
    local code = Et.render ([[
      function Marking.__tostring (marking)
        return tostring (marking.__id)
            .. "@{"
              <% for i, place in ipairs (places) do %>
            .. " <%- place.name %>=" .. tostring (marking.place_<%- i %>)
              <% end %>
            .. " }"
      end
    ]], environment)
    load (code, "Marking.__tostring", "t", environment) ()
  end

  do
    local code = Et.render ([[
      Marking.named = function (t)
        local result = Ffi.new "marking_<%- pnid %>_t"
        <% for i, place in ipairs (places) do %>
        result.place_<%- i %> = t ["<%- place.name %>"] or 0
        <% end %>
        return Marking.unique (result)
      end
    ]], environment)
    load (code, "Marking.named", "t", environment) ()
  end

  do
    local code = Et.render ([[
      Marking.initial = Marking.named {
        <% for i, place in ipairs (places) do %>
        ["<%- place.name %>"] = <%- place.initial %> or 0,
        <% end %>
      }
    ]], environment)
    load (code, "Marking.initial", "t", environment) ()
  end

  do
    local code = Et.render ([[
      local result = Ffi.new "marking_<%- pnid %>_t"
      Marking.empty = Marking.named {}
    ]], environment)
    load (code, "Marking.empty", "t", environment) ()
  end

  do
    local code = Et.render ([[
      <% for i, transition in ipairs (transitions) do %>
        Marking ["<%- transition.name %>"] = function (marking)
          if false
            <% for place, value in pairs (transition.pre) do %>
          or marking.place_<%- place.id %> < <%- value %>
            <% end %>
          then
            return nil
          end
          local result = Ffi.new "marking_<%- pnid %>_t"
          <% for _, place in ipairs (places) do %>
          result.place_<%- place.id %> = marking.place_<%- place.id %> - <%- transition.pre [place] %> + <%- transition.post [place] %>
          <% end %>
          return Marking.unique (result)
        end
        setmetatable (transitions [<%- i %>], {
          __call = function (_, marking)
            return Marking ["<%- transition.name %>"] (marking)
          end,
        })
      <% end %>
    ]], environment)
    load (code, "transitions", "t", environment) ()
  end

  local function reachable (from)
    local explored    = {}
    local encountered = {
      [from] = true
    }
    while next (encountered) do
      local marking = next (encountered)
      encountered [marking] = nil
      if not explored [marking] then
        explored [marking] = true
        for _, transition in ipairs (transitions) do
          local successor = transition (marking)
          if successor then
            -- marking     [transition] = successor
            encountered [successor] = true
          end
        end
       end
    end
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
