# Database Transform

This gem will allow you to transform a database's contents across schemas with a simple DSL. This is useful when
migrating from an application written in another framework to Rails, allowing programmers to reason about how an old
schema maps to a new one.

Similar gems exist:

 - [legacy_migrations](https://github.com/btelles/legacy_migrations)
 - [super_migration](https://github.com/christian/super_migration)

However, they have not been updated for a few years.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'database_transform'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install database_transform

## Usage

Database Transform is built with ActiveRecord in mind. First, define a new database conndtion to the old database in
database.yml:

```yaml
my_old_app_production:
  adapter: postgresql
  host: old_server
  database: my_old_app
```

Then, define the define a transform in `db/transforms/my_old_app_schema.rb`:

```ruby
class MyOldAppSchema < DatabaseTransform::Schema
  migrate_table :users, to: ::User, scope: proc { where('uid <> 0') } do
    primary_key :uid
    column :mail, to: :email
    column :pass, to: :password do |password|
      self.password_confirmation = password
    end
  end
end
```

A summary of methods:

 - `migrate_table` tells Database Transform to perform the given transform over records in the given source table.
   - The first argument is the table to migrate. This can be a symbol, string, or an ActiveRecord model.
   - `to` specifies the new table to migrate to. This can be a symbol, string, or an ActiveRecord model.
     - If either argument is a symbol or string, an ActiveRecord model is generated which allows access to the record's
       data.
   - `default_scope` allows the programmer to specify the records to transform
 - `primary_key` declares the name of column with the primary key
 - `column` declares how to transform the contents of that column from the old database to the new one.
   - If `to:` is omitted, then it is assumed that the transfer function is the identity function, and the column would
     map across as the same name.
   - A block can be provided.
     - If so, then the data from the old record is passed to the block as the first argument
     - In the context of the block, `self` refers to the new record.
     - `self` has an additional attribute `from_record` which refers to the old record.

Finally, execute the Rake task:

    $ rake db:transform my_old_app

And the schema (`MyOldAppSchema`) and database connection (via `my_old_app_production`) will be established for you. A
few variants of the schema name will be checked:

 - my_old_app
 - my_old_app_production

## Contributing

1. Fork it ( https://github.com/[my-github-username]/database_transform/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
