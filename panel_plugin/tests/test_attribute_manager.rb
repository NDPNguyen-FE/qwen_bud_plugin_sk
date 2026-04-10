# encoding: UTF-8
# =============================================================================
# test_attribute_manager.rb - Unit tests for PanelCore::AttributeManager
# =============================================================================
require 'test/unit'

class TestAttributeManager < Test::Unit::TestCase
  def setup
    # Create a dummy ComponentInstance for testing using active model
    @model = Sketchup.active_model
    @definitions = @model.definitions

    # Clean up test definitions
    @definitions.each do |d|
      @definitions.remove(d) if d.name.start_with?('_test_panel_')
    end

    # Create a test definition
    @model.start_operation('Test setup', true)
    @defn = @definitions.add('_test_panel_001')
    pts = [
      Geom::Point3d.new(0, 0, 0),
      Geom::Point3d.new(1, 0, 0),
      Geom::Point3d.new(1, 1, 0),
      Geom::Point3d.new(0, 1, 0)
    ]
    face = @defn.entities.add_face(pts)
    face.pushpull(0.5)
    @instance = @model.active_entities.add_instance(@defn, ORIGIN)
    @model.commit_operation
  end

  def teardown
    @model.start_operation('Test teardown', true)
    @instance.erase! if @instance.valid?
    @model.commit_operation
  end

  # ---------------------------------------------------------------------------
  # definition_of
  # ---------------------------------------------------------------------------
  def test_definition_of_instance
    defn = PanelCore::AttributeManager.definition_of(@instance)
    assert_equal @defn, defn
  end

  def test_definition_of_definition
    defn = PanelCore::AttributeManager.definition_of(@defn)
    assert_equal @defn, defn
  end

  def test_definition_of_invalid_entity
    defn = PanelCore::AttributeManager.definition_of("not an entity")
    assert_nil defn
  end

  # ---------------------------------------------------------------------------
  # write & read
  # ---------------------------------------------------------------------------
  def test_write_and_read
    attrs = {
      'part_name'       => 'Test Panel',
      'material_id'     => 'melamine_18',
      'grain_direction' => 'horizontal',
      'thickness_mm'    => 18.0,
      'is_template'     => false
    }
    PanelCore::AttributeManager.write(@instance, attrs)
    result = PanelCore::AttributeManager.read(@instance)

    assert_equal 'Test Panel',   result['part_name']
    assert_equal 'melamine_18',  result['material_id']
    assert_equal 'horizontal',   result['grain_direction']
    assert_equal 18.0,           result['thickness_mm']
    assert_equal false,          result['is_template']
  end

  def test_read_returns_hash_with_string_keys
    PanelCore::AttributeManager.write(@instance, { 'part_name' => 'Panel' })
    result = PanelCore::AttributeManager.read(@instance)
    assert result.is_a?(Hash)
    assert result.keys.all? { |k| k.is_a?(String) }
  end

  # ---------------------------------------------------------------------------
  # get & set
  # ---------------------------------------------------------------------------
  def test_get_and_set
    PanelCore::AttributeManager.set(@instance, 'part_name', 'My Panel')
    val = PanelCore::AttributeManager.get(@instance, 'part_name')
    assert_equal 'My Panel', val
  end

  # ---------------------------------------------------------------------------
  # panel?
  # ---------------------------------------------------------------------------
  def test_panel_returns_false_without_attributes
    refute PanelCore::AttributeManager.panel?(@instance)
  end

  def test_panel_returns_true_with_valid_attributes
    PanelCore::AttributeManager.write(@instance, {
      'part_name'   => 'Test',
      'is_template' => false
    })
    assert PanelCore::AttributeManager.panel?(@instance)
  end

  def test_panel_returns_false_for_template
    PanelCore::AttributeManager.write(@instance, {
      'part_name'   => 'Template',
      'is_template' => true
    })
    refute PanelCore::AttributeManager.panel?(@instance)
  end

  # ---------------------------------------------------------------------------
  # mark_as_template
  # ---------------------------------------------------------------------------
  def test_mark_as_template
    PanelCore::AttributeManager.mark_as_template(@defn)
    val = PanelCore::AttributeManager.get(@defn, 'is_template')
    assert_equal true, val
  end

  # ---------------------------------------------------------------------------
  # default_attributes
  # ---------------------------------------------------------------------------
  def test_default_attributes_has_required_keys
    defaults = PanelCore::AttributeManager.default_attributes('Panel_001')
    assert defaults.key?('part_name')
    assert defaults.key?('material_id')
    assert defaults.key?('grain_direction')
    assert defaults.key?('thickness_mm')
    assert defaults.key?('is_template')
  end

  def test_default_attributes_not_template
    defaults = PanelCore::AttributeManager.default_attributes
    assert_equal false, defaults['is_template']
  end
end

result = Test::Unit::AutoRunner.run(true, __FILE__)
puts result ? "\n[PASS] All AttributeManager tests passed!" : "\n[FAIL] Some AttributeManager tests failed."
