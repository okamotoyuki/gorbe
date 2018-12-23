class Foo
  def initialize(n)
    p(n)
  end

  def bar(n)
    p(n)
  end
end

foo = Foo.new(1)
foo.bar(2)
