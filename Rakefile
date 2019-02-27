$LOAD_PATH.unshift 'lib'

require 'scraper'

def build_download_script(episodes)
  lines = ['#!/bin/sh', '']

  episodes.each do |episode|
    id = episode['id']
    video_url = episode['video_url']

    output_path = build_output_path(id, video_url)

    command = build_command(output_path, video_url)

    lines << command
  end

  lines.join("\n") + "\n"
end

def build_output_path(id, video_url)
  basename = video_url[/[^\/]+\z/]
  '%03d-railscasts-%s' % [id, basename]
end

def build_command(output_path, video_url)
  "# wget -c -O #{output_path} #{video_url}"
end

task :default => :build

task :build => :scrape do |t|
  episodes = JSON.parse(File.read('episodes.json'))

  content = build_download_script(episodes)

  open('download.sh', 'w', 0755) {|io| io << content }
end

task :scrape do
  Scraper.new('episodes.json').run
end
