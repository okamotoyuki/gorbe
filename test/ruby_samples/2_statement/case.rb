foo = 1
case foo
when 1, 2, 3 then
  bar = 4
when 5, 6 then
  bar = 7
else
  bar = 8
end
p(bar)
