require 'addons-api/version'
require 'rest-client'
require 'oj'
require 'open-uri'

module AddonsApi
  class Client

    # Get a Client configured to use Token authentication.
    def self.connect(options=nil)
      options = sanitize_options(options)
      Wrapper.new(options)
    end

    # Get a Client configured to use Token authentication.
    def self.connect_with_token(token, options=nil)
      options = sanitize_options(options)
      options[:token] = token
      Wrapper.new(options)
    end

    def self.sanitize_options(options)
      return {} if options.nil?

      final_options = {}
      final_options[:auto_paginate] = options[:auto_paginate] if options[:auto_paginate]
      final_options[:headers] = options[:headers] if options[:headers]
      final_options[:timeout] = options[:timeout] if options[:timeout]
      final_options[:token] = options[:token] if options[:token]
      final_options[:base_url] = options[:base_url] if options[:base_url]
      final_options
    end

    #
    # Addons.io API wrapper
    #
    class Wrapper
      BASE_URL = %(https://api.addons.io/).freeze
      API_VERSION = %(2022-12-01).freeze

      HEADERS = {
        'X-Addons-Api-Version' => API_VERSION,
        'Accept'          => 'application/json',
        'Content-Type'    => 'application/json',
        'User-Agent'      => "addons-api/#{AddonsApi::VERSION}"
      }.freeze

      OPTIONS = {
        :auto_paginate  => true,
        :headers => {},
        :logger  => Logger.new(STDERR),
        :timeout => 10 # seconds
      }.freeze

      def initialize(options={})
        @options = OPTIONS.merge(options)

        @token = @options.delete(:token)
        @base_url = @options.delete(:base_url) || BASE_URL

        @options[:headers] = HEADERS
        if @token
          @options[:headers] = @options[:headers].merge({
            'Authorization' => "Bearer #{@token}",
          }).merge(@options[:headers])
        end
      end

      def request(method, path, body: {}, query: {}, base_url: nil)

        base_url = base_url || @base_url
        url = "#{base_url.chomp('/')}/#{path}"
        query_string = URI.encode_www_form(query)

        unless query_string.empty?
          if url.include?('?')
            url = url + '&' + query_string
          else
            url = url + '?' + query_string
          end
        end

        # TODO: How do we paginate these requests??
        result = RestClient::Request.execute(
          method:   method, 
          url:      url,
          params:   query,
          payload:  Oj.dump(body, mode: :compat),
          headers:  @options[:headers],
          timeout:  @options[:timeout],
          log:      @options[:logger]
        )
        Oj.load(result.body, symbol_keys: true)
      rescue RestClient::BadRequest => e
        raise
      end

      # OAuth resource
      def oauth
        @oauth_resource ||= OAuth.new(self)
      end

      # AddonService resource
      def addon_service
        @addon_service_resource ||= AddonService.new(self)
      end

      # Team resource
      def team
        @team_resource ||= Team.new(self)
      end
    end

    # Addon services represent addons that may be provisioned for apps.
    class OAuth
      BASE_PATH = "oauth" 

      def initialize(client)
        @client = client
      end

      def token
        @token_resource ||= Token.new(@client)
      end

      # Token
      class Token
        def initialize(client)
          @client = client
        end

        def create(client, code)
          path =  "#{BASE_PATH}/token"
          token = @client.request(:post, path, body: { 
            code: code,
            grant_type: "authorization_code",
            client_id: client[:id],
            client_secret: client[:secret],
          })
          token
        end

        def refresh(client, refresh_token)
          path =  "#{BASE_PATH}/token"
          token = @client.request(:post, path, body: { 
            refresh_token: refresh_token,
            grant_type: "refresh_token",
            client_id: client[:id],
            client_secret: client[:secret],
          })
          token
        end
      end
    end

    class AddonService
      BASE_PATH = "addon-services"

      def initialize(client)
        @client = client
      end

      def list()
       @client.request(:get, "#{BASE_PATH}")
      end

      def info(addon_service_id)
        @client.request(:get, "#{BASE_PATH}/#{addon_service_id}")
      end

      def plan
        @plan_resource ||= AddonServicePlan.new(@client)
      end

      def field
        @field_resource ||= AddonServiceField.new(@client)
      end

      class AddonServicePlan
        def initialize(client)
          @client = client
        end

        def list(addon_service_id)
          @client.request(:get, "#{BASE_PATH}/#{addon_service_id}/plans")
        end

        def info(addon_service_id, addon_service_plan_id)
          @client.request(:get, "#{BASE_PATH}/#{addon_service_id}/plans/#{addon_service_plan_id}")
        end
      end

      class AddonServiceField
        def initialize(client)
          @client = client
        end

        def list(addon_service_id)
          @client.request(:get, "#{BASE_PATH}/#{addon_service_id}/fields")
        end

        def info(addon_service_id, addon_service_field_id)
          @client.request(:get, "#{BASE_PATH}/#{addon_service_id}/fields/#{addon_service_plan_id}")
        end
      end
    end

    class Team
      BASE_PATH = "teams"

      def initialize(client)
        @client = client
      end

      def list()
       @client.request(:get, "#{BASE_PATH}")
      end

      def info(team_id)
        @client.request(:get, "#{BASE_PATH}/#{team_id}")
      end

      def member
        @member_resource ||= Member.new(@client)
      end

      # Addon resource
      def addon
        @addon_resource ||= Addon.new(@client)
      end

      # A member is a user with access to a team.
      class Member
        def initialize(client)
          @client = client
        end

        # List members of the team
        def list(team_id)
          @client.request(:get, "#{BASE_PATH}/#{team_id}/members")
        end
      end
      
      # Addon
      class Addon
        def initialize(client)
          @client = client
        end

        def action
          @action_resource ||= Action.new(@client)
        end

        def config
          @config_resource ||= Config.new(@client)
        end

        def info(team_id, addon_id)
          @client.request(:get, "#{BASE_PATH}/#{team_id}/addons/#{addon_id}")
        end

        def info_by_callback_url(callback_url)
          @client.request(:get, "", base_url: callback_url)
        end

        def create(team_id, body = {})
          @client.request(:post, "#{BASE_PATH}/#{team_id}/addons", body: body)
        end

        def delete(team_id, addon_id)
          @client.request(:delete, "#{BASE_PATH}/#{team_id}/addons/#{addon_id}")
        end

        def update(team_id, addon_id, body = {})
          @client.request(:patch, "#{BASE_PATH}/#{team_id}/addons/#{addon_id}", body: body)
        end

        # Configuration of an Addon
        class Config
          def initialize(client)
            @client = client
          end

          # Get the configuration of an addon.
          def list(team_id, addon_id)
            @client.request(:get, "#{BASE_PATH}/#{team_id}/addons/#{addon_id}/config")
          end

          # Get the configuration of an addon with callback URL.
          def list_with_callback_url(callback_url)
            @client.request(:get, "config", base_url: callback_url)
          end

          # Update the configuration of an addon.
          def update(team_id, addon_id, body = {})
            @client.request(:patch, "#{BASE_PATH}/#{team_id}/addons/#{addon_id}/config", body: body)
          end

          # Update the configuration of an addon with callback URL.
          def update_with_callback_url(callback_url, body = {})
            @client.request(:patch, "config", base_url: callback_url, body: body)
          end
        end

        # Addon Actions are lifecycle operations for addon provisioning and deprovisioning. 
        # They allow addon providers to (de)provision addons in the background and then report back when (de)provisioning is complete.
        class Action
          def initialize(client)
            @client = client
          end

          # Mark an addon as provisioned.
          def provision(team_id, addon_id)
            @client.request(:post, "#{BASE_PATH}/#{team_id}/addons/#{addon_id}/actions/provision")
          end

          # Mark an addon as provisioned with callback URL.
          def provision_with_callback_url(callback_url)
            @client.request(:post, "actions/provision", base_url: callback_url)
          end

          # Mark an addon as deprovisioned.
          def deprovision(team_id, addon_id)
            @client.request(:post, "#{BASE_PATH}/#{team_id}/addons/#{addon_id}/actions/deprovision")
          end

          # Mark an addon as deprovisioned with callback URL.
          def deprovision_with_callback_url(callback_url)
            @client.request(:post, "actions/deprovision", base_url: callback_url)
          end
        end
      end

    end
  end
end
