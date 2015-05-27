require 'spec_helper'

RSpec.describe DatabaseTransform::SchemaTable do
  class DummyTableSchema < DatabaseTransform::Schema; end
  subject { DatabaseTransform::SchemaTable.new(source_model, destination_model, default_scope) }
  let(:source_model) { Source }
  let(:destination_model) { Destination }
  let(:default_scope) { nil }

  describe '#primary_key' do
    it 'sets the primary key for the source table' do
      subject.primary_key :id
      expect(subject.instance_variable_get(:@primary_key)).to eq(:id)
    end
  end

  describe '#column' do
    it 'declares the mapping for the given column' do
      subject.column :name
      expect(subject.instance_variable_get(:@columns).find { |c| c[:from] == [:name] }).to be_truthy
    end
  end
end
