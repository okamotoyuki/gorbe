require 'gorbe/compiler/expr'

module Gorbe
  module Compiler

    # A class which generates Go code based on Ruby AST (Statement).
    class StatementVisitor < Visitor

      def initialize(block)
        super(block: block, writer: Writer.new, nodetype_map:
            {
                array: 'expr',
                assign: 'assign',
                hash: 'expr',
                program: 'program',
                void_stmt: 'void_stmt',
                binary: 'expr',
                unary: 'expr',
                '@ident': 'ident',
                '@int': 'expr',
                '@float': 'expr',
                var_field: 'var_field',
                var_ref: 'expr',
                string_literal: 'expr',
                if: 'branch',
                if_mod: 'branch',
                elsif: 'branch',
                unless: 'branch',
                unless_mod: 'branch',
                else: 'else'
            }
        )
        @expr_visitor = Compiler::ExprVisitor.new(self)
      end

      def visit_program(node)
        log_activity(__method__.to_s)

        # e.g. [:program, [[:void_stmt]]]
        raise CompileError.new(node, msg: 'Node size must be more than 1.') unless node.length > 1

        children = node.slice(1..-1)
        children.each do |child|
          visit(child)
        end
      end

      def visit_assign(node)
        log_activity(__method__.to_s)

        # e.g. [:assign, [:var_field, [:@ident, "foo", [1, 0]]], [:@int, "1", [1, 6]]]
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        with(value: visit(node[2])) do |temps|
          target = visit(node[1])
          @block.bind_var(@writer, target, temps[:value].expr)
        end
      end

      def visit_expr(node)
        log_activity(__method__.to_s)
        return @expr_visitor.visit(node)
      end

      def visit_ident(node)
        log_activity(__method__.to_s)

        # e.g. [:@ident, "foo", [1, 0]]
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        return node[1]
      end

      def visit_var_field(node)
        log_activity(__method__.to_s)

        # e.g. [:var_field, [:@ident, "foo", [1, 0]]]
        raise CompileError.new(node, msg: 'Node size must be 2.') unless node.length == 2

        return visit(node[1])
      end

      def visit_void_stmt(node)
        # Do nothing
      end

      def visit_branch(node, **args)
        log_activity(__method__.to_s)

        # e.g. [:if, [:var_ref, [:@kw, "true", [1, 3]]], [[:@int, "1", [2, 2]]],
        #       [:elsif, [:var_ref, [:@kw, "false", [3, 6]]], [[:@int, "2", [4, 2]]],
        #       [:else, [[:@int, "3", [6, 2]]]]]]
        #
        #      [:if_mod, [:var_ref, [:@kw, "true", [9, 5]]], [:@int, "1", [9, 0]]]
        raise CompileError.new(node, msg: 'Node size must be 4.') unless node.length == 3 || node.length == 4

        # 'if'/'unless'/'else'/'elsif' bodies
        bodies = args[:bodies].nil? ? [] : args[:bodies]

        label = -1  # Initialize label
        # 'if'/'unless' condition
        with(cond: visit(node[1])) do |cond_temps|
          label = @block.gen_label
          case node[0]

          # Set method name depending on the branch type
          when :if, :elsif, :if_mod then
            is_not = false
          when :unless, :unless_mod then
            is_not = true
          else
            raise CompileError.new(node, msg: 'Unsupported branch node.')
          end

          with(is_true: @block.alloc_temp('bool')) do |true_temps|
            template = <<~EOS
              if #{true_temps[:is_true].expr}, πE = πg.IsTrue(πF, #{cond_temps[:cond].expr}); πE != nil {
              \tcontinue
              }
              if #{is_not ? '!' : ''}#{true_temps[:is_true].expr} {
              \tgoto Label#{label}
              }
            EOS
            @writer.write(template)
          end
        end
        bodies.push([label, node[2]])

        if node[3].nil? # If there is no 'else' statement
          end_label = @block.gen_label

          # Write labels and bodies
          bodies.each do |body|
            @writer.write_label(body[0])
            visit(body[1])
            @writer.write("goto Label%d" % end_label)
          end
          @writer.write_label(end_label)
        else # If there is 'elsif' or 'else' statement
          visit(node[3], bodies: bodies)
        end
      end

      def visit_else(node, **args)
        log_activity(__method__.to_s)

        # e.g. [:else, [[:@int, "3", [6, 2]]]]
        raise CompileError.new(node, msg: 'Node size must be 2.') unless node.length == 2

        # 'if'/'else'/'elsif' bodies
        bodies = args[:bodies]
        default_label = @block.gen_label
        bodies.push([default_label, node[1]])
        end_label = @block.gen_label

        # Write labels and bodies
        bodies.each do |body|
          @writer.write_label(body[0])
          visit(body[1])
          @writer.write("goto Label%d" % end_label)
        end
        @writer.write_label(end_label)
      end

    end
  end
end
