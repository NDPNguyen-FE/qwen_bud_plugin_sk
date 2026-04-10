# encoding: UTF-8
module PanelPlugin
  module Tools
    class FlattenCurveTool

      KE = PanelPlugin::Core::KerfEngine

      def self.run
        model = Sketchup.active_model
        sel   = model.selection
        faces = sel.grep(Sketchup::Face)
        if faces.empty?
          ::UI.messagebox("Vui lòng chọn dải mặt phẳng liên tục cần trải phẳng.")
          return
        end

        # 1. Thu thập thông số từ người dùng (giữ nguyên dialog đơn giản)
        mm = model.materials.map(&:name).reject { |n| n.start_with?('[') }
        mm.unshift('Để Trống') unless mm.include?('Để Trống')
        sv = Sketchup.read_default('panel_plugin', 'board_material', mm.first)
        sv = mm.first unless mm.include?(sv)
        
        i1 = ::UI.inputbox(
          ['Vật Liệu (Tùy chọn):', 'Dày (mm):', 'Rộng Dao CNC (mm):', 'Thịt Giữ Lại (mm):'],
          [sv, '18.0', '6.0', '2.0'],
          [mm.join('|'), '', '', ''],
          'Advanced Kerfbend - Cấu hình'
        )
        return unless i1

        mat_name  = i1[0]
        thickness = i1[1].to_f
        tool_dia  = i1[2].to_f
        remnant   = i1[3].to_f
        kerf_ratio = (thickness - remnant) / thickness

        Sketchup.write_default('panel_plugin', 'board_material', mat_name)

        model.start_operation("Tiến hành Kerfbend ABF", true)
        begin
          # Bước A: Flattener (Lấy thông số hình học: Arc Length, Góc cong, Unrolled points)
          flattener_res = KE::SurfaceFlattener.flatten(faces, {
            method: :auto,
            thickness: thickness
          })

          unless flattener_res && flattener_res[:flat_boundary]
            ::UI.messagebox("Không thể trải phẳng bề mặt. Vui lòng chọn cung tròn liên tục.")
            model.abort_operation
            return
          end

          # Bước B: Kerf Calculator (Tính số lượng rãnh, khoảng cách tối ưu dựa trên Neutral Axis)
          kerf_res = KE::KerfCalculator.calculate_kerfs(flattener_res, {
            thickness: thickness,
            kerf_ratio: kerf_ratio,
            tool_dia: tool_dia
          })

          # Bước C: ABF Adapter (Tạo Component duy nhất, set Layers và Attributes chuẩn ABF chống vỡ Face)
          pname = PanelCore::ComponentManager.next_panel_name

          # Đặt component lệch qua bên cạnh khối gốc
          bb = Geom::BoundingBox.new
          faces.each { |f| f.vertices.each { |v| bb.add(v.position) } }
          target = Geom::Point3d.new(bb.max.x + 200.mm, bb.min.y, 0)

          abf_res = KE::ABFAdapter.create_abf_component(flattener_res, kerf_res, model, {
            part_name: "CNC_#{pname}",
            thickness: thickness,
            target_point: target
          })

          # Gán material nếu có
          unless mat_name == 'Để Trống'
            sm = model.materials[mat_name]
            abf_res[:instance].material = sm if sm
          end

          # In log giống hệ thống xịn
          puts "\n#{'='*60}"
          puts "🔥 [KerfBend Engine] Hoàn tất Expermental Build"
          puts "  Part: #{abf_res[:part_name]}"
          puts "  Method Flatten: #{flattener_res[:method]}"
          puts "  Số rãnh (Kerfs): #{kerf_res[:num_kerfs]}"
          puts "  Bước rãnh (Spacing): #{kerf_res[:spacing]} mm"
          puts "  Chiều dày giữ lại: #{kerf_res[:t_rem]} mm"
          puts "  => Cấu trúc Face KHÔNG BỊ CẮT VỠ nhờ ABF Adapter Z-Offset Z=0.05"
          puts "#{'='*60}\n"

          sel.clear
          sel.add(abf_res[:instance])
        rescue => e
          model.abort_operation
          ::UI.messagebox("Lỗi KerfBend: #{e.message}")
          puts e.backtrace
        end
      end
      
    end
  end
end
