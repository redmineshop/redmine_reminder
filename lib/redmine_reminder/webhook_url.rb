# frozen_string_literal: true

require 'ipaddr'
require 'resolv'
require 'uri'

module RedmineReminder
  # Guards outbound Slack / Google Chat webhook URLs against SSRF.
  # Callers should skip delivery when +safe?+ is false.
  module WebhookUrl
    BLOCKED_NETWORKS = [
      IPAddr.new('0.0.0.0/8'),
      IPAddr.new('10.0.0.0/8'),
      IPAddr.new('100.64.0.0/10'),
      IPAddr.new('127.0.0.0/8'),
      IPAddr.new('169.254.0.0/16'),
      IPAddr.new('172.16.0.0/12'),
      IPAddr.new('192.168.0.0/16'),
      IPAddr.new('224.0.0.0/4'),
      IPAddr.new('::1/128'),
      IPAddr.new('fc00::/7'),
      IPAddr.new('fe80::/10'),
      IPAddr.new('ff00::/8')
    ].freeze

    BLOCKED_HOSTS = %w[
      localhost
      localhost.localdomain
      metadata.google.internal
      metadata
    ].freeze

    module_function

    def safe?(url, resolver: method(:resolve_host))
      uri = parse_https_uri(url)
      return false unless uri

      host = normalize_host(uri.host)
      return false if host.empty?
      return false if blocked_hostname?(host)
      return false if ip_literal?(host) && blocked_ip?(host)

      addresses = Array(resolver.call(host))
      return false if addresses.empty?
      return false if addresses.any? { |ip| blocked_ip?(ip) }

      true
    rescue StandardError
      false
    end

    def host_for_log(url)
      uri = URI.parse(url.to_s.strip)
      normalize_host(uri.host)
    rescue URI::InvalidURIError
      '(invalid-url)'
    end

    def parse_https_uri(url)
      return nil if url.nil?

      stripped = url.to_s.strip
      return nil if stripped.empty?

      uri = URI.parse(stripped)
      return nil unless uri.is_a?(URI::HTTPS)
      return nil if uri.host.nil? || uri.host.empty?
      return nil if uri.userinfo

      uri
    rescue URI::InvalidURIError
      nil
    end

    def normalize_host(host)
      host.to_s.strip.downcase.sub(/\A\[(.*)\]\z/, '\1').sub(/\.+\z/, '')
    end

    def blocked_hostname?(host)
      return true if BLOCKED_HOSTS.include?(host)
      return true if host.end_with?('.localhost')
      return true if host.end_with?('.local')
      return true if host.end_with?('.internal')

      false
    end

    def ip_literal?(host)
      IPAddr.new(host)
      true
    rescue IPAddr::Error
      false
    end

    def blocked_ip?(ip)
      addr = IPAddr.new(ip.to_s)
      addr = addr.native if addr.respond_to?(:ipv4_mapped?) && addr.ipv4_mapped?
      BLOCKED_NETWORKS.any? { |network| network.include?(addr) }
    rescue IPAddr::Error
      true
    end

    def resolve_host(host)
      return [host] if ip_literal?(host)

      Resolv::DNS.open do |dns|
        dns.timeouts = 2
        dns.getaddresses(host).map(&:to_s)
      end
    rescue Resolv::ResolvError, Resolv::ResolvTimeout
      []
    end
  end
end
