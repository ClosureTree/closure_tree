class Hash
  def render_from_yield(&block)
    reduce({}) do |h, entry|
      k, v = entry
      h[block.call(k)] = if v.is_a?(Hash) then
        v.render_from_yield(&block)
      else
        block.call(v)
      end
      h
    end
  end
end
