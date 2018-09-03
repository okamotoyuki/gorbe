module Gorbe
  module Compiler

    # A class which stands an expression in generated Go code.
    class Expr
      attr_reader :name
      attr_reader :type
      attr_reader :expr

      def initialize(block: nil, name: '', type: nil, expr: nil)
        @block = block
        @name = name
        @type = type
        @expr = expr
      end

      def free
      end
    end

    # A class which stands an expression result stored in a temporary value.
    class TempVar < Expr
      def initialize(block: nil, name: '', type: nil)
        super(block: block, name: name, type: type, expr: name)
      end

      def free
        @block.free_temp_var(self)
      end
    end

    # A class which stands Go local var corresponding to a Python local.
    class LocalVar < Expr
      def initialize(name: '')
        super(name: name, expr: Util::get_go_identifier(name))
      end
    end

    # A class which stands a literal in generated Go code.
    class Literal < Expr
      def initialize(expr: nil)
        super(expr: expr)
      end

    end

    class ExprVisitor < Visitor

      BIN_OP_TEMPLATES = {
          :& => lambda { |lhs, rhs| "πg.And(πF, #{lhs}, #{rhs})" },
          :| => lambda { |lhs, rhs| "πg.Or(πF, #{lhs}, #{rhs})" },
          :^ => lambda { |lhs, rhs| "πg.Xor(πF, #{lhs}, #{rhs})" },
          :+ => lambda { |lhs, rhs| "πg.Add(πF, #{lhs}, #{rhs})" },
          :/ => lambda { |lhs, rhs| "πg.Div(πF, #{lhs}, #{rhs})" },
          # :// => lambda { |lhs, rhs | "πg.FloorDiv(πF, #{lhs}, #{rhs})" },
          :<< => lambda { |lhs, rhs| "πg.LShift(πF, #{lhs}, #{rhs})" },
          :% => lambda { |lhs, rhs| "πg.Mod(πF, #{lhs}, #{rhs})" },
          :* => lambda { |lhs, rhs| "πg.Mul(πF, #{lhs}, #{rhs})" },
          :** => lambda { |lhs, rhs| "πg.Pow(πF, #{lhs}, #{rhs})" },
          :>> => lambda { |lhs, rhs| "πg.RShift(πF, #{lhs}, #{rhs})" },
          :- => lambda { |lhs, rhs| "πg.Sub(πF, #{lhs}, #{rhs})" }
      }

      def initialize(stmt_visitor)
        super(block: stmt_visitor.block, parent: stmt_visitor, writer:  stmt_visitor.writer, nodetype_map:
            {
                binary: 'binary',
                var_ref: 'var_ref',
                '@int': 'int'
            }
        )
      end

      def visit_binary(node)
        log_activity(__method__.to_s)

        # e.g. [:binary, [:@int, "1", [1, 0]], :+, [:@int, "1", [1, 4]]]
        raise unless node.length == 4 # TODO : Raise an appropriate exception

        lhs = self.visit(node[1])&.expr
        operator = node[2]
        rhs = self.visit(node[3])&.expr
        raise unless lhs && rhs # TODO : Raise an appropriate exception

        result = @block.alloc_temp_var()

        if BIN_OP_TEMPLATES.has_key?(operator) then
          call = BIN_OP_TEMPLATES[operator].call(lhs, rhs)
          @writer.write_checked_call2(result.name, call)
        else
          Gorbe.logger.error("The operator '#{operator}' is not supported." +
                                 'Please contact us via https://github.com/OkamotoYuki/gorbe/issues.')
          Gorbe.logger.debug(node)
          raise # TODO : Raise an appropriate exception
        end

        return result
      end

      def visit_var_ref(node)
        log_activity(__method__.to_s)

        # e.g. [:var_ref, [:@kw, "true", [1, 0]]]
        raise unless node.length == 2 # TODO : Raise an appropriate exception

        kw = visit_kw(node[1])
        return @block.resolve_name(@writer, kw)
      end

      def visit_kw(node)
         log_activity(__method__.to_s)

        # e.g. [:@kw, "true", [1, 0]]
        raise unless node.length == 3 # TODO : Raise an appropriate exception

        return node[1]
      end

      def visit_int(node)
        log_activity(__method__.to_s)

        # e.g. [:@int, "1", [1, 0]]
        raise unless node.length == 3 # TODO : Raise an appropriate exception

        expr_str = "NewInt(%d)" % node[1]
        return Literal.new(expr: 'πg.' + expr_str + '.ToObject()')
      end
    end

  end
end
