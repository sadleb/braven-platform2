class Section < ApplicationRecord

  belongs_to :program
  belongs_to :logistic

  before_validation { name.try(:strip!) }

  has_many :user_sections
  has_many :users, through: :user_sections do
    def only_fellows
      merge(UserSection.enrolled)
    end

    def only_lcs
      merge(UserSection.facillitates)
    end

    def only_tas
      merge(UserSection.assists)
    end
  end
end
