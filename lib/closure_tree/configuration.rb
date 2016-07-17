module ClosureTree
  class Configuration # :nodoc:
    attr_accessor :database_less

    def initialize
      @database_less = ENV['DATABASE_URL'].to_s.include?('//user:pass@127.0.0.1/')
    end
  end
end
