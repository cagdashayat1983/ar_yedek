def flutter_root
  # Generated.xcconfig dosyası, bu script ile aynı klasörde (ios/Flutter/) olmalı
  generated_xcode_build_settings_path = File.expand_path('Generated.xcconfig', File.dirname(__FILE__))
  
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} bulunamadı. Lütfen önce 'flutter pub get' çalıştırın."
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/\AFLUTTER_ROOT=(.*)\z/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT, #{generated_xcode_build_settings_path} içinde bulunamadı."
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)