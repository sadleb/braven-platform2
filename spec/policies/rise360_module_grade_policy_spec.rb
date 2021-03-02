require 'rails_helper'

RSpec.describe Rise360ModuleGradePolicy, type: :policy do
  let(:user) { create(:registered_user) }
  let(:course) { create(:course) }
  let(:section) { create(:section, course: course) }
  let(:ta_section) { create(:ta_section, course: course) }
  let(:course_rise360_module_version) {
    create( :course_rise360_module_version, course: course)
  }
  let(:rise360_module_grade) {
    create(:rise360_module_grade,
      user: user,
      course_rise360_module_version: course_rise360_module_version
    )
  }

  subject { described_class }

  permissions :show? do
    it "allows any admin user to show a given module grade" do
      user.add_role :admin
      expect(subject).to permit user, rise360_module_grade
    end

    it "allows an lc user to show a module grade from one of their students" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      ta_user = create(:registered_user)
      ta_user.add_role RoleConstants::TA_ENROLLMENT, section
      expect(subject).to permit ta_user, rise360_module_grade
    end

    it "allows a ta user to show a module grade" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      ta_user = create(:registered_user)
      ta_user.add_role RoleConstants::TA_ENROLLMENT, ta_section
      expect(subject).to permit ta_user, rise360_module_grade
    end

    it "allows users to see their own grade" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit user, rise360_module_grade
    end

    it "disallows TAs from other courses" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      another_course = create(:course)
      ta_user = create(:registered_user)
      ta_section = create(:ta_section, course: another_course)
      ta_user.add_role RoleConstants::TA_ENROLLMENT, ta_section
      expect(subject).not_to permit ta_user, rise360_module_grade
    end

    it "disallows LCs from other sections in course" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      another_section = create(:section, course: course)
      lc_user = create(:registered_user)
      lc_user.add_role RoleConstants::TA_ENROLLMENT, another_section
      expect(subject).not_to permit lc_user, rise360_module_grade
    end

    it "disallows users to see grades from another student in their section" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      peer_user = create(:registered_user)
      peer_user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).not_to permit peer_user, rise360_module_grade
    end

    it "disallows non-admin users not enrolled in a course attached to the grade" do
      not_enrolled_user = create(:registered_user)
      expect(subject).not_to permit not_enrolled_user, rise360_module_grade
    end
  end

end
