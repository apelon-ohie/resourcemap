require 'spec_helper'

describe ImportWizard, :type => :model do
  let(:user) { User.make }

  let(:collection) { user.create_collection Collection.make_unsaved }
  let(:user2) { collection.users.make email: 'user2@email.com'}
  let(:membership) { collection.memberships.create! user_id: user2.id }

  let(:layer) { collection.layers.make }

  let(:luhn) { layer.identifier_fields.make code: 'luhn', config: {'format' => 'Luhn'} }
  let(:normal) { layer.identifier_fields.make code: 'normal', config: {'format' => 'Normal'} }

  def aditional_data_file_for(user, collection)
    "#{Rails.root}/tmp/import_wizard/#{user.id}_#{collection.id}_aditional_data.json"
  end

  describe "Luhn field" do

    it "imports into existing field with non-blank values" do
      csv_string = CSV.generate do |csv|
        csv << ['Name', 'Luhn']
        csv << ['Foo', '100000-9']
        csv << ['Bar', '100001-7']
        csv << ['Baz', '100002-5']
      end

      specs = [
        {header: 'Name', use_as: 'name'},
        {header: 'Luhn', use_as: 'existing_field', field_id: luhn.id},
        ]

      ImportWizard.import user, collection, 'foo.csv', csv_string
      ImportWizard.mark_job_as_pending user, collection
      ImportWizard.execute user, collection, specs

      sites = collection.sites
      expect(sites.length).to eq(3)

      expect(sites[0].properties[luhn.es_code]).to eq('100000-9')
      expect(sites[1].properties[luhn.es_code]).to eq('100001-7')
      expect(sites[2].properties[luhn.es_code]).to eq('100002-5')
    end

    it "import into existing field should not generate a new value, because the the luhn value should not be changed unless the user specify a new value" do
      site = collection.sites.make properties: {luhn.es_code => '100000-9'}

      csv_string = CSV.generate do |csv|
        csv << ['resmap-id', 'Name', 'Luhn']
        csv << [site.id, 'Foo', '']
      end

      specs = [
        {header: 'resmap-id', use_as: 'id'},
        {header: 'Name', use_as: 'name'},
        {header: 'Luhn', use_as: 'existing_field', field_id: luhn.id},
        ]

      ImportWizard.import user, collection, 'foo.csv', csv_string
      ImportWizard.mark_job_as_pending user, collection
      ImportWizard.execute user, collection, specs

      sites = collection.sites
      expect(sites.length).to eq(1)
      expect(sites[0].properties[luhn.es_code]).to eq('100000-9')
    end

    it "imports into existing field and with the same value" do
      site = collection.sites.make properties: {luhn.es_code => '100000-9'}

      csv_string = CSV.generate do |csv|
        csv << ['resmap-id', 'Name', 'Luhn']
        csv << [site.id, 'Foo', '100000-9']
      end

      specs = [
        {header: 'resmap-id', use_as: 'id'},
        {header: 'Name', use_as: 'name'},
        {header: 'Luhn', use_as: 'existing_field', field_id: luhn.id},
        ]

      ImportWizard.import user, collection, 'foo.csv', csv_string
      ImportWizard.mark_job_as_pending user, collection
      ImportWizard.execute user, collection, specs

      sites = collection.sites
      expect(sites.length).to eq(1)
      expect(sites[0].properties[luhn.es_code]).to eq('100000-9')
    end

    it "imports into existing field and with the same value(also identifying the site with a string)" do
      site = collection.sites.make properties: {luhn.es_code => '100000-9'}

      csv_string = CSV.generate do |csv|
        csv << ['resmap-id', 'Name', 'Luhn']
        csv << ["#{site.id}", 'Foo', '100000-9']
      end

      specs = [
        {header: 'resmap-id', use_as: 'id'},
        {header: 'Name', use_as: 'name'},
        {header: 'Luhn', use_as: 'existing_field', field_id: luhn.id},
        ]

      ImportWizard.import user, collection, 'foo.csv', csv_string
      ImportWizard.mark_job_as_pending user, collection
      ImportWizard.execute user, collection, specs

      sites = collection.sites
      expect(sites.length).to eq(1)
      expect(sites[0].properties[luhn.es_code]).to eq('100000-9')
    end

    it "imports into existing field with invalid values" do
      collection.sites.make properties: {luhn.es_code => '100000-9'}

      csv_string = CSV.generate do |csv|
        csv << ['Name', 'Luhn']
        csv << ['Foo', 'Hello']
        csv << ['Bar', '100000-8']
        csv << ['Baz', '100000-9']
      end

      specs = [
        {header: 'Name', use_as: 'name'},
        {header: 'Luhn', use_as: 'existing_field', field_id: luhn.id},
        ]

      ImportWizard.import user, collection, 'foo.csv', csv_string
      ImportWizard.mark_job_as_pending user, collection
      sites = (ImportWizard.validate_sites_with_columns user, collection, specs)

      sites_errors = sites[:errors]
      data_errors = sites_errors[:data_errors]
      expect(data_errors.length).to eq(3)

      expect(data_errors[0][:description]).to eq("Some of the values in field 'Luhn' (2nd column) are not valid for the type luhn identifier: The value must be in this format: nnnnnn-n (where 'n' is a number).")
      expect(data_errors[0][:column]).to eq(1)
      expect(data_errors[0][:rows]).to eq([0])

      expect(data_errors[1][:description]).to eq("Some of the values in field 'Luhn' (2nd column) are not valid for the type luhn identifier: Invalid Luhn check digit.")
      expect(data_errors[1][:column]).to eq(1)
      expect(data_errors[1][:rows]).to eq([1])

      expect(data_errors[2][:description]).to eq("Some of the values in field 'Luhn' (2nd column) are not valid for the type luhn identifier: The value already exists in the collection.")
      expect(data_errors[2][:column]).to eq(1)
      expect(data_errors[2][:rows]).to eq([2])
      ImportWizard.delete_files(user, collection)
    end


    it "show validation error if the luhn value is repeated in the CSV" do
      csv_string = CSV.generate do |csv|
        csv << ['Name', 'Luhn']
        csv << ['Bar', '100000-9']
        csv << ['Baz', '100000-9']
      end

      specs = [
        {header: 'Name', use_as: 'name'},
        {header: 'Luhn', use_as: 'existing_field', field_id: luhn.id},
        ]

      ImportWizard.import user, collection, 'foo.csv', csv_string
      ImportWizard.mark_job_as_pending user, collection
      sites = (ImportWizard.validate_sites_with_columns user, collection, specs)

      sites_errors = sites[:errors]

      data_errors = sites_errors[:data_errors]

      expect(data_errors.length).to eq(1)

      expect(data_errors[0][:description]).to eq("Some of the values in field 'Luhn' (2nd column) are not valid for the type luhn identifier: the value is repeated in rows 1 and 2.")
      expect(data_errors[0][:column]).to eq(1)
      expect(data_errors[0][:rows]).to eq([0, 1])
      ImportWizard.delete_files(user, collection)
    end

     it "should not show validation error if the luhn value is empty (because the value will be autogenerated)" do
      csv_string = CSV.generate do |csv|
        csv << ['Name', 'Luhn']
        csv << ['Bar', '']
        csv << ['Baz', '']
      end

      specs = [
        {header: 'Name', use_as: 'name'},
        {header: 'Luhn', use_as: 'existing_field', field_id: luhn.id},
        ]

      ImportWizard.import user, collection, 'foo.csv', csv_string
      ImportWizard.mark_job_as_pending user, collection
      sites = (ImportWizard.validate_sites_with_columns user, collection, specs)

      sites_errors = sites[:errors]
      data_errors = sites_errors[:data_errors]
      expect(data_errors.length).to eq(0)
      ImportWizard.delete_files(user, collection)
    end

    it "should store max luhn value in a json file" do
      luhn2 = layer.identifier_fields.make code: 'luhn2', config: {'format' => 'Luhn'}
      luhn3 = layer.identifier_fields.make code: 'luhn3', config: {'format' => 'Luhn'}

      csv_string = CSV.generate do |csv|
        csv << ['Name', 'Luhn', 'Luhn2', 'Luhn3']
        csv << ['Bar', '100000-9', '', '']
        csv << ['Baz', '100002-5', '', '100001-7']
        csv << ['Baz', '100001-7', '', '']
      end

      specs = [
        {header: 'Name', use_as: 'name'},
        {header: 'Luhn', use_as: 'existing_field', field_id: luhn.id},
        {header: 'Luhn2', use_as: 'existing_field', field_id: luhn2.id},
        {header: 'Luhn3', use_as: 'existing_field', field_id: luhn3.id},
        ]

      ImportWizard.import user, collection, 'foo.csv', csv_string
      ImportWizard.mark_job_as_pending user, collection
      ImportWizard.validate_sites_with_columns user, collection, specs

      luhn_data = JSON.load(File.read(aditional_data_file_for(user, collection)))
      expect(luhn_data[luhn.es_code]).to eq('100002-5')
      expect(luhn_data[luhn2.es_code]).to eq(nil)
      expect(luhn_data[luhn3.es_code]).to eq('100001-7')
      ImportWizard.delete_files(user, collection)
    end
  end

  describe "Normal identifier fields" do

    it "imports into existing normal normal with non-blank values" do
      csv_string = CSV.generate do |csv|
        csv << ['Name', 'Normal']
        csv << ['Foo', '1']
        csv << ['Bar', '2']
        csv << ['Baz', '3']
      end

      specs = [
        {header: 'Name', use_as: 'name'},
        {header: 'Normal', use_as: 'existing_field', field_id: normal.id},
        ]

      ImportWizard.import user, collection, 'foo.csv', csv_string
      ImportWizard.mark_job_as_pending user, collection
      ImportWizard.execute user, collection, specs

      sites = collection.sites
      expect(sites.length).to eq(3)

      expect(sites[0].properties[normal.es_code]).to eq('1')
      expect(sites[1].properties[normal.es_code]).to eq('2')
      expect(sites[2].properties[normal.es_code]).to eq('3')
    end

    it "should not show validation errors for existing normal identifier field with the same value" do
      site = collection.sites.make properties: {normal.es_code => '1'}

      csv_string = CSV.generate do |csv|
        csv << ['resmap-id', 'Name', 'Normal']
        csv << [site.id, 'Foo', '1']
      end

      specs = [
        {header: 'resmap-id', use_as: 'id'},
        {header: 'Name', use_as: 'name'},
        {header: 'Normal', use_as: 'existing_field', field_id: normal.id},
        ]

      ImportWizard.import user, collection, 'foo.csv', csv_string
      ImportWizard.mark_job_as_pending user, collection
      sites = (ImportWizard.validate_sites_with_columns user, collection, specs)

      sites_errors = sites[:errors]
      data_errors = sites_errors[:data_errors]
      expect(data_errors.length).to eq(0)
      ImportWizard.delete_files(user, collection)
    end

    it "imports into existing normal identifier field with the same value" do
      site = collection.sites.make properties: {normal.es_code => '1'}

      csv_string = CSV.generate do |csv|
        csv << ['resmap-id', 'Name', 'Normal']
        csv << [site.id, 'Foo', '1']
      end

      specs = [
        {header: 'resmap-id', use_as: 'id'},
        {header: 'Name', use_as: 'name'},
        {header: 'Normal', use_as: 'existing_field', field_id: normal.id},
        ]

      ImportWizard.import user, collection, 'foo.csv', csv_string
      ImportWizard.mark_job_as_pending user, collection
      ImportWizard.execute user, collection, specs

      sites = collection.sites
      expect(sites.length).to eq(1)
      expect(sites[0].properties[normal.es_code]).to eq('1')
    end

    it "should  show validation errors for repeated normal identifier inside the collection" do
      site = collection.sites.make properties: {normal.es_code => '1'}

      csv_string = CSV.generate do |csv|
        csv << ['Name', 'Normal']
        csv << ['Bar', '1']
      end

      specs = [
        {header: 'Name', use_as: 'name'},
        {header: 'Normal', use_as: 'existing_field', field_id: normal.id},
        ]

      ImportWizard.import user, collection, 'foo.csv', csv_string
      ImportWizard.mark_job_as_pending user, collection
      sites = (ImportWizard.validate_sites_with_columns user, collection, specs)

      sites_errors = sites[:errors]
      data_errors = sites_errors[:data_errors]
      expect(data_errors.length).to eq(1)

      expect(data_errors[0][:description]).to eq("Some of the values in field 'Normal' (2nd column) are not valid for the type identifier: The value already exists in the collection.")
      expect(data_errors[0][:column]).to eq(1)
      expect(data_errors[0][:rows]).to eq([0])
      ImportWizard.delete_files(user, collection)
    end

    it "show validation error if the values are repeated in the CSV" do
      csv_string = CSV.generate do |csv|
        csv << ['Name', 'Normal']
        csv << ['Bar', '1000']
        csv << ['Baz', '1000']
      end

      specs = [
        {header: 'Name', use_as: 'name'},
        {header: 'Normal', use_as: 'existing_field', field_id: normal.id},
        ]

      ImportWizard.import user, collection, 'foo.csv', csv_string
      ImportWizard.mark_job_as_pending user, collection
      sites = (ImportWizard.validate_sites_with_columns user, collection, specs)

      sites_errors = sites[:errors]
      data_errors = sites_errors[:data_errors]
      expect(data_errors.length).to eq(1)

      expect(data_errors[0][:description]).to eq("Some of the values in field 'Normal' (2nd column) are not valid for the type identifier: the value is repeated in rows 1 and 2.")
      expect(data_errors[0][:column]).to eq(1)
      expect(data_errors[0][:rows]).to eq([0, 1])
      ImportWizard.delete_files(user, collection)
    end
  end



end
