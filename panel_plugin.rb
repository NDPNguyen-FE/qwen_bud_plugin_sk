# encoding: UTF-8
# =============================================================================
# panel_plugin.rb — Loader file cho Panel Plugin SketchUp Nội Thất
# Đặt file này trong thư mục Plugins, cùng cấp với thư mục panel_plugin/
# =============================================================================

require 'sketchup.rb'
require 'extensions.rb'

module PanelPlugin
  PLUGIN_DIR = File.join(File.dirname(__FILE__), 'panel_plugin')

  unless defined?(EXTENSION)
    EXTENSION = SketchupExtension.new(
      'Panel Plugin - Nội Thất',
      File.join(PLUGIN_DIR, 'main.rb')
    )
    EXTENSION.description = 'Plugin thiết kế nội thất: tạo tấm ván, quản lý vật liệu, thư viện module tủ.'
    EXTENSION.version     = '1.0.0'
    EXTENSION.copyright   = '2026 Core Team'
    Sketchup.register_extension(EXTENSION, true)
  end
end
