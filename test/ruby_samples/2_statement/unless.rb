unless true
  p(1)
end

unless false
  p(2)
end

foo = 0
unless true then
  foo = 3
else
  foo = 4
end
p(foo)

p(5) unless true
p(6) unless false