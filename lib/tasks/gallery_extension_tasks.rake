require 'tempfile'

def start_section(msg)
  desc msg
  puts
  puts msg
  puts
end

namespace :radiant do
  namespace :extensions do
    namespace :gallery do

      start_section("Runs the migration of the Gallery extension")
      task :migrate => :environment do
        require 'radiant/extension_migrator'
        if ENV["VERSION"]
          GalleryExtension.migrator.migrate(ENV["VERSION"].to_i)
        else
          GalleryExtension.migrator.migrate
        end
      end

      start_section("Copies public assets of the Gallery to the instance public/ directory.")
      task :update => :environment do
        is_svn_or_dir = proc {|path| path =~ /\.svn/ || File.directory?(path) }

        Dir[GalleryExtension.root + "/public/**/*"].reject(&is_svn_or_dir).each do |file|
          path = file.sub(GalleryExtension.root, '')
          directory = File.dirname(path)

          puts "Copying #{path}..."
          mkdir_p RAILS_ROOT + directory
          cp file, RAILS_ROOT + path
        end

        puts "Copy lightbox graphics to public/assets directory"
        dir = RAILS_ROOT + "/public/assets"
        mkdir_p dir
        cp RAILS_ROOT + "/public/images/extensions/gallery/lightbox/closelabel.gif", dir
        cp RAILS_ROOT + "/public/images/extensions/gallery/lightbox/loading.gif", dir
      end




      # Select layout
      task :import_layouts => :environment do
        layouts_path = File.join(GalleryExtension.root, 'layouts')
        extension = ".radius"

        # Build a list of layouts
        layouts = Dir[File.join(layouts_path, "*#{extension}")].collect do |path|
          filename = File.basename(path)
          {
            :path => path,
            :name => filename[0...(filename.size - extension.size)].humanize
          }
        end

        puts
        puts "Select which layout to create (leave blank to skip):"

        # Go through each layout and print the options on the screen.
        layouts.each_with_index do |layout, index|
          puts "#{index + 1}. #{layout[:name]}"
        end

        # Prompt user for selection.
        print "[1-#{layouts.size}] values separated by commas: "
        answer = STDIN.gets.chomp

        layouts_to_install = answer.split(',').collect{|number| number.strip.to_i}

        layouts_to_install.each do |number|
          if (1..layouts.size).include?(number)
            layout = layouts[number-1]
            print "Importing layout '#{layout[:name]}'..."

            File.open(layout[:path], 'r') do |file|
              original_name = "Gallery layout - #{layout[:name]}"
              name, i = original_name, 1

              while Layout.find_by_name(name) do
                name = "#{original_name} (#{i += 1})"
              end

              #TODO: add created by
              Layout.create(:name => name, :content => file.read, :content_type => "text/html" )
              puts 'OK'
            end
          else
            puts "Error: #{number} is not a valid layout."
          end
        end
      end

      start_section "Create gallery.yml file"
      task :create_config_file do
        config_path = File.join(RAILS_ROOT, 'config', 'extensions', 'gallery')
        mkdir_p(config_path)
        %w[gallery content_types].each do |name|
          default_config_file = File.join(File.dirname(__FILE__), '../../', 'config', "#{name}.yml.default")
          config_file = File.join(config_path, "#{name}.yml")
          if File.exists?(default_config_file) && !File.exists?(config_file)
            FileUtils.cp(default_config_file, config_file)
          end
        end
      end

      start_section "Migrates and copies files in public/admin"
      task :install => [:create_config_file, :environment, :migrate, :update, :import_layouts] do
        puts
        puts "\nGallery extension has been installed."
        puts "1. Create a new page with 'Gallery' as page type."
        puts "2. Select a gallery layout for your page."
        puts "3. Start creating your galleries."
      end

      start_section "Report Gallery statistics"
      task :stats => :environment do
        require 'gallery_statistics.rb'
        GalleryStatistics.new.to_s
      end

    end
  end
end unless __FILE__.include? '_darcs'
