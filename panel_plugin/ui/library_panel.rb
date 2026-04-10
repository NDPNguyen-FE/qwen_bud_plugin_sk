# encoding: UTF-8
# =============================================================================
# LibraryPanel - HtmlDialog controller cho thư viện module tủ
# ML-01 to ML-06
# =============================================================================
module PanelPlugin
  module UI
    class LibraryPanel
      @@dialog = nil

      def self.show
        create_dialog unless @@dialog
        @@dialog.show unless @@dialog.visible?
        @@dialog.bring_to_front
        load_templates
      end

      private

      def self.create_dialog
        options = {
          dialog_title:    'Thư viện Module Tủ',
          preferences_key: 'panel_plugin_library',
          scrollable:      false,
          resizable:       true,
          width:           600,
          height:          680,
          left:            650,
          top:             80,
          style:           ::UI::HtmlDialog::STYLE_DIALOG
        }

        @@dialog = ::UI::HtmlDialog.new(options)
        html_file = File.join(File.dirname(__FILE__), 'html', 'library_panel.html')
        @@dialog.set_file(html_file)

        # JS → Ruby: get all templates
        @@dialog.add_action_callback('get_templates') do |_ctx|
          load_templates
        end

        # JS → Ruby: insert a template
        @@dialog.add_action_callback('insert_template') do |_ctx, template_id|
          instances = PanelPlugin::Library::TemplateManager.insert_template(template_id)
          if instances.any?
            @@dialog.execute_script("showInsertSuccess('#{template_id}', #{instances.count})")
          else
            @@dialog.execute_script("showInsertError('Không thể chèn template')")
          end
        end

        # JS → Ruby: save selection as user template
        @@dialog.add_action_callback('save_user_template') do |_ctx, data|
          begin
            info = JSON.parse(data)
            success = PanelPlugin::Library::TemplateManager.save_selection_as_template(
              info['name'], info['category']
            )
            if success
              @@dialog.execute_script("showSaveSuccess()")
              load_templates  # Refresh list
            else
              @@dialog.execute_script("showSaveError('Lưu template thất bại')")
            end
          rescue => e
            @@dialog.execute_script("showSaveError('#{e.message}')")
          end
        end

        @@dialog.set_on_closed { @@dialog = nil }
      end

      def self.load_templates
        return unless @@dialog && @@dialog.visible?
        templates = PanelPlugin::Library::TemplateManager.all_templates
        # Convert to JSON-safe format (symbols → strings)
        json_safe = templates.map do |t|
          {
            id:         t[:id],
            name:       t[:name],
            category:   t[:category],
            user:       t[:user] || false,
            dimensions: t[:dimensions] || {},
            panel_count: (t[:panels] || []).count
          }
        end
        @@dialog.execute_script("loadTemplates(#{json_safe.to_json})")
      end
    end
  end
end
