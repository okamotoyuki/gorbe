foo = 0
if true then
  foo = 1
elsif false then
  foo = 2
else
  foo = 3
end
p(foo)
p(1) if true
p(1) if false