# encoding: UTF-8
# =============================================================================
# AttributeManager - Read/write AttributeDictionary với namespace 'panel_core'
# =============================================================================
module PanelCore
  module AttributeManager
    NAMESPACE = 'panel_core'.freeze

    REQUIRED_KEYS = %w[part_name material_id grain_direction thickness_mm is_template].freeze
    OPTIONAL_KEYS = %w[notes created_at].freeze
    ALL_KEYS      = (REQUIRED_KEYS + OPTIONAL_KEYS).freeze

    # Default attribute set for a new panel
    def self.default_attributes(name = nil)
      thickness = UI.read_default('panel_plugin', 'default_thickness', 18.0)
      {
        'part_name'       => name || 'Panel',
        'material_id'     => 'melamine_18',
        'grain_direction' => 'horizontal',
        'thickness_mm'    => thickness,
        'is_template'     => false,
        'notes'           => '',
        'created_at'      => Time.now.to_i
      }
    end

    # Write attributes to a ComponentInstance or ComponentDefinition
    def self.write(entity, attrs)
      defn = definition_of(entity)
      return false unless defn

      dict = defn.attribute_dictionary(NAMESPACE, true)
      attrs.each do |k, v|
        dict[k.to_s] = v
      end
      true
    end

    # Read attributes from a ComponentInstance or ComponentDefinition
    # Returns hash with string keys
    def self.read(entity)
      defn = definition_of(entity)
      return {} unless defn

      dict = defn.attribute_dictionary(NAMESPACE)
      return default_attributes unless dict

      result = {}
      ALL_KEYS.each do |key|
        result[key] = dict[key]
      end
      result
    end

    # Check if entity is a panel (has panel_core dictionary)
    def self.panel?(entity)
      return false unless entity.is_a?(Sketchup::ComponentInstance)
      defn = entity.definition
      dict = defn.attribute_dictionary(NAMESPACE)
      dict && !dict['part_name'].to_s.strip.empty? && dict['is_template'] != true
    end

    # Check if entity is a template
    def self.template?(entity)
      defn = definition_of(entity)
      return false unless defn
      dict = defn.attribute_dictionary(NAMESPACE)
      dict && dict['is_template'] == true
    end

    # Get a single attribute value
    def self.get(entity, key)
      defn = definition_of(entity)
      return nil unless defn
      dict = defn.attribute_dictionary(NAMESPACE)
      return nil unless dict
      dict[key.to_s]
    end

    # Set a single attribute value
    def self.set(entity, key, value)
      defn = definition_of(entity)
      return false unless defn
      dict = defn.attribute_dictionary(NAMESPACE, true)
      dict[key.to_s] = value
      true
    end

    # Mark a definition as a template
    def self.mark_as_template(defn)
      dict = defn.attribute_dictionary(NAMESPACE, true)
      dict['is_template'] = true
    end

    # Get the definition from an instance or definition
    def self.definition_of(entity)
      if entity.is_a?(Sketchup::ComponentInstance)
        entity.definition
      elsif entity.is_a?(Sketchup::Group)
        entity.respond_to?(:definition) ? entity.definition : entity.entities.parent
      elsif entity.is_a?(Sketchup::ComponentDefinition)
        entity
      else
        nil
      end
    end

    # Apply attributes to all instances sharing the same definition
    # (Does NOT call make_unique - intentional for shared attribute updates)
    def self.apply_to_all_similar(instance, attrs)
      defn = definition_of(instance)
      return 0 unless defn
      write(defn, attrs)
      defn.instances.count
    end

    # Convert grain_direction string to symbol for internal use
    def self.grain_symbol(value)
      GrainDirection.from_string(value.to_s) || GrainDirection::NONE
    end
  end
end
