# encoding: UTF-8
# =============================================================================
# Panel Plugin - Plugin SketchUp Nội Thất
# Sprint 1: Core Data & Paneling
# =============================================================================

require 'sketchup.rb'
require 'extensions.rb'

module PanelPlugin
  PLUGIN_DIR = File.dirname(__FILE__)

  # Load all core modules
  def self.load_modules
    load File.join(PLUGIN_DIR, 'panel_core', 'version.rb')
    load File.join(PLUGIN_DIR, 'panel_core', 'grain_direction.rb')
    load File.join(PLUGIN_DIR, 'panel_core', 'validator.rb')
    load File.join(PLUGIN_DIR, 'panel_core', 'attribute_manager.rb')
    load File.join(PLUGIN_DIR, 'panel_core', 'component_manager.rb')
    load File.join(PLUGIN_DIR, 'panel_core', 'undo_wrapper.rb')
    
    # ABF Integration - Schema chuẩn hóa thuộc tính
    load File.join(PLUGIN_DIR, '..', 'lib', 'abf', 'schema.rb')
    
    load File.join(PLUGIN_DIR, 'core', 'groove_engine.rb')
    load File.join(PLUGIN_DIR, 'core', 'kerf_engine.rb')
    load File.join(PLUGIN_DIR, 'core', 'joinery_engine.rb')
    load File.join(PLUGIN_DIR, 'tools', 'quick_panel_tool.rb')
    load File.join(PLUGIN_DIR, 'tools', 'select_panel_tool.rb')
    load File.join(PLUGIN_DIR, 'tools', 'face_to_panel.rb')
    load File.join(PLUGIN_DIR, 'tools', 'change_thickness.rb')
    load File.join(PLUGIN_DIR, 'tools', 'fillet_tool.rb')
    load File.join(PLUGIN_DIR, 'tools', 'mortise_tenon_tool.rb')
    load File.join(PLUGIN_DIR, 'tools', 'flatten_curve_tool.rb')
    load File.join(PLUGIN_DIR, 'tools', 'export_dxf_tool.rb')
    load File.join(PLUGIN_DIR, 'tools', 'cabinet_builder_tool.rb')
    load File.join(PLUGIN_DIR, 'tools', 'production_shelf_tool.rb')
    load File.join(PLUGIN_DIR, 'tools', 'shelf_divider_tool.rb')
    load File.join(PLUGIN_DIR, 'ui', 'library_panel.rb')
    load File.join(PLUGIN_DIR, 'ui', 'cabinet_builder_panel.rb')
    load File.join(PLUGIN_DIR, 'ui', 'divider_builder_panel.rb')
    load File.join(PLUGIN_DIR, 'library', 'template_manager.rb')
  end

  def self.register_menu
    menu = ::UI.menu('Plugins').add_submenu('Panel Plugin')

    menu.add_item('Tạo Tấm Ván (Quick Panel)') do
      PanelPlugin::Tools::QuickPanelTool.run
    end

    menu.add_item('Tạo Ván Từ Mặt 2D') do
      PanelPlugin::Tools::FaceToPanel.run
    end

    menu.add_item('Chọn Tấm Ván') do
      Sketchup.active_model.select_tool(PanelPlugin::Tools::SelectPanelTool.new)
    end

    menu.add_separator

    menu.add_item('Đổi Độ Dày Ván (Ctrl+Shift+E)') do
      PanelPlugin::Tools::ChangeThickness.run
    end

    menu.add_item('Bo Cạnh Ván (Fillet Corner)') do
      PanelPlugin::Tools::FilletTool.run
    end

    menu.add_item('Đánh Mộng CNC (Âm Dương)') do
      PanelPlugin::Tools::MortiseTenonTool.run
    end

    menu.add_item('Trải Mặt Cong (Flatten Curve)') do
      PanelPlugin::Tools::FlattenCurveTool.run
    end

    menu.add_item('Xuất DXF cho ABF Nesting') do
      PanelPlugin::Tools::ExportDxfTool.run
    end

    menu.add_item('🏗 Xây Tủ Base (Cabinet Builder)') do
      PanelPlugin::UI::CabinetBuilderPanel.show
    end

    menu.add_item('📐 Chia Đợt / Vách Nội Thất') do
      PanelPlugin::UI::DividerBuilderPanel.show
    end

    menu.add_item('🎯 Tạo Đợt (Raycast - Production)') do
      Sketchup.active_model.select_tool(PanelPlugin::Tools::ProductionShelfTool.new)
    end

    menu.add_item('📏 Chia Đợt Kệ (Shelf Divider)') do
      Sketchup.active_model.select_tool(PanelPlugin::Tools::ShelfDividerTool.new)
    end

    menu.add_item('Thư viện Module') do
      PanelPlugin::UI::LibraryPanel.show
    end

    menu.add_separator

    menu.add_item('Cài đặt') do
      show_settings_dialog
    end
  end

  def self.register_toolbar
    toolbar = ::UI::Toolbar.new('Panel Plugin')
    icons_dir = File.join(PLUGIN_DIR, 'icons')

    # Quick Panel Tool button
    cmd_quick = ::UI::Command.new('Tạo Tấm Ván') do
      PanelPlugin::Tools::QuickPanelTool.run
    end
    cmd_quick.tooltip         = 'Quick Panel Tool - Tạo tấm ván nhanh'
    cmd_quick.status_bar_text = 'Hiển thị hộp thoại tạo tấm ván theo kích thước'
    cmd_quick.small_icon      = File.join(icons_dir, 'quick_panel_24.png')
    cmd_quick.large_icon      = File.join(icons_dir, 'quick_panel_48.png')
    toolbar.add_item(cmd_quick)

    # Face to Panel button
    cmd_f2p = ::UI::Command.new('Ván từ 2D') do
      PanelPlugin::Tools::FaceToPanel.run
    end
    cmd_f2p.tooltip         = 'Tạo Ván Từ Mặt 2D'
    cmd_f2p.status_bar_text = 'Chuyển các mặt phẳng 2D đang chọn thành tấm ván'
    cmd_f2p.small_icon      = File.join(icons_dir, 'face_to_panel_24.png')
    cmd_f2p.large_icon      = File.join(icons_dir, 'face_to_panel_48.png')
    toolbar.add_item(cmd_f2p)

    # Change Thickness button
    cmd_attr = ::UI::Command.new('Đổi Độ Dày') do
      PanelPlugin::Tools::ChangeThickness.run
    end
    cmd_attr.tooltip         = 'Đổi Độ Dày Ván (Ctrl+Shift+E)'
    cmd_attr.status_bar_text = 'Thay đổi chiều dày cho các tấm ván đang được chọn'
    cmd_attr.small_icon      = File.join(icons_dir, 'change_thickness_24.png')
    cmd_attr.large_icon      = File.join(icons_dir, 'change_thickness_48.png')
    toolbar.add_item(cmd_attr)

    # Fillet Tool button
    cmd_fillet = ::UI::Command.new('Bo Góc') do
      PanelPlugin::Tools::FilletTool.run
    end
    cmd_fillet.tooltip         = 'Bo Tròn Cạnh Ván CNC (Fillet)'
    cmd_fillet.status_bar_text = 'Click vào góc ván dọc để bo tròn'
    cmd_fillet.small_icon      = File.join(icons_dir, 'fillet_tool_24.png')
    cmd_fillet.large_icon      = File.join(icons_dir, 'fillet_tool_48.png')
    toolbar.add_item(cmd_fillet)

    # Flatten Curve button
    cmd_flatten = ::UI::Command.new('Trải Cong') do
      PanelPlugin::Tools::FlattenCurveTool.run
    end
    cmd_flatten.tooltip         = 'Trải Phẳng Mặt Cong (Flatten)'
    cmd_flatten.status_bar_text = 'Phân tích mặt cong thành tấm ván với các rãnh cắt dao'
    cmd_flatten.small_icon      = File.join(icons_dir, 'face_to_panel_24.png') # Tạm dùng icon face
    cmd_flatten.large_icon      = File.join(icons_dir, 'face_to_panel_48.png')
    toolbar.add_item(cmd_flatten)

    # Cabinet Builder button
    cmd_cab = ::UI::Command.new('Xây Tủ Base') do
      PanelPlugin::UI::CabinetBuilderPanel.show
    end
    cmd_cab.tooltip         = 'Xây Tủ Base – Cabinet Builder'
    cmd_cab.status_bar_text = 'Mở công cụ xây tủ base hoàn chỉnh với preview trực quan'
    cmd_cab.small_icon      = File.join(icons_dir, 'library_panel_24.png')
    cmd_cab.large_icon      = File.join(icons_dir, 'library_panel_48.png')
    toolbar.add_item(cmd_cab)

    # Library Panel button
    cmd_lib = ::UI::Command.new('Thư viện') do
      PanelPlugin::UI::LibraryPanel.show
    end
    cmd_lib.tooltip         = 'Thư viện module tủ chuẩn'
    cmd_lib.status_bar_text = 'Mở thư viện template tủ để chèn vào model'
    cmd_lib.small_icon      = File.join(icons_dir, 'library_panel_24.png')
    cmd_lib.large_icon      = File.join(icons_dir, 'library_panel_48.png')
    toolbar.add_item(cmd_lib)

    # Production Shelf Tool button
    cmd_pshelf = ::UI::Command.new('Tạo Đợt') do
      Sketchup.active_model.select_tool(PanelPlugin::Tools::ProductionShelfTool.new)
    end
    cmd_pshelf.tooltip         = 'Production Shelf Tool - Tạo đợt trong khoang trống'
    cmd_pshelf.status_bar_text = 'Bấm vào khoang trống bất kỳ để tự động nhận dạng và chia đợt'
    cmd_pshelf.small_icon      = File.join(icons_dir, 'library_panel_24.png')
    cmd_pshelf.large_icon      = File.join(icons_dir, 'library_panel_48.png')
    toolbar.add_item(cmd_pshelf)

    # Shelf Divider Tool button
    cmd_sdiv = ::UI::Command.new('Chia Đợt Kệ') do
      Sketchup.active_model.select_tool(PanelPlugin::Tools::ShelfDividerTool.new)
    end
    cmd_sdiv.tooltip         = 'Shelf Divider – Chia đợt kệ theo khoang trong'
    cmd_sdiv.status_bar_text = 'Double-click vào khoang tủ, sau đó click mặt phẳng bên trong để chia đợt kệ'
    cmd_sdiv.small_icon      = File.join(icons_dir, 'library_panel_24.png')
    cmd_sdiv.large_icon      = File.join(icons_dir, 'library_panel_48.png')
    toolbar.add_item(cmd_sdiv)

    toolbar.restore
  end


  def self.register_shortcuts
    ::UI.add_context_menu_handler do |menu|
      sel = Sketchup.active_model.selection
      
      # 1. Edit Parametric Cabinet
      if sel.count == 1 && sel.first.is_a?(Sketchup::Group)
        grp = sel.first
        dict = grp.attribute_dictionary('panel_cabinet')
        if dict && dict['is_parametric']
          menu.add_item('Sửa Tủ Base (Edit Cabinet)') do
            PanelPlugin::UI::CabinetBuilderPanel.show(grp)
          end
          menu.add_item('📏 Chia Đợt Kệ (Shelf Divider)') do
            Sketchup.active_model.select_tool(PanelPlugin::Tools::ShelfDividerTool.new)
          end
        end
      end

      # 2. Change Thickness
      has_solid = sel.any? { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }
      if has_solid
        menu.add_separator
        menu.add_item('Đổi chiều dày tấm ván') do
          PanelPlugin::Tools::ChangeThickness.run
        end
      end
    end
  end

  def self.show_settings_dialog
    default_thickness = Sketchup.read_default('panel_plugin', 'default_thickness', 18.0)
    prompts = ['Chiều dày mặc định (mm):']
    defaults = [default_thickness.to_s]
    input = ::UI.inputbox(prompts, defaults, 'Cài đặt Panel Plugin')
    if input
      thickness = input[0].to_f
      if thickness >= 3.0
        Sketchup.write_default('panel_plugin', 'default_thickness', thickness)
        ::UI.messagebox("Đã lưu chiều dày mặc định: #{thickness}mm")
      else
        ::UI.messagebox('Chiều dày phải >= 3mm')
      end
    end
  end

  # Initialize plugin
  def self.initialize_plugin
    load_modules
    
    unless file_loaded?(__FILE__)
      register_menu
      register_toolbar
      register_shortcuts
      file_loaded(__FILE__)
      puts "[PanelPlugin v#{PanelCore::VERSION}] Loaded successfully."
    else
      puts "[PanelPlugin v#{PanelCore::VERSION}] Reloaded modules successfully."
    end
  end
end

# Start the plugin
PanelPlugin.initialize_plugin
