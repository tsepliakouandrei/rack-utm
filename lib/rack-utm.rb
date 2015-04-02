module Rack
  #
  # Rack Middleware for extracting information from the request params and cookies.
  # It populates +env['affiliate.tag']+, # +env['affiliate.from']+ and
  # +env['affiliate.time'] if it detects a request came from an affiliated link 
  #
  class Utm

    COOKIE_SOURCE   = "utm_source"
    COOKIE_MEDIUM   = "utm_medium"
    COOKIE_TERM     = "utm_term"
    COOKIE_CONTENT  = "utm_content"
    COOKIE_CAMPAIGN = "utm_campaign"
    COOKIE_FROM     = "utm_from"
    COOKIE_TIME     = "utm_time"
    COOKIE_LP       = "utm_lp"

    COOKIE_SOURCE_14   = "utm_source_14"
    COOKIE_MEDIUM_14   = "utm_medium_14"
    COOKIE_TERM_14     = "utm_term_14"
    COOKIE_CONTENT_14  = "utm_content_14"
    COOKIE_CAMPAIGN_14 = "utm_campaign_14"
    COOKIE_FROM_14     = "utm_from_14"
    COOKIE_TIME_14     = "utm_time_14"
    COOKIE_LP_14       = "utm_lp_14"
    
    def initialize(app, opts = {})
      @app = app
      @key_param = "utm_source"
      @cookie_ttl_30 = opts[:ttl] || 60*60*24*30  # 30 days
      @cookie_ttl_14 = opts[:ttl] || 60*60*24*14  # 14 days
      @cookie_domain = opts[:domain] || nil
      @allow_overwrite = opts[:overwrite].nil? ? true : opts[:overwrite] 
    end

    def call(env)
      req = Rack::Request.new(env)

      params_tag = req.params[@key_param]
      cookie_tag = req.cookies[COOKIE_SOURCE]

      if cookie_tag
        source, medium, term, content, campaign, from, time, lp = cookie_info(req)
      end

      if params_tag
        if source
          if @allow_overwrite
            source, medium, term, content, campaign, from, time, lp = params_info(req)
          end
        else
          source, medium, term, content, campaign, from, time, lp = params_info(req)
        end
      end

      if source
        env["utm.source"] = source
        env['utm.medium'] = medium
        env['utm.term'] = term
        env['utm.content'] = content
        env['utm.campaign'] = campaign

        env['utm.from'] = from
        env['utm.time'] = time
        env['utm.lp'] = lp
      end

      status, headers, body = @app.call(env)

      bake_cookies(headers, source, medium, term, content, campaign, from, time, lp)

      [status, headers, body]
    end

    def utm_info(req)
      params_info(req) || cookie_info(req) 
    end

    def params_info(req)
      [
          req.params["utm_source"],
          req.params["utm_medium"],
          req.params["utm_term"],
          req.params["utm_content"],
          req.params["utm_campaign"],
          req.env["HTTP_REFERER"],
          Time.now.to_i,
          req.path
      ]
    end

    def cookie_info(req)
      [
        req.cookies[COOKIE_SOURCE],
        req.cookies[COOKIE_MEDIUM],
        req.cookies[COOKIE_TERM],
        req.cookies[COOKIE_CONTENT],
        req.cookies[COOKIE_CAMPAIGN],
        
        req.cookies[COOKIE_FROM],
        req.cookies[COOKIE_TIME],
        req.cookies[COOKIE_LP]
      ]
    end

    protected
    def bake_cookies(headers, source, medium, term, content, campaign, from, time, lp)
      expires_30 = Time.now + @cookie_ttl_30
      {
        COOKIE_SOURCE => source,
        COOKIE_MEDIUM => medium,
        COOKIE_TERM => term,
        COOKIE_CONTENT => content,
        COOKIE_CAMPAIGN => campaign,
        COOKIE_FROM => from,
        COOKIE_TIME => time,
        COOKIE_LP => lp
      }.each do |key, value|
          set_cookie_header(headers, key, value, expires_30)
      end

      if medium.present?
        expires_14 = Time.now + @cookie_ttl_14
        {
          COOKIE_SOURCE_14 => source,
          COOKIE_MEDIUM_14 => medium,
          COOKIE_TERM_14 => term,
          COOKIE_CONTENT_14 => content,
          COOKIE_CAMPAIGN_14 => campaign,
          COOKIE_FROM_14 => from,
          COOKIE_TIME_14 => time,
          COOKIE_LP_14 => lp
        }.each do |key, value|
            set_cookie_header(headers, key, value, expires_14)
        end
      end
    end

    protected
    def set_cookie_header(headers, key, value, expires)
      cookie_hash = {:value => value,
                     :expires => expires,
                     :path => "/"}
      cookie_hash[:domain] = @cookie_domain if @cookie_domain
      Rack::Utils.set_cookie_header!(headers, key, cookie_hash)
    end
  end
end
