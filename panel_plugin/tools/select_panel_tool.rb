# encoding: UTF-8
# =============================================================================
# SelectPanelTool - Tool chọn và highlight tấm ván
# =============================================================================
module PanelPlugin
  module Tools
    class SelectPanelTool
      def activate
        Sketchup.active_model.set_status_text(
          'Click vào tấm ván để chọn | Double-click: Đổi chiều dày ván | Esc: Thoát',
          SB_PROMPT
        )
      end

      def deactivate(view)
        view.invalidate
      end

      def onMouseMove(flags, x, y, view)
        ph  = view.pick_helper
        ph.do_pick(x, y)
        @hovered = ph.best_picked
        view.invalidate
      end

      def onLButtonDown(flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        picked = ph.best_picked

        model = Sketchup.active_model
        sel   = model.selection

        if picked.is_a?(Sketchup::ComponentInstance)
          if PanelCore::AttributeManager.panel?(picked)
            sel.clear
            sel.add(picked)
            # Removed AttributeEditor refresh
          else
            sel.clear
          end
        else
          sel.clear
        end

        view.invalidate
      end

      def onLButtonDoubleClick(flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        picked = ph.best_picked

        if picked.is_a?(Sketchup::ComponentInstance) && PanelCore::AttributeManager.panel?(picked)
          Sketchup.active_model.selection.add(picked)
          PanelPlugin::Tools::ChangeThickness.run
        end
      end

      def draw(view)
        # Highlight hovered panel
        if @hovered.is_a?(Sketchup::ComponentInstance) && PanelCore::AttributeManager.panel?(@hovered)
          bb = @hovered.bounds
          pts = [
            bb.corner(0), bb.corner(1), bb.corner(3), bb.corner(2),
            bb.corner(4), bb.corner(5), bb.corner(7), bb.corner(6)
          ]
          view.drawing_color = Sketchup::Color.new(0, 120, 212, 150)
          view.line_width = 2
          view.draw(GL_LINE_LOOP, [bb.corner(0), bb.corner(1), bb.corner(3), bb.corner(2)])
          view.draw(GL_LINE_LOOP, [bb.corner(4), bb.corner(5), bb.corner(7), bb.corner(6)])
        end
      end
    end
  end
end
