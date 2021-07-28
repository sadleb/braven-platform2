# Add custom utility functions to the String class here.
class String

  # Returns a copy of str with all whitespace deleted. E.g.
  # " blah\n foo ".delete_whitespace #=> "blahfoo"
  def delete_whitespace
    self.gsub(/\s+/, '')
  end
end
