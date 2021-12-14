# frozen_string_literal: true

# Heroku Connect is a Heroku add-on that lets you choose Salesforce objects and
# sync selected fields from them into a separate database schema in your application's
# database: https://devcenter.heroku.com/categories/heroku-connect
#
# This is a base class to use when creating models to read from those tables with Salesforce
# data. To create a new model for an existing table, just subclass this and set the table_name
# as well as any relationships to other related tables you want. See HerokuConnect::Participant
# for an example.
#
# Usage:
#
# class HerokuConnect::MyModel
#   self.table_name = 'my_table'
#
#  # type cast these from strings to symbols to make the code cleaner
#  attribute :column1, :symbol
#
#   belongs_to :other_table, foreign_key: 'some_column1'
#   has_many :other_table2, foreign_key: 'some_column2'
#
#   def default_columns()
#     [:column1, :column2]
#   end
# end
#
# ========================
# To add a new Salesforce object and a new table in the "salesforce" schema where they live,
# go to the Mappings tab in the add-on and choose "+Create Mapping" for the object. You'll almost
# certainly want to check the box that says "Accelerate Polling" so that the data is available in
# near real-time. Choose the fields you need access to. Don't just select them all. Only choose the
# ones you need b/c it's a lot of data and would take a lot of resources for us to sync and query
# everything. Then sub-class this and setup the `table_name` along with the associations and
# `default_columns`.
#
# To add a new Salesforce field to an existing table and model, simply open the add-on in Heroku, go to
# the Mappings tab, select the object you want (aka Participant__c), and select the new field
# to map. If you need to use it in WHERE clauses or it's used as a foreign key consider checking
# the box to make it indexed. Then come add the column to the `default_columns` list.
#
# Pro-tip: to see the column name, grab the `HEROKU_CONNECT_DATABASE_URL` value and enter:
# `psql the_value` in the terminal. Then type `\d+ salesforce.table_name`. If you don't know the
# table name, type `\dt+ salesforce.*` to list all the Heroku Connect tables.
#
# Notes:
# - This is intended for read-only access only. If we enabled write access (and configured
#   Heroku Connect to sync those writes back to Salesforce), we wouldn't know if they failed
#   and it doesn't happen in real-time (it's every 2 minutes at time of writing). Plus we'd
#   have to deal with data integrity with Salesforce writing stuff and then these writes conflicting.
#   Instead, use the SalesforceAPI to write to Salesforce.
# - In production, configure the heroku_connect database connection in database.yml to point
#   at the production database, but create a read-only user for the connection.
# - In development, we've setup Heroku Conenct on our staging Heroku application (braven-platform-staging)
#   to point at the shared Salesforce Sandbox we use for development. Configure the heroku_connect
#   database connection to use the read-only postgres credentials for that application.
# - When adding / editing the Heroku Connect mappings for fields we want to use in this application,
#   make sure and add them in both the prod and staging Heroku apps. Note that in staging, I didn't map
#   all the fields that are mapped in prod and used by Periscope, our data visualization tool. It's too
#   much to maintain keeping in sync. We just care about which ones we use in this platform application.
#   See the default_scope() stuff for more context on this. The specs will detect a mismatch and prevent
#   prod deploys.
#
# More info here on the Wiki: https://github.com/bebraven/platform/wiki/Salesforce
class HerokuConnect::HerokuConnectRecord < ActiveRecord::Base
  self.abstract_class = true # this is not a real table

  # This is what lets the normal ActiveRecord relationships, like has_many and belongs_to
  # work. See here for more info:
  # https://devcenter.heroku.com/articles/heroku-connect-database-tables#system-columns
  def self.primary_key
    'sfid';
  end

  # By default, ActiveRecord select all columns. Change that to only select the ones
  # we care about for this model considering there can be like 100 columns when we care about 3.
  # We could easily blow up the memory usage if we load it all.
  default_scope {
    if self.has_attribute?(:isdeleted)
      select(default_columns).where(isdeleted: false)
    else
      select(default_columns)
    end
  }

  # If you want to get all columns in the Heroku Connect table, use this. E.g.:
  # HerokuConnect::Contact.where(foo: blah).all_columns
  # Careful though.
  scope :all_columns, -> { unscope(:select) }

  # See database.yml for this config.
  # See here for more info on how this per model connection stuff works:
  # https://github.com/rails/rails/blob/59eb7edb687c8b9cffc74288921b77da01971fb2/activerecord/lib/active_record/base.rb#L232
  establish_connection :heroku_connect

private

  # Every subclass is expected to define a default_columns() method that returns
  # the array of columns we care about in this application.
  # If we want them all, use: `def default_columns; '*'; end`
  #
  # We maintain the list per model b/c ActiveRecord selects all columns by default
  # which is normally fine b/c we have control over designing our tables not to have
  # a 100 columns. However, for these Heroku Connect backed tables we are not the
  # only consumer. Anything Periscope (our data visualization tool) needs is added
  # as a column which quickly gets out of hand. For example, at the time of writing
  # there are 95 columns in the HerokuConnect::Contact table and we only care about a handful.
  def self.default_columns
    raise NoMethodError, 'HerokuConnect::HerokuConnectRecord expects method `default_columns` to be overridden with the columns we care about'
  end

end
