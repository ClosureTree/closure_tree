module ClosureTree
  module Rebuild
    class Pg
      def initialize(table, hierarchies_table_name, options = {})
        @table = table
        @hierarchies_table_name = hierarchies_table_name.to_sym
        @options = options
      end

      def rebuild(db)
        io = StringIO.new
        write_header(io)
        chains.each do |row|
          io.write([row.size].pack('n'))
          row.each { |v| write_integer(v, io) }
          yield if block_given?
        end
        write_close(io)
        copy(db, io)
      end

      def chains
        @chains ||= ClosureTree::Rebuild::Chains.new(
          @table, @hierarchies_table_name, @options
        ).chains
      end

      private

      def write_integer(value, io)
        buf = [value].pack('N')
        io.write([buf.bytesize].pack('N'))
        io.write(buf)
      end

      def write_header(io)
        io.write("PGCOPY\n\377\r\n\0")
        io.write([0, 0].pack('NN'))
      end

      def write_close(io)
        io.write([-1].pack('n'))
        io.rewind
      end

      def copy(db, io)
        db[@hierarchies_table_name].truncate
        db.run('SET client_min_messages TO warning;')
        db.copy_into(
          @hierarchies_table_name,
          columns: COLUMNS, format: :binary, data: io.read
        )
      end

      COLUMNS = [:ancestor_id, :descendant_id, :generations]
    end
  end
end
