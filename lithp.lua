#!/usr/bin/env lua
local lpeg = require'lpeg'
local argparse = require 'argparse'
local pretty = require'pl.pretty'
local P, R, S = lpeg.P, lpeg.R, lpeg.S --patterns
-- S for single char from choices, R for range, P for pattern
local C, Ct = lpeg.C, lpeg.Ct --capture
--Ct returns a table with all captures from patt
--C returns the match for patt plus all captures made by patt
local V = lpeg.V --variable
-- ^n matches n or more, and A * B matches A and then B
-- A + B is an ordered choice
local parser = P { --because we are passing a table, it is a grammar
  'program', -- initial rule
  program   = Ct(V'sexpr' ^ 0),
  wspace    = S' \n\r\t' ^ 0,
  atom      = V'boolean' + V'float' + V'integer' + V'string' + V'symbol',
    symbol  = C((1 - S' \n\r\t"\'()[]{}#@~') ^ 1) /
              function(s) return _G[s] end,
    boolean = C(P'true' + P'false') /
              function(x) return x == 'true' end,
    float   = C(((P'0' + (R'19' * R'09'^0)) * P'.' * R'09'^1)) / tonumber,
    integer = C(R'19' * R'09'^0) / tonumber,
    string  = P'"' * C((1 - S'"\n\r') ^ 0) * P'"',
  coll      = V'list' + V'array',
    list    = P'\'(' * Ct(V'expr' ^ 1) * P')',
    array   = P'[' * Ct(V'expr' ^ 1) * P']',
  expr      = V'wspace' * (V'coll' + V'atom' + V'sexpr'),
  sexpr     = V'wspace' * P'(' * V'symbol' * Ct(V'expr' ^ 0) * P')' /
              function(f, ...) return f(...) end
}

--some "built-ins"
reduce = function(f, list)
  for i, v in ipairs(list) do
    if i == 1 then
      head = v
    else
      head = f(head, v)
    end
  end
  return head
end

def = function(k, v) _G[k] = v end
def('+',   function(...) return reduce(function(a, b) return a + b end, ...) end)
def('-',   function(...) return reduce(function(a, b) return a - b end, ...) end)
def('*',   function(...) return reduce(function(a, b) return a * b end, ...) end)
def('/',   function(...) return reduce(function(a, b) return a / b end, ...) end)
def('%',   function(...) return reduce(function(a, b) return a % b end, ...) end)
def('str', function(...) return reduce(function(a, b) return tostring(a)..tostring(b) end, ...) end)
def('not', function(a) return not a end)

function file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

local function read_file(path)
    local file = io.open(path, "r") -- r read mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

local argparser = argparse("lithp", "A simple lisp written with lpeg")
argparser:option("-f --file", "Input file.")
argparser:option("-s --string", "Input string.")

local args = argparser:parse()
if args['file'] ~= nil and file_exists(args['file']) then
  pretty.dump(parser:match(read_file(args['file'])))
elseif args['string'] ~= nil then
  pretty.dump(parser:match(args['string']))
end