class DatabaseTransform::Railtie < Rails::Railtie
  rake_tasks do
    load 'database_transform/tasks/transform.rake'
  end
end
