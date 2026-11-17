# Value object representing a normalized 5-digit US ZIP code.
class ZipCode < Data.define(:value)
  PATTERN = /\A(\d{5})(?:-\d{4})?\z/

  def self.parse(input)
    match = input.to_s.strip.match(PATTERN)
    match ? new(match[1]) : nil
  end

  def to_s
    value.to_s
  end
end
