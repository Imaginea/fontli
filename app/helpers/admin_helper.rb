module AdminHelper
  def sortable(column, title = nil)
    title ||= column.titleize
    css_class = column == sort_column ? "current #{sort_direction}" : nil
    direction = column == sort_column && sort_direction == 'asc' ? 'desc' : 'asc'
    link_to title, params.merge(sort: column, direction: direction), class: css_class
  end

  def valid_string(name)
    name.to_s.chars.select(&:valid_encoding?).join
  end

  def active_class(*actions)
    'active' if actions.include?(params[:action])
  end
end
