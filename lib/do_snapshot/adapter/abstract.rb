# -*- encoding : utf-8 -*-

module DoSnapshot
  module Adapter
    # API for CLI commands
    # Operating with Digital Ocean.
    #
    class Abstract
      include DoSnapshot::Helpers

      attr_accessor :delay, :timeout

      def initialize(options = {})
        check_keys
        set_id
        options.each_pair do |key, option|
          send("#{key}=", option)
        end
      end

      protected

      def set_id; end

      def check_keys; end

      # Waiting for event exit
      def wait_wrap(id, message = "Event Id: #{id}", &status_block)
        logger.debug message
        time = Time.now
        sleep(delay) until status_block.call(id, time)
      end

      # Waiting for event exit
      def wait_event(event_id)
        wait_wrap(event_id) { |id, time| get_event_status(id, time) }
      end

      # Waiting for event exit
      def wait_shutdown(droplet_id)
        wait_wrap(droplet_id, "Droplet Id: #{droplet_id} shutting down") { |id, time| get_shutdown_status(id, time) }
      end

      def after_cleanup(droplet_id, droplet_name, snapshot, event)
        if !event
          logger.error "Destroy of snapshot #{snapshot.name} for droplet id: #{droplet_id} name: #{droplet_name} is failed."
        elsif event && !event.status.include?('OK')
          logger.error event.message
        else
          logger.debug "Snapshot name: #{snapshot.name} delete requested."
        end
      end

      def timeout?(id, time, message = "Event #{id} finished by timeout #{time}")
        return false unless (Time.now - time) > @timeout
        logger.debug message
        true
      end

      def droplet_timeout?(id, time)
        timeout? id, time, "Droplet id: #{id} shutdown event closed by timeout #{time}"
      end

      # Looking for event status.
      # Before snapshot we to know that machine has powered off.
      #
      def get_shutdown_status(id, time)
        fail "Droplet #{id} not responding for shutdown!" if droplet_timeout?(id, time)

        inactive?(id)
      end
    end
  end
end
