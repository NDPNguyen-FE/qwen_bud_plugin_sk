# encoding: UTF-8
# =============================================================================
# test_validator.rb - Unit tests for PanelCore::Validator
# Run inside SketchUp Ruby Console:
#   load File.join(Sketchup.find_support_file('', 'Plugins'), '../panel_plugin/tests/test_validator.rb')
# =============================================================================
require 'test/unit'

class TestValidator < Test::Unit::TestCase
  # ---------------------------------------------------------------------------
  # validate_dimensions!
  # ---------------------------------------------------------------------------
  def test_valid_dimensions
    assert PanelCore::Validator.validate_dimensions!(600, 400, 18)
  end

  def test_minimum_dimensions_pass
    assert PanelCore::Validator.validate_dimensions!(10, 10, 3)
  end

  def test_thickness_below_minimum_raises
    assert_raises(ArgumentError) do
      PanelCore::Validator.validate_dimensions!(600, 400, 2.9)
    end
  end

  def test_thickness_exactly_minimum_passes
    assert PanelCore::Validator.validate_dimensions!(600, 400, 3.0)
  end

  def test_length_below_minimum_raises
    assert_raises(ArgumentError) do
      PanelCore::Validator.validate_dimensions!(9, 400, 18)
    end
  end

  def test_width_below_minimum_raises
    assert_raises(ArgumentError) do
      PanelCore::Validator.validate_dimensions!(600, 9, 18)
    end
  end

  # ---------------------------------------------------------------------------
  # check_dimensions (non-raising version)
  # ---------------------------------------------------------------------------
  def test_check_dimensions_returns_empty_for_valid
    errors = PanelCore::Validator.check_dimensions(600, 400, 18)
    assert errors.empty?, "Expected no errors, got: #{errors}"
  end

  def test_check_dimensions_returns_errors_for_invalid
    errors = PanelCore::Validator.check_dimensions(5, 5, 1)
    assert errors.length == 3, "Expected 3 errors, got #{errors.length}: #{errors}"
  end

  # ---------------------------------------------------------------------------
  # validate_attributes!
  # ---------------------------------------------------------------------------
  def test_valid_attributes
    attrs = { part_name: 'Vách trái', grain_direction: :horizontal }
    assert PanelCore::Validator.validate_attributes!(attrs)
  end

  def test_empty_name_raises
    attrs = { part_name: '', grain_direction: :horizontal }
    assert_raises(ArgumentError) { PanelCore::Validator.validate_attributes!(attrs) }
  end

  def test_blank_name_raises
    attrs = { part_name: '   ', grain_direction: :horizontal }
    assert_raises(ArgumentError) { PanelCore::Validator.validate_attributes!(attrs) }
  end

  def test_name_with_slash_raises
    attrs = { part_name: 'Test/01', grain_direction: :horizontal }
    assert_raises(ArgumentError) { PanelCore::Validator.validate_attributes!(attrs) }
  end

  def test_name_with_backslash_raises
    attrs = { part_name: 'Test\\01', grain_direction: :horizontal }
    assert_raises(ArgumentError) { PanelCore::Validator.validate_attributes!(attrs) }
  end

  def test_name_with_colon_raises
    attrs = { part_name: 'Test:01', grain_direction: :horizontal }
    assert_raises(ArgumentError) { PanelCore::Validator.validate_attributes!(attrs) }
  end

  def test_name_with_asterisk_raises
    attrs = { part_name: 'Test*01', grain_direction: :horizontal }
    assert_raises(ArgumentError) { PanelCore::Validator.validate_attributes!(attrs) }
  end

  def test_invalid_grain_direction_raises
    attrs = { part_name: 'Vách trái', grain_direction: :diagonal }
    assert_raises(ArgumentError) { PanelCore::Validator.validate_attributes!(attrs) }
  end

  def test_nil_grain_direction_raises
    attrs = { part_name: 'Vách trái', grain_direction: nil }
    assert_raises(ArgumentError) { PanelCore::Validator.validate_attributes!(attrs) }
  end

  # ---------------------------------------------------------------------------
  # validate_part_name
  # ---------------------------------------------------------------------------
  def test_validate_part_name_nil_for_valid
    assert_nil PanelCore::Validator.validate_part_name('Panel_001')
  end

  def test_validate_part_name_returns_error_for_empty
    err = PanelCore::Validator.validate_part_name('')
    assert err.is_a?(String) && !err.empty?
  end

  def test_validate_part_name_returns_error_for_special_chars
    err = PanelCore::Validator.validate_part_name('Panel/01')
    assert err.is_a?(String) && !err.empty?
  end
end

# Run tests and output results
result = Test::Unit::AutoRunner.run(true, __FILE__)
puts result ? "\n[PASS] All Validator tests passed!" : "\n[FAIL] Some Validator tests failed."
