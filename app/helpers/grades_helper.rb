module GradesHelper

  # E.g. the float 0.5 would return 50% as a string
  def as_percent(decimal_value)
    number_to_percentage(decimal_value * 100, precision: 0)
  end

end
