# encoding: UTF-8
module PanelPlugin
  module Tools
    class MortiseTenonTool

      def initialize
        @state = 0
        @panel1 = nil
        @panel2 = nil
        @cursor_id = UI.create_cursor(File.join(PanelPlugin::PLUGIN_DIR, 'assets', 'cursor_select.png'), 0, 0) rescue 0
      end

      def self.run
        Sketchup.active_model.select_tool(new)
      end

      def activate
        @state = 0
        @panel1 = nil
        @panel2 = nil
        Sketchup.active_model.selection.clear
        update_status
      end

      def onSetCursor
        UI.set_cursor(@cursor_id) if @cursor_id > 0
      end

      def onLButtonDown(flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        comp = ph.best_picked

        if valid_panel?(comp)
          if @state == 0
            @panel1 = comp
            Sketchup.active_model.selection.add(@panel1)
            @state = 1
            update_status
          elsif @state == 1
            if comp != @panel1
              @panel2 = comp
              Sketchup.active_model.selection.add(@panel2)
              process_joint
              
              # Tự động reset lại tool để đánh mộng tiếp (giữ nguyên vách)
              @state = 0
              @panel1 = nil
              @panel2 = nil
              Sketchup.active_model.selection.clear
              update_status
            end
          end
        else
          UI.beep
          view.tooltip = "Vui lòng chọn một Group/Component tấm ván"
        end
      end

      def onMouseMove(flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        comp = ph.best_picked
        
        if valid_panel?(comp)
          if @state == 0
            view.tooltip = "Click Tấm Đâm (Tenon) - Tấm sẽ có mộng dương"
          else
            view.tooltip = comp == @panel1 ? "Đã chọn" : "Click Tấm Vách (Mortise) - Tấm sẽ bị khoét lỗ"
          end
        else
          view.tooltip = "Khu vực trống"
        end
        view.invalidate
      end

      def draw(view)
        if @panel1 && @panel1.valid?
          view.drawing_color = Sketchup::Color.new(255, 0, 0, 128)
          view.line_width = 3
          view.draw_bounding_box(@panel1.bounds)
        end
        if @panel2 && @panel2.valid?
          view.drawing_color = Sketchup::Color.new(0, 0, 255, 128)
          view.draw_bounding_box(@panel2.bounds)
        end
      end

      def onCancel(reason, view)
        activate
      end

      private

      def update_status
        if @state == 0
          Sketchup.status_text = "[Đánh Mộng CNC] BƯỚC 1: Click chọn tấm ván ĐÂM VÀO (Tấm Đợt - Chứa Mộng Dương)"
        else
          Sketchup.status_text = "[Đánh Mộng CNC] BƯỚC 2: Click chọn tấm BỊ ĐÂM (Tấm Vách - Chứa Lỗ Mộng Âm)"
        end
      end

      def valid_panel?(ent)
        ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
      end

      def process_joint
        defaults = [
          Sketchup.read_default('panel_plugin', 'mt_length', '40.0'),
          Sketchup.read_default('panel_plugin', 'mt_margin', '20.0'),
          Sketchup.read_default('panel_plugin', 'mt_depth', '9.0'),
          Sketchup.read_default('panel_plugin', 'mt_tool', '6.0'),
          Sketchup.read_default('panel_plugin', 'mt_tol', '0.2')
        ]

        prompts = [
          "Chiều dài 1 răng mộng (mm):",
          "Thụt lề giấu mộng 2 đầu (mm):",
          "Chiều sâu âm vào vách (mm):",
          "Đường kính dao CNC (mm):",
          "Độ hở keo lô mộng (mm):"
        ]

        # Cho phép nhập bằng tay
        result = ::UI.inputbox(prompts, defaults, [], "Thông Số Mộng Âm Dương")
        return unless result

        t_len = result[0].to_f
        t_mar = result[1].to_f
        depth = result[2].to_f
        t_dia = result[3].to_f
        tol   = result[4].to_f

        Sketchup.write_default('panel_plugin', 'mt_length', result[0])
        Sketchup.write_default('panel_plugin', 'mt_margin', result[1])
        Sketchup.write_default('panel_plugin', 'mt_depth', result[2])
        Sketchup.write_default('panel_plugin', 'mt_tool', result[3])
        Sketchup.write_default('panel_plugin', 'mt_tol', result[4])

        options = {
          tenon_length: t_len.mm,
          tenon_margin: t_mar.mm,
          mortise_depth: depth.mm,
          tool_dia: t_dia.mm,
          tolerance: tol.mm
        }

        # Ép engine chỉ tạo join cho 2 panels này (bất chấp chạm mặt phẳng nào, ta sẽ tự check)
        res = PanelPlugin::Core::JoineryEngine.process_panels([@panel1, @panel2], options)
        
        if res[:success]
          puts "[Joinery] Đã đánh mộng hoàn tất!"
        else
          Sketchup.messagebox(res[:message])
        end
      end
    end
  end
end
