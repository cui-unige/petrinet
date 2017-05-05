local Xml = require "xml"

return function (path)
  local places      = {}
  local transitions = {}
  local data   = Xml.loadpath (path)
  assert (data.xml == "pnml")
  for _, net in ipairs (data) do
    if net.xml == "net" then
      for _, page in ipairs (net) do
        if page.xml == "page" then
          for _, element in ipairs (page) do
            if element.xml == "place" then
              local name    = element.id
              local marking
              for _, x in ipairs (element) do
                if x.xml == "initialMarking" then
                  local text = x [1]
                  assert (text.xml == "text")
                  marking = tonumber (text [1])
                end
              end
              places [name] = {
                type    = "place",
                initial = marking,
              }
            end
          end
          for _, element in ipairs (page) do
            if element.xml == "transition" then
              local name    = element.id
              transitions [name] = {
                type = "transition",
                pre  = {},
                post = {},
              }
            end
          end
        end
      end
    end
  end
  for _, net in ipairs (data) do
    if net.xml == "net" then
      for _, page in ipairs (net) do
        if page.xml == "page" then
          for _, element in ipairs (page) do
            if element.xml == "arc" then
              local value = 1
              for _, x in ipairs (element) do
                if x.xml == "inscription" then
                  local text = x [1]
                  assert (text.xml == "text")
                  value = tonumber (text [1])
                end
              end
              if transitions [element.target] then
                local transition = transitions [element.target]
                transition.pre  [element.source] = value
              elseif transitions [element.source] then
                local transition = transitions [element.source]
                transition.post [element.target] = value
              else
                assert (false)
              end
            end
          end
        end
      end
    end
  end
  local result = {}
  for name, place in pairs (places) do
    result [name] = place
  end
  for name, transition in pairs (transitions) do
    result [name] = transition
  end
  return result
end
