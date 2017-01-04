local Et  = require "etlua"
local Bit = require "bit"

local pnid = 0

return function (petrinet)

  local Marking_mt = {}
  local Marking    = setmetatable ({}, Marking_mt)
  Marking.__index  = Marking

  local sorted_places      = {}
  local sorted_transitions = {}
  for name, x in pairs (petrinet) do
    if type (x) == "table" and x.type == "place" then
      x.name    = name
      x.initial = x.initial or 0
      x.bound   = x.bound   or 0
      sorted_places [#sorted_places+1] = x
    elseif type (x) == "table" and x.type == "transition" then
      x.name = name
      sorted_transitions [#sorted_transitions+1] = x
    end
  end
  table.sort (sorted_places     , function (l, r) return l.name < r.name end)
  table.sort (sorted_transitions, function (l, r) return l.name < r.name end)

  local unicity = {
    id = 0,
  }

  local environment = {
    Marking            = Marking,
    Bit                = Bit,
    petrinet           = petrinet,
    sorted_places      = sorted_places,
    sorted_transitions = sorted_transitions,
    unicity            = unicity,
    getmetatable       = getmetatable,
    setmetatable       = setmetatable,
    print              = print,
    tostring           = tostring,
    pnid               = pnid,
  }

  do
    local code = Et.render ([[
      function Marking.unique (marking)
        local hash = 0
        <% for i, place in ipairs (sorted_places) do %>
          hash = Bit.bxor (hash, <%- i %> * marking ["<%- place.name %>"] * 2654435761)
        <% end %>
        local bucket = unicity [hash]
        if not bucket then
          bucket         = {}
          unicity [hash] = bucket
        end
        for i = 1, #bucket do
          if Marking.__deepeq (bucket [i], marking) then
            return bucket [i]
          end
        end
        bucket [#bucket+1] = marking
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
        return Marking.unique (setmetatable ({
          <% for _, place in ipairs (sorted_places) do %>
            ["<%- place.name %>"] = t ["<%- place.name %>"] or 0,
          <% end %>
        }, Marking))
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
        <% for _, place in ipairs (sorted_places) do %>
           and (lhs ["<%- place.name %>"] or 0) == (rhs ["<%- place.name %>"] or 0)
        <% end %>
      end
    ]], environment)
    load (code, "Marking.__deepeq", "t", environment) ()
  end

  do
    local code = Et.render ([[
      function Marking.__le (lhs, rhs)
        return true
        <% for _, place in ipairs (sorted_places) do %>
           and (lhs ["<%- place.name %>"] or 0) <= (rhs ["<%- place.name %>"] or 0)
        <% end %>
      end
    ]], environment)
    load (code, "Marking.__le", "t", environment) ()
  end

  do
    local code = Et.render ([[
      function Marking.__add (lhs, rhs)
        return Marking {
          <% for _, place in ipairs (sorted_places) do %>
            ["<%- place.name %>"] = (lhs ["<%- place.name %>"] or 0) + (rhs ["<%- place.name %>"] or 0),
          <% end %>
        }
      end
    ]], environment)
    load (code, "Marking.__add", "t", environment) ()
  end

  do
    local code = Et.render ([[
      function Marking.__sub (lhs, rhs)
        return Marking {
          <% for _, place in ipairs (sorted_places) do %>
            ["<%- place.name %>"] = (lhs ["<%- place.name %>"] or 0) - (rhs ["<%- place.name %>"] or 0),
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
              <% for _, place in ipairs (sorted_places) do %>
            .. " <%- place.name %>=" .. tostring (marking ["<%- place.name %>"])
              <% end %>
            .. " }"
      end
    ]], environment)
    load (code, "Marking.__tostring", "t", environment) ()
  end

  do
    local code = Et.render ([[
      Marking.initial = Marking {
        <% for _, place in ipairs (sorted_places) do %>
          ["<%- place.name %>"] = <%- place.initial %>,
        <% end %>
      }
    ]], environment)
    load (code, "Marking.initial", "t", environment) ()
  end

  do
    local code = Et.render ([[
      Marking.empty = Marking {
        <% for _, place in ipairs (sorted_places) do %>
          ["<%- place.name %>"] = 0,
        <% end %>
      }
    ]], environment)
    load (code, "Marking.empty", "t", environment) ()
  end

  do
    local code = Et.render ([[
      <% for i, transition in ipairs (sorted_transitions) do %>
        do
          local pre  = Marking {
            <% for place, value in pairs (transition.pre) do %>
              ["<%- place %>"] = <%- value %>,
            <% end %>
          }
          local post = Marking {
            <% for place, value in pairs (transition.post) do %>
              ["<%- place %>"] = <%- value %>,
            <% end %>
          }
          Marking ["<%- transition.name %>"] = function (marking)
            if marking >= pre then
              return marking - pre + post
            else
              return nil
            end
          end
        end
        setmetatable (sorted_transitions [<%- i %>], {
          __call = function (_, marking)
            return marking ["<%- transition.name %>"] (marking)
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
        for _, transition in ipairs (sorted_transitions) do
          local successor = transition (marking)
          if successor then
            -- marking     [transition] = successor
            encountered [successor ] = true
          end
        end
       end
    end
    local size = 0
    for _ in pairs (explored) do
      size = size + 1
    end
    return explored, size
  end

  return {
    marking   = Marking,
    initial   = Marking.initial,
    empty     = Marking.empty,
    reachable = reachable,
  }
end
