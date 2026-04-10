# encoding: UTF-8
# =============================================================================
# dev_reload.rb — HOT RELOAD helper cho development
# Copy file nay vao SketchUp Plugins folder MOT LAN
# Sau do trong Ruby Console goi: PanelPlugin.reload!
# =============================================================================

# Duong dan toi thu muc development cua ban
DEV_PLUGIN_DIR = 'd:/plugin'.freeze

module PanelPlugin
  # Reload toan bo plugin tu thu muc development
  # Goi lenh nay trong Ruby Console bat cu luc nao muon test code moi
  def self.reload!
    t0 = Time.now

    # Load lai tung file .rb trong panel_plugin/
    dir = File.join(DEV_PLUGIN_DIR, 'panel_plugin')
    files = Dir.glob(File.join(dir, '**', '*.rb')).sort

    loaded = 0
    errors = []

    files.each do |f|
      begin
        load f
        loaded += 1
      rescue => e
        errors << "  [ERROR] #{File.basename(f)}: #{e.message}"
      end
    end

    elapsed = ((Time.now - t0) * 1000).round(1)

    puts "\n" + "="*50
    puts "[PanelPlugin] Reload xong trong #{elapsed}ms"
    puts "  Loaded: #{loaded} files"
    if errors.empty?
      puts "  Status: OK"
    else
      puts "  Loi:"
      errors.each { |e| puts e }
    end
    puts "="*50 + "\n"

    errors.empty?
  end

  # Chi reload 1 file cu the (khi sua 1 tool)
  # Vi du: PanelPlugin.reload_file('tools/cabinet_builder_tool.rb')
  def self.reload_file(relative_path)
    full = File.join(DEV_PLUGIN_DIR, 'panel_plugin', relative_path)
    if File.exist?(full)
      load full
      puts "[reload] OK: #{relative_path}"
      true
    else
      puts "[reload] KHONG THAY FILE: #{full}"
      false
    end
  end
end

puts "[dev_reload] San sang! Goi PanelPlugin.reload! trong Ruby Console bat cu luc nao."
