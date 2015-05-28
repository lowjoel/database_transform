RSpec.configure do
  dummy_connection = {
    'adapter' => 'sqlite3',
    'database' => File.join(__dir__, '..', 'test_database.sqlite3')
  }

  ActiveRecord::Base.configurations['default'] = dummy_connection
  ActiveRecord::Base.configurations['dummy_schema_production'] = dummy_connection
  ActiveRecord::Base.configurations['dummy_schema4'] = dummy_connection
  ActiveRecord::Base.configurations['dummy_cyclic_dependency_schema'] = dummy_connection

  ActiveRecord::Base.establish_connection(:default)
  ActiveRecord::Base.connection.execute <<SQL
  --Create the dummy database
  CREATE TABLE IF NOT EXISTS sources (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    val NUMERIC,
    content TEXT
  );

  CREATE TABLE IF NOT EXISTS destinations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    val NUMERIC,
    content TEXT
  );
SQL
end
