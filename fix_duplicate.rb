require 'xcodeproj'
require 'fileutils'

project_path = 'BusTimeApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)
widget_target = project.targets.find { |t| t.name == 'BusTimeWidgetExtension' }

# Find the file reference for the duplicated file in the widget group
group = project.main_group['BusTimeWidgetExtension']
if group
  file_ref = group.files.find { |f| f.path == 'BusActivityAttributes.swift' }
  if file_ref
    # Remove from build phase
    widget_target.source_build_phase.files_references.delete(file_ref)
    
    # Remove from group
    file_ref.remove_from_project
    
    puts "Removed duplicate file reference from project."
  end
end

project.save

# Delete the duplicated physical file
FileUtils.rm_f('BusTimeWidgetExtension/BusActivityAttributes.swift')
puts "Deleted duplicate physical file."

