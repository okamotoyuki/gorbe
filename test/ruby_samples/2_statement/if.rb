if true
  p(1)
end

if false
  p(2)
end

foo = 0
if true then
  foo = 3
elsif false then
  foo = 4
else
  foo = 5
end
p(foo)

p(6) if true
p(7) if false
