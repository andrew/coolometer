Mongoid.configure do |config|
  if ENV['MONGOHQ_URL']
    conn = Mongo::Connection.from_uri(ENV['MONGOHQ_URL'])
    uri = URI.parse(ENV['MONGOHQ_URL'])
    config.master = conn.db(uri.path.gsub(/^\//, ''))
  else
    config.master = Mongo::Connection.from_uri("mongodb://localhost:27017").db('coolometer')
  end
end

class TwitterUser
  include Mongoid::Document

  field :updated_at, :type => DateTime
  field :followers_count, :type => Integer
  field :friends_count, :type => Integer
  field :created_at, :type => DateTime
  field :screen_name
  field :profile_image_url
  field :megafonzies, :type => Float
end

class Coolometer < Sinatra::Base
  set :root, File.dirname(__FILE__)

  get '/' do
    haml :index
  end

  post '/' do
    redirect to("/#{params[:username]}")
  end

  get '/leaderboard' do
    @twitter_users = TwitterUser.desc(:megafonzies).limit(100)
    haml :leaderboard
  end

  get '/:username' do
    calculate_coolness_for(params[:username])

    haml :user
  end

  def calculate_coolness_for(username)
    if @user = TwitterUser.first(:conditions => {:screen_name => username})
      @megafonzies = @user.megafonzies.to_f
    else
      @user = Twitter.user(username)
      timeline = Twitter.user_timeline(username)
      trends = Twitter.trends_weekly
      @megafonzies = 0

      # amount of time mentions recent trends
      squished_timeline = timeline.map(&:text).join(' ')
      buzzwords = trends.map{|day| day[1].map(&:name) }.flatten.uniq
      buzzwords.each do |buzzword|
        @megafonzies +=1 if squished_timeline.match(Regexp.new(buzzword,true))
      end

      # amount of retweets
      timeline.each {|tweet| @megafonzies += tweet.retweet_count.to_i}

      # followers
      @megafonzies += @user.followers_count.to_f/@user.friends_count

      # listed
      @megafonzies += @user.listed_count.to_f/100

      # how long you've been on twitter
      @megafonzies += (Time.now - Time.parse(@user.created_at)).to_f/10000000
      TwitterUser.create( :updated_at => Time.now,
                          :followers_count => @user.followers_count,
                          :friends_count => @user.friends_count,
                          :created_at => @user.created_at,
                          :screen_name => @user.screen_name,
                          :profile_image_url => @user.profile_image_url,
                          :megafonzies => @megafonzies)
    end
  end
end