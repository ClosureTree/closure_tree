require 'closure_tree'

module ClosureTree
  module Test
    module Matcher
      def be_a_closure_tree
        ClosureTree.new
      end

      class ClosureTree
        def matches?(subject)
          @subject = subject.is_a?(Class) ? subject : subject.class
          # OPTIMIZE
          if @subject.respond_to?(:_ct)

            unless @subject.column_names.include?(@subject._ct.parent_column_name)
              @message = "expected #{@subject.name} to respond to #{@subject._ct.parent_column_name}"
              return false
            end

            # Checking if hierarchy table exists (common error)
            unless  @subject.hierarchy_class.table_exists?
              @message = "expected #{@subject.name}'s hierarchy table '#{@subject.hierarchy_class.table_name}' to exist"
              return false
            end

            if @ordered
              unless  @subject._ct.options.include?(:order)
                @message = "expected #{@subject.name} to be an ordered closure tree"
                return false
              end
              unless @subject.column_names.include?(@subject._ct.options[:order].to_s)
                @message = "expected #{@subject.name} to have #{@subject._ct.options[:order]} as column"
                return false
              end
            end

            if @with_advisory_lock && !@subject._ct.options[:with_advisory_lock]
                @message = "expected #{@subject.name} to have advisory lock"
                return false
            end

            if @without_advisory_lock && @subject._ct.options[:with_advisory_lock]
                @message = "expected #{@subject.name} to not have advisory lock"
                return false
            end

            return true
          end
          false
        end

        def ordered(column = nil)
          @ordered = 'n ordered'
          @order_colum = column
          self
        end

        def with_advisory_lock
          @with_advisory_lock = ' with advisory lock'
          self
        end

        def without_advisory_lock
          @without_advisory_lock = ' without advisory lock'
          self
        end

        def failure_message
          @message || "expected #{@subject.name} to #{description}"
        end

        alias_method :failure_message_for_should, :failure_message

        def failure_message_when_negated
          "expected #{@subject.name} not be a closure tree, but it is."
        end

        alias_method :failure_message_for_should_not, :failure_message_when_negated

        def description
          "be a#{@ordered} closure tree#{@with_advisory_lock}"
        end
      end
    end
  end
end

RSpec.configure do |c|
  c.include ClosureTree::Test::Matcher, type: :model
end
