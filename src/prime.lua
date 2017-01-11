#! /usr/bin/env lua

local Serpent = require "serpent"
local primes  = {}
for line in io.lines "primes.txt" do
  for prime in line:gmatch "%S+" do
    primes [#primes+1] = tonumber (prime)
  end
end
print (Serpent.dump (primes))
