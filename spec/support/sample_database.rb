RSpec.configure do
  source_blog_connection = {
      'adapter' => 'sqlite3',
      'database' => File.join(__dir__, '..', 'source_blog_database.sqlite3')
  }
  ActiveRecord::Base.configurations['blog_schema'] = source_blog_connection

  class BlogSchemaModel < ActiveRecord::Base
    establish_connection(:blog_schema)
    connection.execute <<SQL
      PRAGMA journal_mode = MEMORY
SQL

    connection.execute <<SQL
      CREATE TABLE IF NOT EXISTS users (
        uid INTEGER PRIMARY KEY AUTOINCREMENT,
        given_name TEXT,
        mail TEXT
      );
SQL

    connection.execute <<SQL
      CREATE TABLE IF NOT EXISTS posts (
        post_id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid INTEGER,
        content TEXT
      );
SQL

    connection.execute <<SQL
      INSERT INTO users (given_name, mail) VALUES
        ('A', 'a@b.com'),
        ('C', 'c@d.com');
SQL

    connection.execute <<SQL
      INSERT INTO posts (uid, content) VALUES
        ((SELECT uid FROM users ORDER BY random() LIMIT 1), 'AAA'),
        ((SELECT uid FROM users ORDER BY random() LIMIT 1), 'AAA'),
        ((SELECT uid FROM users ORDER BY random() LIMIT 1), 'BBB')
SQL
  end

  class ActiveRecord::Base
    connection.execute <<SQL
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        given_name TEXT,
        email TEXT
      );
SQL

    connection.execute <<SQL
      CREATE TABLE IF NOT EXISTS posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        content TEXT
      );
SQL
  end
end
