require "test_helper"

class ZipCodeTest < ActiveSupport::TestCase
  test "parses a valid 5-digit ZIP code" do
    zip = ZipCode.parse("95014")

    assert_equal "95014", zip.to_s
  end

  test "parses ZIP+4 and keeps only the 5-digit prefix" do
    zip = ZipCode.parse("95014-2083")

    assert_equal "95014", zip.to_s
  end

  test "strips surrounding whitespace" do
    assert_equal ZipCode.parse("95014"), ZipCode.parse("  95014 \n")
    assert_equal ZipCode.parse("95014"), ZipCode.parse(" 95014-2083 ")
  end

  test "returns nil for invalid inputs" do
    [ nil, "", "   ", "abcde", "9501", "950145", "95014-123", "95014 2083" ].each do |invalid|
      assert_nil ZipCode.parse(invalid), "Expected nil for #{invalid.inspect}"
    end
  end

  test "supports value equality" do
    assert_equal ZipCode.parse("95014"), ZipCode.parse("95014-2083")
    assert_not_equal ZipCode.parse("95014"), ZipCode.parse("10001")
  end
end
