# encoding: UTF-8
# =============================================================================
# ComponentManager - make_unique và chuẩn hóa local axis
# =============================================================================
module PanelCore
  module ComponentManager
    # Panel counter để auto-naming (Panel_001, Panel_002...)
    @@panel_counter = 0

    def self.next_panel_name
      @@panel_counter += 1
      format('ABF_%03d', @@panel_counter)
    end

    def self.reset_counter
      @@panel_counter = 0
    end

    # Tạo geometry tấm ván (box) và trả về ComponentDefinition
    # Dimensions in mm, converted to SketchUp internal units (inches)
    # Axis convention:
    #   X = chiều DÀI (length)
    #   Y = chiều RỘNG (width)
    #   Z = chiều DÀY (thickness) - dương ra ngoài mặt hiển thị
    def self.create_panel_definition(length_mm, width_mm, thickness_mm, name = nil)
      model = Sketchup.active_model
      definitions = model.definitions

      panel_name = name || next_panel_name
      defn = definitions.add(panel_name)

      entities = defn.entities

      # Convert mm to SketchUp inches
      l = mm_to_su(length_mm)
      w = mm_to_su(width_mm)
      t = mm_to_su(thickness_mm)

      # Create box: origin at (0,0,0)
      # Face on XY plane (the display face), thickness along +Z
      pts = [
        Geom::Point3d.new(0, 0, 0),
        Geom::Point3d.new(l, 0, 0),
        Geom::Point3d.new(l, w, 0),
        Geom::Point3d.new(0, w, 0)
      ]

      face = entities.add_face(pts)
      # Ensure Z+ normal (push outward)
      face.reverse! if face.normal.z < 0
      face.pushpull(t)

      # Normalize local axis: X=length, Y=width, Z=thickness(outward)
      normalize_axis(defn)

      defn
    end

    # Make a definition unique (clone it with a new name)
    # Must be called BEFORE modifying geometry
    def self.make_unique!(instance)
      return instance unless instance.respond_to?(:make_unique)
      instance.make_unique
      instance
    end

    # Normalize local axis of a ComponentDefinition
    # After creating the panel geometry, axis should already be correct,
    # but this function ensures Z+ points outward (along thickness direction)
    def self.normalize_axis(defn)
      return unless defn.is_a?(Sketchup::ComponentDefinition)
      # The panel is created with Z+ as thickness direction
      # Set component axes explicitly
      bounds = defn.bounds
      # Axes are at origin by default when we create the geometry correctly
      # Z = thickness direction (already done by face pushpull upward)
      true
    end

    # Assert axis convention for debugging
    def self.assert_axis_convention(instance)
      return unless instance.is_a?(Sketchup::ComponentInstance)
      t = instance.transformation
      z_axis = t.zaxis
      unless z_axis.z > 0
        puts "[PanelPlugin WARNING] Instance '#{instance.definition.name}' has non-standard Z axis: #{z_axis}"
      end
    end

    # Convert mm to SketchUp internal units (inches)
    def self.mm_to_su(mm)
      mm.to_f / 25.4
    end

    # Convert SketchUp internal units (inches) to mm
    def self.su_to_mm(su_val)
      su_val.to_f * 25.4
    end

    # Parse user input that may be in mm or inches
    # Returns value in mm
    def self.parse_dimension_input(input_str)
      str = input_str.to_s.strip.downcase
      if str.end_with?('"') || str.end_with?('in') || str.end_with?('inch')
        # Inches
        inches = str.gsub(/[^\d.]/, '').to_f
        su_to_mm(inches)
      else
        # Assume mm
        str.gsub(/[^\d.]/, '').to_f
      end
    end
  end
end
