require 'date'
require 'json'
require 'logger'
require 'pathname'
require 'uri'

require 'mechanize'

class Scraper
  BASE_URI = URI.parse('http://railscasts.com/').freeze

  def initialize(output_path, logger: Logger.new($stderr))
    @output_path = Pathname.new(output_path)
    @logger = logger
    @mech = Mechanize.new
  end

  def run
    scrape_each_page_url
    scrape_each_video_url
    scrape_each_video_length
  end

  private

  def scrape_each_page_url
    return if @output_path.exist?

    episodes = []

    next_url = BASE_URI.dup

    while next_url
      wait

      debug "GET: #{next_url}"

      page = @mech.get(next_url)

      next_link = page.at('a.next_page')

      next_url = next_link && (BASE_URI + next_link[:href])

      page.search('.episode').each do |node|
        page_url = BASE_URI + node.at('.main h2 a')[:href]

        posted_on = Date.parse(node.at('.published_at').text)

        episodes << {
          'page_url' => page_url,
          'posted_on' => posted_on.to_s
        }
      end
    end

    episodes = episodes.reverse.map.with_index(1) do |episode, index|
      episode['id'] = index
      episode
    end

    dump_episodes(episodes)
  end

  def scrape_each_video_url
    episodes = load_episodes

    episodes.each do |episode|
      next if episode['video_url']

      page_url = episode['page_url']

      wait

      debug "GET: #{page_url}"

      page = @mech.get(page_url)

      episode['title'] = page.at('title').text.gsub(/\s+/, ' ').strip.sub(/ - RailsCasts\z/, '')

      episode['video_url'] = page.at('.//li/a[text()="mp4"]')[:href]

      dump_episodes(episodes)
    end
  end

  def scrape_each_video_length
    episodes = load_episodes

    episodes.each do |episode|
      next if episode['video_length']

      video_url = episode['video_url']

      wait

      debug "GET: #{video_url}"

      episode['video_length'] = get_video_length(video_url)

      dump_episodes(episodes)
    end
  end

  def get_video_length(video_url)
    info = IO.popen(['ffmpeg', '-i', video_url, :err => [:child, :out]], &:read)

    if /Duration: (\d+):(\d+):(\d+\.\d+)/ =~ info
      hours = $1.to_i
      minutes = $2.to_i
      seconds = $3.to_f.ceil
      return (hours * 60 * 60) + (minutes * 60) + seconds
    else
      debug info
      raise 'invalid info'
    end
  end

  def load_episodes
    JSON.parse(@output_path.read)
  end

  def dump_episodes(episodes)
    @output_path.write(JSON.pretty_generate(episodes))
  end

  def wait(sec = 1)
    sleep sec
  end

  def debug(message)
    @logger&.debug(message)
  end
end
