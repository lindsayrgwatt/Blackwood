
namespace "redis" do

  desc "Subscriber process that listens for cache invalidations"
  task :subscriber => :environment do
    REDIS_CONFIG = YAML.load(File.open(Rails.root.join("config/subscribe_redis.yml")))[Rails.env]

    redis_connect = Redis.new(REDIS_CONFIG.symbolize_keys!.merge(:timeout => 0) )
    Rails.logger.error "Subscribing to Invalidations in RAILS_ENV:#{Rails.env}"
    redis_connect.subscribe("#{REDIS_CONFIG[:namespace]}:invalidations") do |on|
      on.message do |channel, msg|
        data = JSON.parse(msg)
        Rails.logger.error "#invalidating key - [#{data['model']}/#{data['id']}]"

        $redis.del( "#{data['model']}/#{data['id']}".downcase )
      end
    end
  end
end