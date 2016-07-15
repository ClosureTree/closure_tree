module ClosureTree
  class Configuration # :nodoc:
    attr_accessor :database_less

    def initialize
      @database_less = false
    end
  end
end
