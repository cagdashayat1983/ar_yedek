def flutter_root
  # 1. Önce Codemagic/Sistem değişkenlerine bak (En güvenli yol)
  return ENV['FLUTTER_ROOT'] if ENV['FLUTTER_ROOT']

  # 2. Eğer bulamazsa dosyadan oku (Lokal çalışma için)
  generated_xcode_build_settings_path = File.expand_path('Generated.xcconfig', File.dirname(__FILE__))
  
  if File.exist?(generated_xcode_build_settings_path)
    File.foreach(generated_xcode_build_settings_path) do |line|
      matches = line.match(/\AFLUTTER_ROOT=(.*)\z/)
      return matches[1].strip if matches
    end
  end

  # 3. Hiçbir yerde yoksa hata verme, boş dön (Flutter build süreci bunu sonra tamamlar)
  ""
end

# Flutter SDK içindeki asıl podhelper'ı yükle
f_root = flutter_root
if !f_root.empty?
  require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), f_root)
end