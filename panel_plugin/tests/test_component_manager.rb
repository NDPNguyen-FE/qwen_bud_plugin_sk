# encoding: UTF-8
# =============================================================================
# test_component_manager.rb - Unit tests for PanelCore::ComponentManager
# =============================================================================
require 'test/unit'

class TestComponentManager < Test::Unit::TestCase
  def setup
    @model = Sketchup.active_model
    @created_instances = []
  end

  def teardown
    @model.start_operation('Test cleanup', true)
    @created_instances.each do |inst|
      inst.erase! if inst.valid?
    end
    @model.commit_operation
  end

  # ---------------------------------------------------------------------------
  # mm_to_su / su_to_mm
  # ---------------------------------------------------------------------------
  def test_mm_to_su_conversion
    # 25.4mm = 1 inch (SketchUp unit)
    val = PanelCore::ComponentManager.mm_to_su(25.4)
    assert_in_delta 1.0, val, 0.0001
  end

  def test_su_to_mm_conversion
    val = PanelCore::ComponentManager.su_to_mm(1.0)
    assert_in_delta 25.4, val, 0.0001
  end

  def test_roundtrip_conversion
    original = 600.0
    val = PanelCore::ComponentManager.su_to_mm(
      PanelCore::ComponentManager.mm_to_su(original)
    )
    assert_in_delta original, val, 0.001
  end

  # ---------------------------------------------------------------------------
  # parse_dimension_input
  # ---------------------------------------------------------------------------
  def test_parse_mm_input
    val = PanelCore::ComponentManager.parse_dimension_input('600')
    assert_in_delta 600.0, val, 0.001
  end

  def test_parse_mm_with_unit_suffix
    val = PanelCore::ComponentManager.parse_dimension_input('600mm')
    assert_in_delta 600.0, val, 0.001
  end

  def test_parse_inch_input
    val = PanelCore::ComponentManager.parse_dimension_input('1"')
    assert_in_delta 25.4, val, 0.01
  end

  # ---------------------------------------------------------------------------
  # next_panel_name
  # ---------------------------------------------------------------------------
  def test_panel_name_format
    name1 = PanelCore::ComponentManager.next_panel_name
    name2 = PanelCore::ComponentManager.next_panel_name
    assert_match /^ABF_\d{3}$/, name1
    assert_not_equal name1, name2
  end

  # ---------------------------------------------------------------------------
  # create_panel_definition
  # ---------------------------------------------------------------------------
  def test_create_panel_definition_returns_definition
    @model.start_operation('test', true)
    defn = PanelCore::ComponentManager.create_panel_definition(600, 400, 18, '_test_cp_001')
    @model.commit_operation

    assert defn.is_a?(Sketchup::ComponentDefinition)
    assert_equal '_test_cp_001', defn.name

    # Clean up
    @model.start_operation('cleanup', true)
    inst = @model.active_entities.add_instance(defn, ORIGIN)
    inst.erase!
    @model.commit_operation
  end

  def test_create_panel_definition_correct_bounds
    @model.start_operation('test', true)
    defn = PanelCore::ComponentManager.create_panel_definition(600, 400, 18, '_test_cp_002')
    inst = @model.active_entities.add_instance(defn, ORIGIN)
    @created_instances << inst
    @model.commit_operation

    bounds = inst.bounds
    l_su = PanelCore::ComponentManager.mm_to_su(600)
    w_su = PanelCore::ComponentManager.mm_to_su(400)
    t_su = PanelCore::ComponentManager.mm_to_su(18)

    assert_in_delta l_su, bounds.width,  0.001
    assert_in_delta w_su, bounds.depth,  0.001
    assert_in_delta t_su, bounds.height, 0.001
  end
end

result = Test::Unit::AutoRunner.run(true, __FILE__)
puts result ? "\n[PASS] All ComponentManager tests passed!" : "\n[FAIL] Some ComponentManager tests failed."
