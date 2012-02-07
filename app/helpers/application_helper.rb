module ApplicationHelper
  def google_maps_javascript_include_tag
    javascript_include_tag(raw("http://maps.googleapis.com/maps/api/js?sensor=false&key=#{GoogleMapsKey}"))
  end

  def ko_link_to(text, click, options = {})
    link_to text, 'javascript:void()', options.merge(ko :click => click)
  end

  def ko_link_to_root(text, click, optinos = {})
    ko_link_to text, "$root.#{click}", options
  end

  def ko_text_field_tag(name, options = {})
    text_field_tag name, '', ko(options.reverse_merge(:value => name, :valueUpdate => "'afterkeydown'"))
  end

  def ko_check_box_tag(name, options = {})
    check_box_tag name, '1', false, options.reverse_merge(ko :checked => name)
  end

  def ko(hash = {})
    {'data-bind' => kov(hash)}
  end

  def kov(hash = {})
    hash.map{|k, v| "#{k}:#{v}"}.join(',')
  end
end
