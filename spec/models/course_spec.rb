require 'rails_helper'

RSpec.describe Course, type: :model do
  let(:course) { build(:course) }
  
  describe '#save' do

    context 'when course name has extra whitespace' do
      it 'strips away the whitespace in name' do
        course.name = "  #{course.name}  "
        course.save!
        expect(course.name).to eq(course.name.strip)
      end

      it 'strips away the whitespace in term' do
        course.term = "  #{course.term}  "
        course.save!
        expect(course.term).to eq(course.term.strip)
      end
    end
  end

  describe '#valid?' do
    let(:term_name) { 'Term Name' }
    let(:course_name) { 'Course Name' }
    let(:course) { build(:course, name: course_name, term: term_name)}
    subject { course }

    context 'when course name is empty' do
      let(:course_name) { '' }
      it { is_expected.to_not be_valid }
    end

    context 'when term name is empty' do
      let(:term_name) { '' }
      it { is_expected.to_not be_valid }
    end
  end
end
