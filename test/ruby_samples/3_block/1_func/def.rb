def foo(n)
  p(n)
end

def bar(n)
  foo(n + 1)
end

bar(0)
bar(1)
bar(2)
bar(3)
bar(4)

