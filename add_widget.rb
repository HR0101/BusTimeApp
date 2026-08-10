require 'xcodeproj'
require 'fileutils'

project_path = 'BusTimeApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

if project.targets.any? { |t| t.name == 'BusTimeWidgetExtension' }
  puts "Target already exists"
  exit
end

app_target = project.targets.find { |t| t.name == 'BusTimeApp' }

# 1. Add NSSupportsLiveActivities to BusTimeApp target
app_target.build_configuration_list.build_configurations.each do |config|
  config.build_settings['INFOPLIST_KEY_NSSupportsLiveActivities'] = 'YES'
end

# 2. Create Widget Extension Target
widget_target = project.new_target(:app_extension, 'BusTimeWidgetExtension', :ios, '16.1')

# 3. Create Group and files
group = project.main_group.new_group('BusTimeWidgetExtension', 'BusTimeWidgetExtension')
FileUtils.mkdir_p('BusTimeWidgetExtension')

# Create BusTimeWidgetLiveActivity.swift
widget_code = <<~SWIFT
import ActivityKit
import WidgetKit
import SwiftUI

struct BusTimeWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusActivityAttributes.self) { context in
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "bus.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.blue)
                        .clipShape(Circle())
                    Text("\\(context.attributes.busDepartureTime) 発")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    Text(context.attributes.busArrivalTime)
                        .font(.title3.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                }
                HStack {
                    Text(context.attributes.routeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if context.state.isDeparted {
                        Text("出発済み")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.gray)
                            .clipShape(Capsule())
                    } else {
                        Text("あと \\(context.state.remainingMinutes) 分")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(15)
            .activityBackgroundTint(Color(UIColor.systemGroupedBackground))
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.busDepartureTime, systemImage: "bus.fill")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.state.isDeparted {
                        Text("\\(context.state.remainingMinutes) 分")
                            .font(.title2.bold())
                            .foregroundColor(.red)
                    } else {
                        Text("出発済")
                            .foregroundColor(.gray)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.routeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } compactLeading: {
                Image(systemName: "bus.fill")
                    .foregroundColor(.blue)
            } compactTrailing: {
                if !context.state.isDeparted {
                    Text("\\(context.state.remainingMinutes)m")
                        .foregroundColor(.red)
                        .bold()
                } else {
                    Text("--")
                }
            } minimal: {
                Image(systemName: "bus.fill")
                    .foregroundColor(.blue)
            }
        }
    }
}
SWIFT

File.write('BusTimeWidgetExtension/BusTimeWidgetLiveActivity.swift', widget_code)
file_ref = group.new_file('BusTimeWidgetLiveActivity.swift')
widget_target.source_build_phase.add_file_reference(file_ref)

# Create BusTimeWidgetBundle.swift
bundle_code = <<~SWIFT
import WidgetKit
import SwiftUI

@main
struct BusTimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        BusTimeWidgetLiveActivity()
    }
}
SWIFT
File.write('BusTimeWidgetExtension/BusTimeWidgetBundle.swift', bundle_code)
bundle_ref = group.new_file('BusTimeWidgetBundle.swift')
widget_target.source_build_phase.add_file_reference(bundle_ref)

# Duplicate BusActivityAttributes.swift into Widget target because Xcode 16 synchronized groups are weird with xcodeproj gem
FileUtils.cp('BusTimeApp/BusActivityAttributes.swift', 'BusTimeWidgetExtension/BusActivityAttributes.swift')
attr_ref = group.new_file('BusActivityAttributes.swift')
widget_target.source_build_phase.add_file_reference(attr_ref)

# 4. Set up Widget build settings
widget_target.build_configuration_list.build_configurations.each do |config|
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['INFOPLIST_KEY_NSExtensionPointIdentifier'] = 'com.apple.widgetkit-extension'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.hara.BusTimeApp.BusTimeWidgetExtension'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME'] = 'WidgetBackground'
end

# 5. Embed the extension in the app target
embed_phase = app_target.new_copy_files_build_phase('Embed Foundation Extensions')
embed_phase.dst_subfolder_spec = '13' # Plugins
embed_phase.add_file_reference(widget_target.product_reference, true)

# 6. Add target dependency
app_target.add_dependency(widget_target)

project.save
puts "Successfully added BusTimeWidgetExtension target and configured Live Activities!"
