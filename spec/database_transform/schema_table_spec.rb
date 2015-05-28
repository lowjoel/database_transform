require 'spec_helper'

RSpec.describe DatabaseTransform::SchemaTable do
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

  describe '#save' do
    it 'declares a conditional save for the given column' do
      subject.save if: proc { c.dirty? }
      expect(subject.instance_variable_get(:@save)).to be_truthy
    end

    context 'when #save is called twice' do
      it 'raises an error' do
        subject.save if: proc { c.dirty? }
        expect { subject.save if: proc { c.dirty? } }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#migrate!' do
    context 'when a default scope is specified' do
      let(:default_scope) { proc { where('id % 2 = 0') } }
      before do
        subject.column :id, to: :id
        Source.transaction do
          (0..10).each do |i|
            Source.create(val: i, content: format('%d counts!', i))
          end
        end
      end

      it 'all records match the default scope' do
        destination_model.delete_all
        subject.send(:migrate!)
        destination_model.all.each do |row|
          expect(row.id % 2).to eq(0)
        end
      end
    end
  end
end
