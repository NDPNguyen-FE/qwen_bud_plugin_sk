# encoding: UTF-8
# =============================================================================
# TemplateManager - Load/save template từ file .skp, tránh bị Purge Unused
# ML-01 to ML-06
# =============================================================================
module PanelPlugin
  module Library
    class TemplateManager
      TEMPLATE_DIR  = File.join(File.dirname(File.dirname(File.dirname(__FILE__))), 'library', 'templates')
      USER_DIR      = File.join(ENV['APPDATA'] || File.expand_path('~'), 'PanelPlugin', 'user_templates')

      BUILT_IN_TEMPLATES = [
        {
          id:          'kitchen_base_600',
          name:        'Tủ bếp dưới 600mm',
          category:    'bếp',
          thumbnail:   'kitchen_base_600.png',
          file:        'kitchen_base_600.skp',
          dimensions:  { length: 600, width: 560, height: 820 },
          panels: [
            { name: 'Vách trái',    l: 560, w: 820, t: 18, grain: :vertical },
            { name: 'Vách phải',   l: 560, w: 820, t: 18, grain: :vertical },
            { name: 'Vách hậu',    l: 600, w: 820, t: 18, grain: :vertical },
            { name: 'Sàn tủ',      l: 564, w: 560, t: 18, grain: :horizontal },
            { name: 'Nóc tủ',      l: 564, w: 560, t: 18, grain: :horizontal },
            { name: 'Cánh tủ',     l: 600, w: 820, t: 18, grain: :vertical }
          ]
        },
        {
          id:          'kitchen_base_corner',
          name:        'Tủ bếp dưới góc',
          category:    'bếp',
          thumbnail:   'kitchen_base_corner.png',
          file:        'kitchen_base_corner.skp',
          dimensions:  { length: 900, width: 900, height: 820 },
          panels: [
            { name: 'Vách A',      l: 882, w: 820, t: 18, grain: :vertical },
            { name: 'Vách B',      l: 882, w: 820, t: 18, grain: :vertical },
            { name: 'Vách hậu A',  l: 900, w: 820, t: 18, grain: :vertical },
            { name: 'Vách hậu B',  l: 882, w: 820, t: 18, grain: :vertical },
            { name: 'Sàn tủ',      l: 882, w: 882, t: 18, grain: :horizontal }
          ]
        },
        {
          id:          'kitchen_upper_600',
          name:        'Tủ bếp trên 600mm',
          category:    'bếp',
          thumbnail:   'kitchen_upper_600.png',
          file:        'kitchen_upper_600.skp',
          dimensions:  { length: 600, width: 350, height: 700 },
          panels: [
            { name: 'Vách trái',    l: 350, w: 700, t: 18, grain: :vertical },
            { name: 'Vách phải',   l: 350, w: 700, t: 18, grain: :vertical },
            { name: 'Vách hậu',    l: 600, w: 700, t: 18, grain: :vertical },
            { name: 'Sàn tủ trên', l: 564, w: 350, t: 18, grain: :horizontal },
            { name: 'Nóc tủ trên', l: 564, w: 350, t: 18, grain: :horizontal },
            { name: 'Cánh trên',   l: 600, w: 700, t: 18, grain: :vertical }
          ]
        },
        {
          id:          'wardrobe_2door',
          name:        'Tủ áo 2 cánh',
          category:    'phòng ngủ',
          thumbnail:   'wardrobe_2door.png',
          file:        'wardrobe_2door.skp',
          dimensions:  { length: 1200, width: 600, height: 2100 },
          panels: [
            { name: 'Vách trái',    l: 600, w: 2100, t: 18, grain: :vertical },
            { name: 'Vách phải',   l: 600, w: 2100, t: 18, grain: :vertical },
            { name: 'Vách hậu',    l: 1200, w: 2100, t: 18, grain: :vertical },
            { name: 'Nóc',         l: 1164, w: 600,  t: 18, grain: :horizontal },
            { name: 'Sàn tủ',      l: 1164, w: 600,  t: 18, grain: :horizontal },
            { name: 'Kệ giữa',     l: 1164, w: 570,  t: 18, grain: :horizontal },
            { name: 'Cánh trái',   l: 600,  w: 2100, t: 18, grain: :vertical },
            { name: 'Cánh phải',   l: 600,  w: 2100, t: 18, grain: :vertical }
          ]
        },
        {
          id:          'drawer_single',
          name:        'Ngăn kéo đơn',
          category:    'phòng ngủ',
          thumbnail:   'drawer_single.png',
          file:        'drawer_single.skp',
          dimensions:  { length: 500, width: 450, height: 150 },
          panels: [
            { name: 'Mặt ngăn kéo', l: 500, w: 150, t: 18, grain: :horizontal },
            { name: 'Vách trái',    l: 432, w: 132, t: 9, grain: :horizontal },
            { name: 'Vách phải',   l: 432, w: 132, t: 9, grain: :horizontal },
            { name: 'Vách hậu',    l: 482, w: 132, t: 9, grain: :horizontal },
            { name: 'Đáy',         l: 482, w: 432, t: 9, grain: :none }
          ]
        },
        {
          id:          'bookshelf_simple',
          name:        'Kệ sách đơn giản',
          category:    'phòng khách',
          thumbnail:   'bookshelf_simple.png',
          file:        'bookshelf_simple.skp',
          dimensions:  { length: 800, width: 300, height: 1200 },
          panels: [
            { name: 'Vách trái',    l: 300, w: 1200, t: 18, grain: :vertical },
            { name: 'Vách phải',   l: 300, w: 1200, t: 18, grain: :vertical },
            { name: 'Vách hậu',    l: 800, w: 1200, t: 9,  grain: :none },
            { name: 'Nóc',         l: 764, w: 300,  t: 18, grain: :horizontal },
            { name: 'Sàn',         l: 764, w: 300,  t: 18, grain: :horizontal },
            { name: 'Kệ 1',        l: 764, w: 280,  t: 18, grain: :horizontal },
            { name: 'Kệ 2',        l: 764, w: 280,  t: 18, grain: :horizontal },
            { name: 'Kệ 3',        l: 764, w: 280,  t: 18, grain: :horizontal }
          ]
        }
      ].freeze

      def self.all_templates
        built_in = BUILT_IN_TEMPLATES.dup
        user     = load_user_templates
        built_in + user
      end

      def self.find_template(id)
        all_templates.find { |t| t[:id] == id.to_s }
      end

      def self.templates_by_category(category)
        all_templates.select { |t| t[:category] == category.to_s }
      end

      def self.categories
        all_templates.map { |t| t[:category] }.uniq.sort
      end

      # Insert a template into the model
      # Returns array of ComponentInstances created
      # ML-02: clone, make_unique, assign AttributeDictionary
      def self.insert_template(template_id, position = ORIGIN)
        tmpl = find_template(template_id)
        unless tmpl
          ::UI.messagebox("Không tìm thấy template: #{template_id}")
          return []
        end

        instances = []

        PanelCore::UndoWrapper.run("Chèn #{tmpl[:name]}") do
          model    = Sketchup.active_model
          group_defn = model.definitions.add("#{tmpl[:name]}_Group")

          tmpl[:panels].each_with_index do |panel_def, idx|
            panel_name = "#{tmpl[:name]}_#{panel_def[:name]}"

            # Create each sub-panel definition
            defn = PanelCore::ComponentManager.create_panel_definition(
              panel_def[:l],
              panel_def[:w],
              panel_def[:t],
              panel_name
            )

            # Build attributes
            attrs = {
              'part_name'       => panel_def[:name],
              'material_id'     => 'melamine_18',
              'grain_direction' => panel_def[:grain].to_s,
              'thickness_mm'    => panel_def[:t].to_f,
              'is_template'     => false,
              'notes'           => '',
              'created_at'      => Time.now.to_i
            }

            # ML-02: assign AttributeDictionary AFTER make_unique
            PanelCore::AttributeManager.write(defn, attrs)

            # Stack panels along Y axis for preview
            offset = Geom::Transformation.translation(
              Geom::Vector3d.new(0, idx * PanelCore::ComponentManager.mm_to_su(panel_def[:l] + 20), 0)
            )
            inst = model.active_entities.add_instance(defn, offset)
            inst.name = panel_def[:name]
            instances << inst
          end
        end

        instances
      end

      # ML-06: Save current selection as user template
      def self.save_selection_as_template(name, category)
        sel = Sketchup.active_model.selection.to_a
        panels = sel.select { |e| PanelCore::AttributeManager.panel?(e) }

        if panels.empty?
          ::UI.messagebox('Không có tấm ván nào được chọn để lưu vào thư viện.')
          return false
        end

        FileUtils.mkdir_p(USER_DIR) unless Dir.exist?(USER_DIR)

        id = name.downcase.gsub(/\s+/, '_').gsub(/[^a-z0-9_]/, '')
        template = {
          id:       id,
          name:     name,
          category: category,
          user:     true,
          panels:   panels.map { |p|
            attrs = PanelCore::AttributeManager.read(p)
            {
              name:  attrs['part_name'] || p.definition.name,
              l:     (attrs['thickness_mm'] || 600).to_f,
              w:     400.0,
              t:     (attrs['thickness_mm'] || 18).to_f,
              grain: (attrs['grain_direction'] || 'horizontal').to_sym
            }
          }
        }

        file = File.join(USER_DIR, "#{id}.json")
        File.write(file, template.to_json)
        puts "[TemplateManager] Saved user template: #{file}"
        true
      end

      private

      def self.load_user_templates
        return [] unless Dir.exist?(USER_DIR)
        templates = []
        Dir.glob(File.join(USER_DIR, '*.json')).each do |f|
          begin
            data = JSON.parse(File.read(f), symbolize_names: true)
            templates << data
          rescue => e
            puts "[TemplateManager] Failed to load #{f}: #{e.message}"
          end
        end
        templates
      end
    end
  end
end
