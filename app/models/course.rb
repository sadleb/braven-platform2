class Course < Program
  has_many :grade_categories
  has_many :projects, :through => :grade_categories
  has_many :lessons, :through => :grade_categories  

  before_validation do
    name.strip!
    term.strip!
  end

  validates_presence_of :term
end
