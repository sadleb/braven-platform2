class Course < Program
  before_validation do
    name.strip!
    term.strip!
  end

  validates_presence_of :term
end
