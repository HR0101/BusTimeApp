require 'xcodeproj'

project_path = 'BusTimeApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)
widget_target = project.targets.find { |t| t.name == 'BusTimeWidgetExtension' }

info_plist_content = <<~XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.widgetkit-extension</string>
	</dict>
</dict>
</plist>
XML

File.write('BusTimeWidgetExtension/Info.plist', info_plist_content)

widget_target.build_configuration_list.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = 'BusTimeWidgetExtension/Info.plist'
  config.build_settings.delete('INFOPLIST_KEY_NSExtensionPointIdentifier')
end

project.save
puts "Fixed Info.plist for widget."
