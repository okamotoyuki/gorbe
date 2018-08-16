module Gorbe
  module Compiler

    class ExprVisitor < Visitor

      BIN_OP_TEMPLATES = {
          :& => 'πg.And(πF, {lhs}, {rhs})',
          :| => 'πg.Or(πF, {lhs}, {rhs})',
          :^ => 'πg.Xor(πF, {lhs}, {rhs})',
          :+ => 'πg.Add(πF, {lhs}, {rhs})',
          :/ => 'πg.Div(πF, {lhs}, {rhs})',
          # :// => 'πg.FloorDiv(πF, {lhs}, {rhs})',
          :<< => 'πg.LShift(πF, {lhs}, {rhs})',
          :% => 'πg.Mod(πF, {lhs}, {rhs})',
          :* => 'πg.Mul(πF, {lhs}, {rhs})',
          :** => 'πg.Pow(πF, {lhs}, {rhs})',
          :>> => 'πg.RShift(πF, {lhs}, {rhs})',
          :- => 'πg.Sub(πF, {lhs}, {rhs})'
      }

      def initialize(stmt_visitor)
        super(parent: stmt_visitor, writer:  stmt_visitor.writer, nodetype_map:
            {
                binary: 'binop',
                '@int': 'int'
            }
        )
      end

      def visit_binop(node)
        log_activity(__method__.to_s)

        raise if node.length != 4 # TODO : Raise an appropriate exception

        lhs = node[1]
        operator = node[2]
        rhs = node[3]

        if BIN_OP_TEMPLATES.has_key?(operator) then
          template = BIN_OP_TEMPLATES[operator]
        else
          Gorbe.logger.error("The operator '#{operator}' is not supported." +
                                 'Please contact us via https://github.com/OkamotoYuki/gorbe/issues.')
          Gorbe.logger.debug(node)
          raise # TODO : Raise an appropriate exception
        end

        #if operator in
      end

      def visit_int(node)
        log_activity(__method__.to_s)
      end
    end

  end
end
