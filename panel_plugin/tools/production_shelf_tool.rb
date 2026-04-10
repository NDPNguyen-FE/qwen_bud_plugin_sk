module PanelPlugin
  # SketchUp Plugin: Shelf Division Tool (Production-Oriented Example)
# Author: ChatGPT
# Note: Simplified but production-structured example

module ShelfTool

  class DivideShelvesTool

    def activate
      @ip = Sketchup::InputPoint.new
      @picked_face = nil
    end

    def onMouseMove(flags, x, y, view)
      @ip.pick(view, x, y)
      view.invalidate
    end

    def draw(view)
      @ip.draw(view) if @ip.valid?
    end

    def onLButtonDown(flags, x, y, view)
      @ip.pick(view, x, y)
      face = @ip.face
      return unless face

      @picked_face = face
      process_face(face)
    end

    # ==============================
    # CORE LOGIC
    # ==============================

    def process_face(face)
      model = Sketchup.active_model
      instance = find_parent_instance(face)
      return unless instance

      tr = instance.transformation
      local_point = @ip.position.transform(tr.inverse)

      bounds = detect_internal_bounds(instance, local_point)
      return unless bounds

      height = bounds[:top] - bounds[:bottom]

      prompts = ["Number of shelves"]
      defaults = [3]
      input = UI.inputbox(prompts, defaults, "Shelf تقسیم")
      return unless input

      n = input[0].to_i
      return if n <= 0

      spacing = height.to_f / (n + 1)

      if spacing < 10.mm
        UI.messagebox("Not enough space")
        return
      end

      create_shelves(instance, bounds, spacing, n)
    end

    # ==============================
    # FIND PARENT INSTANCE
    # ==============================

    def find_parent_instance(face)
      path = Sketchup.active_model.active_path
      return nil unless path && path.last.is_a?(Sketchup::ComponentInstance) || path.last.is_a?(Sketchup::Group)
      path.last
    end

    # ==============================
    # RAYCAST DETECTION
    # ==============================

    def detect_internal_bounds(instance, point)
      model = Sketchup.active_model

      directions = {
        left:  Geom::Vector3d.new(-1, 0, 0),
        right: Geom::Vector3d.new(1, 0, 0),
        front: Geom::Vector3d.new(0, -1, 0),
        back:  Geom::Vector3d.new(0, 1, 0),
        bottom:Geom::Vector3d.new(0, 0, -1),
        top:   Geom::Vector3d.new(0, 0, 1)
      }

      results = {}

      directions.each do |key, dir|
        ray = [point, dir]
        hit = model.raytest(ray)
        return nil unless hit

        hit_point = hit[0]
        results[key] = hit_point
      end

      {
        left: results[:left].x,
        right: results[:right].x,
        front: results[:front].y,
        back: results[:back].y,
        bottom: results[:bottom].z,
        top: results[:top].z
      }
    end

    # ==============================
    # CREATE SHELVES
    # ==============================

    def create_shelves(instance, bounds, spacing, n)
      ents = instance.definition.entities

      width  = bounds[:right] - bounds[:left]
      depth  = bounds[:back] - bounds[:front]

      (1..n).each do |i|
        z = bounds[:bottom] + i * spacing

        pts = [
          Geom::Point3d.new(bounds[:left], bounds[:front], z),
          Geom::Point3d.new(bounds[:right], bounds[:front], z),
          Geom::Point3d.new(bounds[:right], bounds[:back], z),
          Geom::Point3d.new(bounds[:left], bounds[:back], z)
        ]

        group = ents.add_group
        face = group.entities.add_face(pts)
        face.reverse! if face.normal.z < 0

        group.name = "Shelf_#{i}"
      end
    end

  end

  # ==============================
  # ACTIVATE TOOL
  # ==============================

  def self.activate
    Sketchup.active_model.select_tool(DivideShelvesTool.new)
  end

end

# Run:
# ShelfTool.activate

end
