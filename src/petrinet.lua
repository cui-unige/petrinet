local Et      = require "etlua"
local Bit     = require "bit"
local Gettime = require "socket".gettime
local Primes  = require "petrinet.primes"

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
      x.bound   = {
        minimum = x.bound and x.bound.minimum or 0,
        maximum = x.bound and x.bound.maximum or math.huge,
      }
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
    math         = math,
    print        = print,
    tostring     = tostring,
    pnid         = pnid,
  }

  do
    local code = Et.render ([=[
      function Marking.unique (marking)
        setmetatable (marking, Marking)
        local hash = 0
        <% for i, place in ipairs (places) do %>
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
    ]=], environment)
    load (code, "Marking.unique", "t", environment) ()
  end

  do
    local code = Et.render ([=[
      local Mt  = getmetatable (Marking)
      function Mt.__call (_, t)
        return Marking.unique (Marking.named (t, Marking))
      end
    ]=], environment)
    load (code, "Marking_mt.__call", "t", environment) ()
  end

  do
    local code = Et.render ([=[
      function Marking.__eq (lhs, rhs)
        return lhs.__id == rhs.__id
      end
    ]=], environment)
    load (code, "Marking.__eq", "t", environment) ()
  end

  do
    local code = Et.render ([=[
      function Marking.__deepeq (lhs, rhs)
        return true
        <% for _, place in ipairs (places) do %>
           and lhs [<%- place.id %>] == rhs [<%- place.id %>]
        <% end %>
      end
    ]=], environment)
    load (code, "Marking.__deepeq", "t", environment) ()
  end

  do
    local code = Et.render ([=[
      function Marking.__le (lhs, rhs)
        return true
        <% for _, place in ipairs (places) do %>
           and lhs [<%- place.id %>] <= rhs [<%- place.id %>]
        <% end %>
      end
    ]=], environment)
    load (code, "Marking.__le", "t", environment) ()
  end

  do
    local code = Et.render ([=[
      function Marking.__add (lhs, rhs)
        return Marking.unique {
          <% for _, place in ipairs (places) do %>
            lhs [<%- place.id %>] + rhs [<%- place.id %>],
          <% end %>
        }
      end
    ]=], environment)
    load (code, "Marking.__add", "t", environment) ()
  end

  do
    local code = Et.render ([=[
      function Marking.__sub (lhs, rhs)
        return Marking.unique {
          <% for _, place in ipairs (places) do %>
            lhs [<%- place.id %>] - rhs [<%- place.id %>],
          <% end %>
        }
      end
    ]=], environment)
    load (code, "Marking.__sub", "t", environment) ()
  end

  do
    local code = Et.render ([=[
      function Marking.__tostring (marking)
        return tostring (marking.__id)
            .. "@{"
              <% for _, place in ipairs (places) do %>
            .. " <%- place.name %>=" .. tostring (marking [<%- place.id %>])
              <% end %>
            .. " }"
      end
    ]=], environment)
    load (code, "Marking.__tostring", "t", environment) ()
  end

  do
    local code = Et.render ([=[
      Marking.named = function (t)
        return Marking.unique {
          <% for _, place in ipairs (places) do %>
            [<%- place.id %>] = t ["<%- place.name %>"] or 0,
          <% end %>
        }
      end
    ]=], environment)
    load (code, "Marking.named", "t", environment) ()
  end

  do
    local code = Et.render ([=[
      Marking.initial = Marking.named {
        <% for _, place in ipairs (places) do %>
          ["<%- place.name %>"] = <%- place.initial %> or 0,
        <% end %>
      }
    ]=], environment)
    load (code, "Marking.initial", "t", environment) ()
  end

  do
    local code = Et.render ([=[
      Marking.empty = Marking.unique {
        <% for _, place in ipairs (places) do %>
          [<%- place.id %>] = 0,
        <% end %>
      }
    ]=], environment)
    load (code, "Marking.empty", "t", environment) ()
  end

  for _, transition in ipairs (transitions) do
    environment.transition = transition
    local code = Et.render ([=[
      local inf = math.huge
      local function transition_<%- transition.id %> (marking)
        if false
          <% for place, value in pairs (transition.pre) do %>
        or marking [<%- place.id %>] < <%- value %>
          <% end %>
        then
          return nil
        end
        local result = {
          <% for _, place in ipairs (places) do %>
          marking [<%- place.id %>] - <%- transition.pre [place] %> + <%- transition.post [place] %>,
          <% end %>
        }
        <% for _, place in ipairs (places) do %>
          if result [<%- place.id %>] < <%- place.bound.minimum %> then
            error {
              type   = "bound.minimum",
              place  = <%- place.name %>,
              bound  = <%- place.bound.minimum %>,
              tokens = result [<%- place.id %>],
            }
          end
          if result [<%- place.id %>] > <%- place.bound.maximum %> then
            error {
              type   = "bound.maximum",
              place  = <%- place.name %>,
              bound  = <%- place.bound.maximum %>,
              tokens = result [<%- place.id %>],
            }
          end
        <% end %>
        return Marking.unique (result)
      end
      local mt = getmetatable (transitions [<%- transition.id %>]) or {}
      mt.__call = function (_, marking)
        return transition_<%- transition.id %> (marking)
      end
      setmetatable (transitions [<%- transition.id %>], mt)
      Marking ["<%- transition.name %>"] = transition_<%- transition.id %>
    ]=], environment)
    environment.transition = nil
    load (code, transition.name, "t", environment) ()
  end

  do
    local code = Et.render ([=[
      Marking.reachable = function (marking)
        local explored    = {}
        local encountered = {
          [marking] = true
        }
        while next (encountered) do
          local marking = next (encountered)
          encountered [marking] = nil
          explored    [marking] = true
          <% for _, transition in ipairs (transitions) do %>
          do
            local successor = transitions [<%- transition.id %>] (marking)
            if successor then
              marking [transitions [<%- transition.id %>]] = successor
              if not explored [successor] then
                encountered [successor] = true
              end
            end
          end
          <% end %>
        end
        return explored
      end
    ]=], environment)
    load (code, "reachable", "t", environment) ()
  end

  do
    local code = Et.render ([=[
      Marking.bound = function (marking, markings)
        markings = markings or Marking.reachable (from)
        local bound    = {
          <% for _, place in ipairs (places) do %>
          [<%- place.id %>] = {
            minimum = math.huge,
            maximum = 0,
          },
          <% end %>
        }
        for marking in pairs (markings) do
          <% for _, place in ipairs (places) do %>
          bound [<%- place.id %>].minimum = math.min (bound [<%- place.id %>].minimum, marking [<%- place.id %>])
          bound [<%- place.id %>].maximum = math.max (bound [<%- place.id %>].maximum, marking [<%- place.id %>])
          <% end %>
        end
        return bound
      end
    ]=], environment)
    load (code, "bound", "t", environment) ()
  end

  do
    local code = Et.render ([=[
    ]=], environment)
    load (code, "tarjan", "t", environment) ()
  end

  do
    local code = Et.render ([=[
      local function tarjan (initial, markings)
        markings = markings or Marking.reachable (initial)
        local id        = 0
        local stack     = {}
        local partition = {}
        local function walk (marking)
          stack [#stack+1] = marking
          marking.tarjan   = {
            id       = id,
            rid      = id,
            in_stack = true,
          }
          id = id + 1
          <% for _, transition in ipairs (transitions) do %>
          do
            local successor = marking [transitions [<%- transition.id %>]]
            if successor and not successor.tarjan then
              walk (successor)
              marking.tarjan.rid = math.min (marking.tarjan.rid, successor.tarjan.rid)
            elseif successor and successor.tarjan and successor.tarjan.in_stack then
              marking.tarjan.rid = math.min (marking.tarjan.rid, successor.tarjan.id)
            end
          end
          <% end %>
          if marking.tarjan.rid == marking.tarjan.id then
            local component = {}
            repeat
              local element = stack [#stack]
              element.tarjan.in_stack  = false
              element.tarjan.component = component
              component [element] = true
              stack [#stack] = nil
            until element == marking
            partition [#partition+1] = component
          end
        end
        for marking in pairs (markings) do
          if not marking.tarjan then
            walk (marking)
          end
        end
        return partition
      end
      Marking.liveness = function (marking, markings)
        markings         = markings or Marking.reachable (from)
        local components = tarjan (marking, markings)
        <% for _, transition in ipairs (transitions) do %>
        do
          local transition    = transitions [<%- transition.id %>]
          transition.liveness = {
            l0 = true,
            l1 = false,
            l2 = false,
            l3 = false,
            l4 = true,
          }
          for marking in pairs (markings) do
            if marking [transition] then
              transition.liveness.l0 = false
              transition.liveness.l1 = true
            else
              transition.liveness.l4 = false
            end
          end
          for _, component in ipairs (components) do
            local is_final = true
            for marking in pairs (component) do
              if  marking [transition]
              and marking [transition].tarjan.component == component then
                transition.liveness.l2 = true
              end
              is_final = is_final and function ()
                <% for _, transition in ipairs (transitions) do %>
                do
                  local t = transitions [<%- transition.id %>]
                  local s = marking [t]
                  if s and s.tarjan.component ~= component then
                    return false
                  end
                end
                <% end %>
              end
            end
            transition.liveness.l3 = is_final and transition.liveness.l2
          end
        end
        <% end %>
        return transitions
      end
    ]=], environment)
    load (code, "liveness", "t", environment) ()
  end

  local function analysis ()
    local result = {
      reachability = {
        duration = nil,
        markings = nil,
        size     = nil,
      },
      bound = {
        duration = nil,
        marking  = nil,
      },
      liveness = {
        duration    = nil,
        transitions = nil,
      }
    }
    do
      local start = Gettime ()
      result.reachability.markings = Marking.reachable (Marking.initial)
      result.reachability.duration = Gettime () - start
      local size = 0
      for _ in pairs (result.reachability.markings) do
        size = size + 1
      end
      result.reachability.size = size
    end
    do
      local start = Gettime ()
      result.bound.marking  = Marking.bound (Marking.initial, result.reachability.markings)
      result.bound.duration = Gettime () - start
      for _, place in pairs (places) do
        place.bound = result.bound.marking [place.id]
      end
    end
    do
      local start = Gettime ()
      result.liveness.transitions = Marking.liveness (Marking.initial, result.reachability.markings)
      result.liveness.duration    = Gettime () - start
    end
    return result
  end

  return {
    places      = places,
    transitions = transitions,
    marking     = Marking.named,
    initial     = Marking.initial,
    empty       = Marking.empty,
    analysis    = analysis,
  }
end
