class Coolometer < Sinatra::Base
  set :root, File.dirname(__FILE__)

  get '/' do
    haml :index
  end

  post '/' do
    redirect to("/#{params[:username]}")
  end

  get '/:username' do
    calculate_coolness_for(params[:username])

    haml :user
  end

  def calculate_coolness_for(username)
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
  end
end
