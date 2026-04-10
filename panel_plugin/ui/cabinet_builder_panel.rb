# encoding: UTF-8
# =============================================================================
# CabinetBuilderPanel - HtmlDialog controller cho công cụ xây tủ base
# =============================================================================
module PanelPlugin
  module UI
    class CabinetBuilderPanel
      @@dialog = nil

      @target_panel = nil

      def self.show(target_panel = nil)
        @target_panel = target_panel
        create_dialog unless @@dialog
        @@dialog.show unless @@dialog.visible?
        @@dialog.bring_to_front
        
        load_cabinet_data if @target_panel && @target_panel.valid?
      end

      private

      def self.create_dialog
        options = {
          dialog_title:    'Xây Tủ Base - Cabinet Builder',
          preferences_key: 'panel_plugin_cabinet_builder',
          scrollable:      false,
          resizable:       true,
          width:           700,
          height:          760,
          left:            300,
          top:             60,
          style:           ::UI::HtmlDialog::STYLE_DIALOG
        }

        @@dialog = ::UI::HtmlDialog.new(options)
        html_file = File.join(File.dirname(__FILE__), 'html', 'cabinet_builder.html')
        @@dialog.set_file(html_file)

        # JS → Ruby: build cabinet
        @@dialog.add_action_callback('build_cabinet') do |_ctx, json_data|
          begin
            data   = JSON.parse(json_data)
            config = {
              width:           data['width'].to_f,
              depth:           data['depth'].to_f,
              height:          data['height'].to_f,
              thickness:       data['thickness'].to_f,
              back_thickness:  data['back_thickness'].to_f,
              back_groove_depth:  (data['back_groove_depth'] || 8).to_f,
              back_groove_offset: (data['back_groove_offset'] || 18).to_f,
              toe_kick_height: data['toe_kick_height'].to_f,
              toe_kick_depth:  data['toe_kick_depth'].to_f,
              has_top:         data['has_top'] == true,
              has_back:        data['has_back'] == true,
              style:           data['style'].to_sym,
              floor_raise:     data['floor_raise'].to_f,
              door_gap_top:    data['door_gap_top'].to_f,
              door_gap_bot:    data['door_gap_bot'].to_f,
              door_gap_l:      data['door_gap_l'].to_f,
              door_gap_r:      data['door_gap_r'].to_f,
              num_doors:       (data['num_doors'] || 1).to_i,
              num_shelves:     (data['num_shelves'] || 0).to_i,
              num_dividers:    (data['num_dividers'] || 0).to_i,
              name:            data['name'].to_s.empty? ? 'Tủ Base' : data['name'].to_s
            }

            if @target_panel && @target_panel.valid?
              cabinet_id = @target_panel.get_attribute('panel_cabinet', 'cabinet_id')
              instances = PanelPlugin::Tools::CabinetBuilderTool.build(config, cabinet_id)
            else
              instances = PanelPlugin::Tools::CabinetBuilderTool.build(config)
            end
            
            count = instances.select { |i| i.is_a?(Sketchup::Group) }.count
            @@dialog.execute_script("onBuildSuccess(#{count})")
            @target_panel = nil # reset after successful build
          rescue => e
            puts "[CabinetBuilderPanel] Error: #{e.message}"
            puts e.backtrace.first(5).join("\n")
            safe_msg = e.message.gsub("'", "\\'").gsub('"', '\\"')
            @@dialog.execute_script("onBuildError('#{safe_msg}')")
          end
        end

        # JS → Ruby: build multiple (array of cabinets)
        @@dialog.add_action_callback('build_cabinet_row') do |_ctx, json_data|
          begin
            configs = JSON.parse(json_data)
            total   = 0
            offset_x = 0.0
            PanelCore::UndoWrapper.run('Xây dãy tủ base') do
              configs.each do |data|
                cfg = {
                  width:           data['width'].to_f,
                  depth:           data['depth'].to_f,
                  height:          data['height'].to_f,
                  thickness:       data['thickness'].to_f,
                  back_thickness:  data['back_thickness'].to_f,
                  toe_kick_height: data['toe_kick_height'].to_f,
                  toe_kick_depth:  data['toe_kick_depth'].to_f,
                  has_top:         data['has_top'] == true,
                  has_back:        data['has_back'] == true,
                  style:           data['style'].to_sym,
                  door_overlay:    data['door_overlay'].to_f,
                  num_shelves:     data['num_shelves'].to_i,
                  name:            data['name'].to_s.empty? ? 'Tủ Base' : data['name'].to_s,
                  position:        Geom::Point3d.new(
                    PanelCore::ComponentManager.mm_to_su(offset_x), 0, 0
                  )
                }
                insts = PanelPlugin::Tools::CabinetBuilderTool.build(cfg)
                total += insts.select { |i| i.is_a?(Sketchup::Group) }.count
                offset_x += data['width'].to_f
              end
            end
            @@dialog.execute_script("onBuildSuccess(#{total})")
          rescue => e
            safe_msg = e.message.gsub("'", "\\'")
            @@dialog.execute_script("onBuildError('#{safe_msg}')")
          end
        end

        @@dialog.set_on_closed { 
          @@dialog = nil 
          @target_panel = nil
        }
      end

      def self.load_cabinet_data
        return unless @target_panel && @target_panel.valid?
        dict = @target_panel.attribute_dictionary('panel_cabinet')
        return unless dict
        
        data = {
          name:            dict['name'] || 'Tủ Base',
          width:           dict['width_mm'].to_f,
          depth:           dict['depth_mm'].to_f,
          height:          dict['height_mm'].to_f,
          thickness:       dict['thickness_mm'].to_f,
          back_thickness:  dict['back_thickness_mm'].to_f,
          back_groove_depth:  (dict['back_groove_depth'] || 8).to_f,
          back_groove_offset: (dict['back_groove_offset'] || 18).to_f,
          toe_kick_height: dict['toe_kick_height_mm'].to_f,
          toe_kick_depth:  dict['toe_kick_depth_mm'].to_f,
          has_top:         dict['has_top'],
          has_back:        dict['has_back'],
          style:           dict['style'],
          floor_raise:     dict['floor_raise_mm'].to_f,
          num_shelves:     dict['num_shelves'].to_i,
          num_dividers:    dict['num_dividers'].to_i,
          door_overlay:    dict['door_overlay'].to_f
        }
        
        # In case some old cabinets don't have new attributes, set defaults via JS
        @@dialog.execute_script("loadCabinetData(#{data.to_json})")
      end
    end
  end
end
