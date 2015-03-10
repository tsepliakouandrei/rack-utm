module Rack
  #
  # Rack Middleware for extracting information from the request params and cookies.
  # It populates +env['affiliate.tag']+, # +env['affiliate.from']+ and
  # +env['affiliate.time'] if it detects a request came from an affiliated link 
  #
  class Utm

    COOKIE_SOURCE   = "utm_source"
    COOKIE_SOURCE14 = "first_source14"
    COOKIE_SOURCE30 = "first_source30"
    COOKIE_MEDIUM   = "utm_medium"
    COOKIE_TERM     = "utm_term"
    COOKIE_CONTENT  = "utm_content"
    COOKIE_CAMPAIGN = "utm_campaign"
    
    COOKIE_FROM     = "utm_from"
    COOKIE_TIME     = "utm_time"
    COOKIE_LP       = "utm_lp"
    
    def initialize(app, opts = {})
      @app = app
      @key_param = "utm_source"
      @cookie_ttl = opts[:ttl] || 60*60*24*30  # 30 days
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
      expires = Time.now + @cookie_ttl
      { COOKIE_SOURCE => source,
        COOKIE_MEDIUM => medium,
        COOKIE_TERM => term,
        COOKIE_CONTENT => content,
        COOKIE_CAMPAIGN => campaign,
        COOKIE_FROM => from,
        COOKIE_TIME => time,
        COOKIE_LP => lp
      }.each do |key, value|
          set_cookie_header(headers, key, value, expires)
      end 

      if medium == 'cpc'
        set_cookie_header(headers, COOKIE_SOURCE14, source, Time.now + 60*60*24*14)
      end

      if medium == 'cpm'
        set_cookie_header(headers, COOKIE_SOURCE30, source, Time.now + 60*60*24*30)
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
