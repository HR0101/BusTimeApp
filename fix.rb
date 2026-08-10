require 'xcodeproj'
project_path = 'BusTimeApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)
widget_target = project.targets.find { |t| t.name == 'BusTimeWidgetExtension' }
widget_target.build_configuration_list.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
end
project.save
