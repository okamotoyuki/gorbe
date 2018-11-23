foo = 0
unless true then
  foo = 1
else
  foo = 2
end
p(foo)
p(1) unless true
p(1) unless false