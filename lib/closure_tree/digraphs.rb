module ClosureTree
  module Digraphs
    extend ActiveSupport::Concern

    def to_dot_digraph
      self.class.to_dot_digraph(self_and_descendants)
    end

    # override this method in your model class if you want a different digraph label.
    def to_digraph_label
      _ct.has_name? ? read_attribute(_ct.name_column) : to_s
    end

    module ClassMethods
      # Renders the given scope as a DOT digraph, suitable for rendering by Graphviz
      def to_dot_digraph(tree_scope)
        id_to_instance = tree_scope.reduce({}) { |h, ea| h[ea.id] = ea; h }
        output = StringIO.new
        output << "digraph G {\n"
        tree_scope.each do |ea|
          if id_to_instance.key? ea._ct_parent_id
            output << "  \"#{ea._ct_parent_id}\" -> \"#{ea._ct_id}\"\n"
          end
          output << "  \"#{ea._ct_id}\" [label=\"#{ea.to_digraph_label}\" #{extra_attributes(ea)}]\n"
        end
        output << "}\n"
        output.string
      end

      def extra_attributes ea
        if ea.respond_to? :to_digraph_extra_attributes
          attributes_hash = ea.to_digraph_extra_attributes
          attributes_hash.map { |key, value| "#{key.to_s}=\"#{value.to_s}\"" }.join(" ")
        else
          ""
        end
      end
    end
  end
end
