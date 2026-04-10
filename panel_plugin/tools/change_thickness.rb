# encoding: UTF-8
module PanelPlugin
  module Tools
    class ChangeThickness

      def self.run
        model = Sketchup.active_model


        # Lọc lấy Group và ComponentInstance từ selection ở cấp model (ngoài edit context)
        sel = model.selection.select { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }

        if sel.empty?
          # Thử lấy container đang được edit (khi double-click vào trong)
          active = model.active_path ? model.active_path.last : nil
          if active && (active.is_a?(Sketchup::Group) || active.is_a?(Sketchup::ComponentInstance))
            sel = [active]
          else
            if model.selection.empty?
              UI.messagebox("Bạn chưa chọn đối tượng nào.\nVui lòng chọn ít nhất một tấm ván (Group hoặc Component) trên màn hình.")
            else
              types = model.selection.map { |e| e.class.name.split('::').last }.uniq.join(", ")
              UI.messagebox("Bạn đang chọn đối tượng loại: #{types}.\nNếu bạn đang ở bên trong Group, hãy nhấn Escape để thoát ra ngoài trước, rồi click chọn Group/Component từ bên ngoài.")
            end
            return
          end
        end

        first_panel = sel.first

        # Lấy kích thước bounding box theo instance (world-space bounds)
        b = first_panel.bounds
        dx = (b.max.x - b.min.x) * 25.4
        dy = (b.max.y - b.min.y) * 25.4
        dz = (b.max.z - b.min.z) * 25.4

        valid_dims = { x: dx, y: dy, z: dz }.select { |_k, v| v > 0.1 }
        current_depth = valid_dims.empty? ? 18.0 : valid_dims.min_by { |_k, v| v }[1]

        old_attr = PanelCore::AttributeManager.get(first_panel, 'thickness_mm')
        old_thickness = (old_attr && old_attr.to_f > 0) ? old_attr.to_f : current_depth.round(1)

        prompts  = ['Nhap do day moi (mm):']
        defaults = [old_thickness.to_s]
        input = ::UI.inputbox(prompts, defaults, "Doi chieu day #{sel.length} tam van")
        return unless input

        new_t_mm = input[0].to_f
        if new_t_mm < 3.0
          UI.messagebox("Do day phai >= 3mm")
          return
        end

        PanelCore::UndoWrapper.run("Doi do day hang loat") do
          sel.each do |instance|
            change_panel_thickness(instance, new_t_mm)
          end
        end
      end

      def self.change_panel_thickness(instance, new_t_mm)
        # Lay definition: ComponentInstance co .definition, Group cung co .definition tu SU 2014+
        defn = instance.respond_to?(:definition) ? instance.definition : nil
        return unless defn

        # Dung instance.bounds (world-space) de doc kich thuoc thuc te
        b = instance.bounds
        dx = (b.max.x - b.min.x) * 25.4
        dy = (b.max.y - b.min.y) * 25.4
        dz = (b.max.z - b.min.z) * 25.4
        dims = { x: dx, y: dy, z: dz }

        old_t_mm = PanelCore::AttributeManager.get(instance, 'thickness_mm').to_f
        thickness_axis = :z  # default

        if old_t_mm > 0.0
          # Tim truc world-space gan nhat voi metadata
          matching = dims.select { |_k, v| (v - old_t_mm).abs < 2.0 }
          thickness_axis = matching.min_by { |_k, v| (v - old_t_mm).abs }[0] unless matching.empty?
        else
          # Khong co metadata -> truc nho nhat trong world-space la chieu day
          valid = dims.select { |_k, v| v > 0.1 }
          unless valid.empty?
            thickness_axis = valid.min_by { |_k, v| v }[0]
            old_t_mm = valid[thickness_axis]
          end
        end

        return if old_t_mm <= 0.0 || (old_t_mm - new_t_mm).abs < 0.001

        # Make unique de khong anh huong cac instance khac
        PanelCore::ComponentManager.make_unique!(instance)
        defn = instance.respond_to?(:definition) ? instance.definition : nil
        return unless defn

        scale_factor = new_t_mm / old_t_mm

        # Scale hinh hoc ben trong definition doc theo truc local tuong ung
        sx = thickness_axis == :x ? scale_factor : 1.0
        sy = thickness_axis == :y ? scale_factor : 1.0
        sz = thickness_axis == :z ? scale_factor : 1.0

        t = Geom::Transformation.scaling(ORIGIN, sx, sy, sz)
        defn.entities.transform_entities(t, defn.entities.to_a)

        # Luu metadata do day moi
        PanelCore::AttributeManager.write(defn, { 'thickness_mm' => new_t_mm })
      end

    end
  end
end
