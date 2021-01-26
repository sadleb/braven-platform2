module ApplicationHelper
  def nav_link label, url, options={}
    options[:feather] ||= 'arrow-right-circle'
    
    text = "<span data-feather=\"#{options[:feather]}\"></span> #{label}".html_safe

    html_class = 'nav-link'
    
    if (options[:controller] ? (controller.controller_path == options[:controller]) : current_page?(url))
      html_class += ' active'
    end
    
    html_class += " #{controller.controller_path}"
    
    link_to(text, url, class: html_class)
  end
  
  def previous_page collection
    "#{request.base_url}#{request.path}?page=#{collection.previous_page}"
  end
  
  def next_page collection
    "#{request.base_url}#{request.path}?page=#{collection.next_page}"
  end
  
  # Converts Rails flash message types to Bootstrap CSS classes found here:
  # https://getbootstrap.com/docs/4.0/components/alerts/
  def alert_css_class(flash_message_type)
    case flash_message_type.to_sym
    when :notice
      'alert-success'
    when :alert
      'alert-danger'
    else
      Rails.logger.warn("Undefined Rails flash message type converted to alert-primary CSS style: '#{flash_message_type}'")
      'alert-primary'
    end
  end

  # https://www.w3schools.com/tags/att_option_selected.asp
  def option_selected(condition)
    condition == true ? 'selected' : ''
  end

  # https://www.w3schools.com/tags/att_input_checked.asp
  def input_checked(condition)
    condition == true ? 'checked' : ''
  end
end
