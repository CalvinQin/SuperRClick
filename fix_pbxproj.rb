require 'xcodeproj'

project_path = 'SuperRClick.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'SuperRClick' }

# Define files to add
new_files = [
  'App/Features/Settings/LanguageManager.swift',
  'App/Features/Settings/AppModeManager.swift',
  'App/Features/Update/GitHubUpdater.swift'
]

new_files.each do |file_path|
  # We can just add the file using path relative to project root
  # by finding the group dynamically or creating it
  group_names = File.dirname(file_path).split('/')
  
  current_group = project.main_group
  group_names.each do |group_name|
    matched_group = current_group.groups.find { |g| g.path == group_name || g.name == group_name }
    if matched_group.nil?
      matched_group = current_group.new_group(group_name, group_name)
    end
    current_group = matched_group
  end
  
  filename = File.basename(file_path)
  file_reference = current_group.files.find { |f| f.path == filename }
  
  if file_reference.nil?
    file_reference = current_group.new_file(filename)
    puts "Created file reference for #{filename}"
  end
  
  if !target.source_build_phase.files_references.include?(file_reference)
    target.source_build_phase.add_file_reference(file_reference)
    puts "Added #{filename} to compile sources."
  else
    puts "#{filename} already in compile sources."
  end
end

project.save
puts "Successfully saved project!"
