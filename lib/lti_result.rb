# Represents the Result object returned from the LtiAdvantage API.
#
# See: https://canvas.instructure.com/doc/api/result.html
class LtiResult
  attr_reader :raw_result, :resultScore, :resultMaximum

  def initialize(raw_result)
    @raw_result = raw_result
    if present?
      @resultScore= Float(@raw_result['resultScore'], exception: false)
      @resultMaximum = Float(@raw_result['resultMaximum'], exception: false)
    end
  end

  def present?
    @raw_result.present?
  end

  def has_full_credit?
    present? && @resultScore == @resultMaximum
  end

  def ==(other)
    @raw_result == other.raw_result
  end
end
