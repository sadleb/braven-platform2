require 'active_record/connection_adapters/postgresql_adapter'
require 'filter_logging'

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter 

private

  # Overrides the "info" sent in an ActiveRecord::Notification for cached values.
  def cache_notification_info(sql, name, binds)
    filtered_type_casted_binds = FilterLogging.filter_sql(name, binds, -> { type_casted_binds(binds) })
    return super unless filtered_type_casted_binds
    return {
      sql: sql,
      binds: binds,
      type_casted_binds: filtered_type_casted_binds,
      name: name,
      connection: self,
      cached: true
    }
  end

  # Overrides the log method which is responsibe for sending an ActiveRecord::Notification
  # event for 'sql.active_record' so that we can filter what is sent in the event. By doing it
  # here, not only the Logger gets filtered, but also things like Sentry and Honeycomb which
  # subscribe to the Notification events to build their payloads as well.
  def log(sql, name = "SQL", binds = [], type_casted_binds = [], statement_name = nil, async: false)
    filtered_type_casted_binds = FilterLogging.filter_sql(name, binds, -> { type_casted_binds })
    if filtered_type_casted_binds
      super(sql, name, binds, filtered_type_casted_binds, statement_name)
    else
      super(sql, name, binds, type_casted_binds, statement_name)
    end
  end
end
