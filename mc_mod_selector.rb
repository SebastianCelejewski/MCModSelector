require 'zip'
require 'yaml'

puts "Minecraft mod selector"

def scan_mods(directory)
	mods = []

	jars = Dir["#{directory}/*.jar"]
	jars.each do |jar|
		puts "Analysing #{jar}"
		jarWithMods = {filename:File.basename(jar), enabled:false, mods:[]}		
		begin
			Zip::File.open(jar) do |jar_contents|
				modinfo_yaml_entry = jar_contents.glob("mcmod.info").first
				next if modinfo_yaml_entry == nil
				modinfo_yaml = modinfo_yaml_entry.get_input_stream.read
				modinfo = YAML.load(modinfo_yaml)
				if modinfo.class == Array
					modinfo.each { |mod| jarWithMods[:mods] << mod }
				else
					modinfo['modList'].each { |mod| jarWithMods[:mods] << mod }
				end
			end
		rescue
			puts "Cannot read #{jar}. Skipping"
		end
		mods << jarWithMods
	end

	return mods
end

if ARGV.length != 2
	puts "Usage: ruby mc_mod_selector.rb <directory_with_available_mods> <minecraft_mods_directory>"
	abort
end

def m2s(mod)
	return "name: #{mod['name']}, version: #{mod['version']}, Minecraft version: #{mod['mcversion']}, required mods: #{mod['requiredMods']}"
end

available_mods_dir = ARGV[0].gsub("\\","/")
minecraft_mods_dir = ARGV[1].gsub("\\","/")

available_mods = scan_mods(available_mods_dir)
enabled_mods = scan_mods(minecraft_mods_dir)

full_mod_list = available_mods
full_mod_list.each do |modfile|
	if enabled_mods.include?(modfile)
		modfile[:enabled] = true
	end
end

def s(text, length)
	text = "" if text == nil
	text = text[0..length-1]
	while text.length < length
		text += " "
	end
	return text
end

error_message = ""

begin
	puts ""
	puts " ID | Enabled | File name                      | Mod name                  | Mod version     | Minecraft version"
	puts "----+---------|--------------------------------+---------------------------+-----------------+----------------"
	full_mod_list.each_with_index do |modfile, idx|
		puts "#{s((idx+1).to_s,3)} |   #{modfile[:enabled]?"yes":"no "}   | #{s(modfile[:filename],30)} | #{s(modfile[:mods].map{|x| x['name']}.join(","),25)} | #{s(modfile[:mods].map{|x| x['version']}.join(","),15)} | #{s(modfile[:mods].map{|x| x['mcversion']}.join(","),15)}"
	end

	puts ""
	if error_message.length > 0
		puts "MESSAGE: #{error_message}"
	end
	puts "Which mod you want to enable or disable?"

	modid = STDIN.gets.chomp.to_i

	if modid > 0 && modid <= full_mod_list.length
		full_mod_list[modid-1][:enabled] = !full_mod_list[modid-1][:enabled]

		filename = full_mod_list[modid-1][:filename]
		enabled = full_mod_list[modid-1][:enabled]

		if enabled == true
			source_location = "#{available_mods_dir}/#{filename}"
			target_location = "#{minecraft_mods_dir}/#{filename}"
			FileUtils.cp(source_location, target_location)
			error_message = "File #{filename} added to Minecraf mods"
		else
			target_location = "#{minecraft_mods_dir}/#{filename}"
			FileUtils::chmod(0644, target_location)
			FileUtils.rm(target_location)
			error_message = "File #{filename} removed from Minecraf mods"
		end
	else
		error_message = "Number out of the range"
	end

end while true