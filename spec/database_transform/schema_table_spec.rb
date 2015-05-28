require 'spec_helper'

RSpec.describe DatabaseTransform::SchemaTable do
  subject { DatabaseTransform::SchemaTable.new(source_model, destination_model, default_scope) }
  let(:source_model) { Source }
  let(:destination_model) { Destination }
  let(:default_scope) { nil }
  let(:dummy_records) do
    Source.transaction do
      (0..3).each do |i|
        Source.create(val: i, content: format('%d counts!', i.to_f))
      end
    end
  end

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
    before { dummy_records }

    context 'when a default scope is specified' do
      let(:default_scope) { proc { where('id % 2 = 0') } }
      before do
        subject.column :id, to: :id
      end

      it 'all records match the default scope' do
        destination_model.delete_all
        subject.run_migration
        expect(destination_model.count).not_to be(0)
        destination_model.all.each do |row|
          expect(row.id % 2).to eq(0)
        end
      end
    end

    context 'when a mapping transform is specified' do
      context 'when multiple source columns are specified' do
        before do
          subject.column :val
          subject.column :val, :content, to: :content do |val, content|
            format('%d%s', val, content)
          end
        end

        it 'provides all columns to the block' do
          destination_model.delete_all
          subject.run_migration
          expect(destination_model.count).not_to be(0)
          destination_model.all.each do |row|
            expect(row.content).to eq(format('%d%d counts!', row.val, row.val))
          end
        end
      end

      context 'when a destination column is specified' do
        before do
          subject.column :id, to: :id do |id|
            id * 2 + 1
          end
        end

        it 'sets the corresponding column with the result of the transform' do
          destination_model.delete_all
          subject.run_migration
          expect(destination_model.count).not_to be(0)
          destination_model.all.each do |row|
            expect(row.id % 2).to eq(1)
          end
        end
      end

      context 'when a destination column is not specified' do
        before do
          subject.column :val do
            0
          end
        end

        it 'does not modify the record' do
          destination_model.delete_all
          subject.run_migration
          expect(destination_model.count).not_to be(0)
          destination_model.all.each do |row|
            expect(row.val).to be_nil
          end
        end
      end
    end

    context 'when a mapping transform is not specified' do
      context 'when a destination column is specified' do
        before do
          subject.column :val, to: :val
          subject.column :val, to: :content
        end

        it 'sets the corresponding column' do
          destination_model.delete_all
          subject.run_migration
          expect(destination_model.count).not_to be(0)
          destination_model.all.each do |row|
            expect(row.val.to_s).to eq(row.content)
          end
        end

        context 'when multiple source columns are specified' do
          it 'fails' do
            expect { subject.column :val, :content, to: :content }.to raise_error(ArgumentError)
          end
        end
      end

      context 'when a destination column is not specified' do
        before do
          subject.column :content
        end
        it 'sets the corresponding column with the same name in the destination' do
          destination_model.delete_all
          subject.run_migration
          expect(destination_model.count).not_to be(0)
          destination_model.all.each do |row|
            expect(row.content).not_to be_nil
          end
        end
      end
    end
  end
end
