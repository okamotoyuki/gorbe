module Gorbe
  module Compiler

    class Util
      def self.generate_go_str(value)
        return value.inspect.gsub(/\\\\/, '\\')
      end

      def self.get_go_identifier(name)
        return 'µ' + name
      end
    end

  end
end