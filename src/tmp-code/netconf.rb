#!/usr/local/bin/ruby
#coding:utf-8

# frozen_string_literal: true

## -----------------------------------------------------------------------
## This file contains the Netconf::Transport parent class definition.
## All other transports, i.e. "ssh", "serial", "telnet" use this parent
## class to define their transport specific methods:
##
##    trans_open: open the transport connection
##    trans_close: close the transport connection
##    trans_send: send XML command (String) via transport
##    trans_receive: receive XML response (String) via transport
##
## -----------------------------------------------------------------------

module Netconf
  class Transport
    attr_reader :rpc, :state, :session_id, :capabilities
    attr_writer :timeout, :waitio

    def initialize(&block)
      @state = :NETCONF_CLOSED
      @os_type = @args[:os_type] || Netconf::DEFAULT_OS_TYPE

      @rpc = Netconf::RPC::Executor.new(self, @os_type)
      @rpc_message_id = 1

      if block_given?
        open(&block = nil) # do not pass this block to open()
        yield self
        close
      end
    end # initialize

    def open?
      @state == :NETCONF_OPEN
    end

    def closed?
      @state == :NETCONF_CLOSED
    end

    def open(&block) # :yield: specialized transport open, generally not used
      raise Netconf::StateError if @state == :NETCONF_OPEN
      # block is used to deal with special open processing ...
      # this is *NOT* the block passed to initialize()
      raise Netconf::OpenError unless trans_open(&block)
      # read the <hello> from the server and parse out
      # the capabilities and session-id
      hello_rsp = Nokogiri::XML(trans_receive_hello)
      hello_rsp.remove_namespaces!

      @capabilities = hello_rsp.xpath('//capability').map(&:text)
      @session_id = hello_rsp.xpath('//session-id').text

      # send the <hello>
      trans_send_hello

      @state = :NETCONF_OPEN
      self
    end

    def trans_receive_hello
      trans_receive
    end

    def trans_send_hello
      trans_send( Netconf::RPC::MSG_HELLO )
      trans_send( RPC::MSG_END )
    end

    def has_capability?(capability)
      @capabilities.select { |c| c.include? capability }.pop
      # note: the caller could also simply use #grep on @capabilities
    end

    def close
      raise Netconf::StateError unless @state == :NETCONF_OPEN
      trans_close
      @state = :NETCONF_CLOSED
      self
    end

    # string in; string out
    def send_and_receive(cmd_str)
      trans_send(cmd_str)
      trans_send(RPC::MSG_END)
      trans_receive
    end

    def rpc_exec(cmd_nx)
      raise Netconf::StateError unless @state == :NETCONF_OPEN

      # add the mandatory message-id and namespace to the RPC

      rpc_nx = cmd_nx.parent.root
      rpc_nx.default_namespace = Netconf::NAMESPACE
      rpc_nx['message-id'] = @rpc_message_id.to_s
      @rpc_message_id += 1

      # send the XML command through the transport and
      # receive the response; then covert it to a Nokogiri XML
      # object so we can process it.

      rsp_nx = Nokogiri::XML(send_and_receive(cmd_nx.to_xml))

      # the following removes only the default namespace (xmlns)
      # definitions from the document.  This is an alternative
      # to using #remove_namespaces! which would remove everything
      # including vendor specific namespaces.  So this approach is a
      # nice "compromise" ... just don't know what it does
      # performance-wise on large datasets.

      rsp_nx.traverse { |n| n.namespace = nil }

      # set the response context to the root node; <rpc-reply>

      rsp_nx = rsp_nx.root

      # check for rpc-error elements.  these could be
      # located anywhere in the structured response

      rpc_errs = rsp_nx.xpath('//self::rpc-error')
      if rpc_errs.count.positive?

        # look for rpc-errors that have a severity == 'error'
        # in some cases the rpc-error is generated with
        # severity == 'warning'

        sev_err = rpc_errs.xpath('error-severity[. = "error"]')

        # if there are rpc-error with severity == 'error'
        # or if the caller wants to raise if severity == 'warning'
        # then generate the exception

        if sev_err.count.positive? || Netconf::raise_on_warning
          exception = Netconf::RPC.get_exception(cmd_nx)
          raise exception.new(self, cmd_nx, rsp_nx)
        end
      end

      # return the XML with context at toplevel element; i.e.
      # after the <rpc-reply> element
      # @@@/JLS: might this be <ok> ? isn't for Junos, but need to check
      # @@@/JLS: the generic case.

      rsp_nx.element_children
    end
  end # class: Transport
end # module: Netconf




module Netconf
  class SSH < Netconf::Transport
    NETCONF_PORT = 830
    NETCONF_SUBSYSTEM = 'netconf'

    def initialize(args_h, &block)
      @args = args_h.clone
      @args[:os_type] = args_h[:os_type] || Netconf::DEFAULT_OS_TYPE

      # extend this instance with the capabilities of the specific os_type
      begin
        extend Netconf.const_get(@args[:os_type]).TransSSH
      rescue NameError
        # no extensions available ...
      end

      @trans = {}
      super(&block)
    end

    def trans_open(&block)
      # open a connection to the NETCONF subsystem
      start_args = {}
      start_args[:password] ||= @args[:password]
      start_args[:passphrase] = @args[:passphrase] || nil
      start_args[:port] = @args[:port] || NETCONF_PORT
      start_args.merge!(@args[:ssh_args]) if @args[:ssh_args]

      begin
        @trans[:conn] = Net::SSH.start(@args[:target], @args[:username], start_args)
        @trans[:chan] = @trans[:conn].open_channel do |ch|
          ch.subsystem(NETCONF_SUBSYSTEM)
        end
      rescue Errno::ECONNREFUSED => e
        if self.respond_to? 'trans_on_connect_refused'
          return trans_on_connect_refused(start_args)
        end
        return nil
      end
      @trans[:chan]
    end

    def trans_close
      @trans[:chan].close if @trans[:chan]
      @trans[:conn].close if @trans[:conn]
    end

    def trans_receive
      @trans[:rx_buf] = ''
      @trans[:more] = true

      # collect the response data as it comes back ...
      # the "on" functions must be set before calling
      # the #loop method

      @trans[:chan].on_data do |_ch, data|
        if data.include?(RPC::MSG_END)
          data.slice!(RPC::MSG_END)
          @trans[:rx_buf] << data unless data.empty?
          @trans[:more] = false
        else
          @trans[:rx_buf] << data
        end
      end

      # ... if there are errors ...
      @trans[:chan].on_extended_data do |_ch, _type, data|
        @trans[:rx_err] = data
        @trans[:more] = false
      end

      # the #loop method is what actually performs
      # ssh event processing ...

      @trans[:conn].loop { @trans[:more] }

      @trans[:rx_buf]
    end

    def trans_send(cmd_str)
      @trans[:chan].send_data(cmd_str)
    end

    # accessor to create an Net::SCP object so the caller can perform
    # secure-copy operations (see Net::SCP) for details
    def scp
      @scp ||= Net::SCP.start(@args[:target],
                              @args[:username],
                              password: @args[:password],
                              port: @args[:port] || 22)
    end
  end # class: SSH
end # module: Netconf

require 'net/netconf'

login = {
  target: '121.59.168.95',
  port: 22,
  username: 'cn2sdn',
  password: 'St5s%g6u'
}

Netconf::SSH.new(login) do |dev|
  config = dev.rpc.get_config

  puts 'Showing users on this device ...'
  config.xpath('//users/user').each do |user|
    puts "Username: #{user.xpath('name').text}"
  end
end