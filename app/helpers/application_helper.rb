module ApplicationHelper
  def resource_name
    :admin
  end

  def resource
    @resource ||= Admin.new
  end

  def devise_mapping
    @devise_mapping ||= Devise.mappings[:admin]
  end

  def build_control(f, object, help_object, attribute, control_type, options = nil)
    content_tag(:div, class: "form-group") do
      build_label(f, object, attribute, options) +
      build_control_error(f, object, help_object, attribute, control_type, options)
    end
  end

  def build_control_error(f, object, help_object, attribute, control_type, options = nil)
    content_tag :div, class: "col-md-5" do
      build_specific_control(f, object, attribute, control_type, options).html_safe +
      content_tag(:div, object.errors[attribute.to_sym].join(","), class: "field_with_errors")
    end
  end

   def build_label(f, object, attribute, options = nil)
    if options && options[:label]
      f.label(attribute, options[:label], class: 'control-label col-md-3')
    else
      f.label(attribute, class: 'control-label col-md-3')
    end
  end

  def build_specific_control(f, object, attribute, control_type, options = nil)
    case control_type
    when 'text'
      build_text_field(f, object, attribute, options)
    when 'text_area'
      build_text_area(f, object, attribute, options)
    when 'date'
      build_date_field(f, object, attribute, options)
    when 'datetime'
      build_datetime_field(f, object, attribute, options)
    when 'password'
      f.password_field(attribute)
    when 'select'
      build_select_box(f, attribute, options[:select_list])
    when 'check_box'
      f.check_box(attribute)
    when 'radio_buttons'
      build_radio_buttons(f, attribute, options)
    end
  end

  def build_text_field(f, object, attribute, options = nil)
    if options && options[:precision]
      f.text_field(attribute, value: number_with_precision(f.object[attribute.to_sym],
        precision: options[:precision], delimiter: ','), class: "form-control")
    else
      f.text_field(attribute, class: "form-control")
    end
  end

  def build_text_area(f, object, attribute, options = nil)
    if options && options[:rows]
      f.text_area(attribute, rows: options[:rows], class: "form-control")
    else
      f.text_area(attribute, rows: '3', class: "form-control")
    end
  end

  def build_date_field(f, object, attribute, options = nil)
    formatted_date = object.send(attribute).strftime("%m/%d/%Y") if object.send(attribute)
    f.text_field(attribute, value: formatted_date,
      placeholder: "mm/dd/yyyy", class: "form-control")
  end

  def build_datetime_field(f, object, attribute, options = nil)
    formatted_datetime = object.send(attribute).strftime("%m/%d/%Y %I:%M %P") if object.send(attribute)
    f.text_field(attribute, value: formatted_datetime,
      placeholder: "mm/dd/yyyy", class: "form-control" )
  end

  def build_select_box(f, attribute, select_list)
    f.select(attribute, select_list.collect {|item| [item, item]})
  end

  def build_radio_buttons(f, attribute, options)
    options[:values_list].inject("") do |control, value|
      control << content_tag(:label, f.radio_button(attribute, value) + " #{value}", class: "radio")
      control
    end
  end

  def user_friendly_value(value)
    if value.is_a?(Boolean)
      value ? "Yes" : "No"
    else
      value
    end
  end

end
