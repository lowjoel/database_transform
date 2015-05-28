require 'spec_helper'

RSpec.describe DatabaseTransform do
  it 'has a version number' do
    expect(DatabaseTransform::VERSION).not_to be nil
  end

  class BlogSchema < DatabaseTransform::Schema
    transform_table :users, to: ::User, scope: proc { where('uid <> 0') } do
      primary_key :uid
      column :given_name
      column :mail, to: :email
    end

    transform_table :posts, to: ::Post do
      primary_key :post_id
      column :uid, to: :user, null: false do |uid|
        Source::User.transform(uid)
      end
      column :content
    end
  end

  context 'when a schema is transformed' do
    subject { BlogSchema.new }
    before { subject.transform! }
    it 'transforms all users' do
      BlogSchema::Source::User.all.each do |user|
        expect(BlogSchema::Source::User.transform(user.id).given_name).to eq(user.given_name)
        expect(BlogSchema::Source::User.transform(user.id).email).to eq(user.mail)
      end
    end

    it 'transforms all posts preserving user' do
      BlogSchema::Source::Post.all.each do |post|
        expect(BlogSchema::Source::Post.transform(post.id).content).to eq(post.content)
        expect(BlogSchema::Source::Post.transform(post.id).user_id).to eq(
          BlogSchema::Source::User.transform(post.uid).id)
      end
    end
  end
end
