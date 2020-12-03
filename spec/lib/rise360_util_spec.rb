require 'rails_helper'
require 'rise360_util'

RSpec.describe Rise360Util do

  let(:aws_object) { instance_double(Aws::S3::Object) }
  let(:rise360_module) { create(:rise360_module_with_zipfile) }

  before(:each) do
    allow_any_instance_of(Rise360Util::AwsS3Bucket).to receive(:object).and_return(aws_object)
    allow(aws_object).to receive(:public_url).and_return("https://S3-bucket-path/lessons/somekey/index.html")
    allow(aws_object).to receive(:put)
  end

  describe '#publish' do
    context 'when valid Rise360 zipfile' do

      it 'unzips to S3' do
        expect(aws_object).to receive(:put).with(Hash).at_least(10).times # There are a bunch of files in there to unzip. 10 is arbitrary
        rise360_module # The creation of this object causes it to be published.
      end

    end
  end

  describe '#launch_path' do
    context 'when valid Rise360 zipfile' do

      it 'returns launch URL' do
        allow(Rise360Util).to receive(:publish).and_return("https://S3-bucket-path/lessons/somekey/index.html")
        expect(aws_object).to receive(:public_url).and_return("https://S3-bucket-path/lessons/somekey/index.html")
        expect(Rise360Util.launch_path(rise360_module.rise360_zipfile.key)).to eq('/lessons/somekey/index.html')
      end

    end
  end

  describe '#update_metadata!' do
    context 'when valid Rise360 zipfile' do

      it 'updates the record appropriately' do
        expect(aws_object).to receive(:get).and_return({'body':
            File.open("#{Rails.root}/spec/fixtures/example_tincan.xml")}.with_indifferent_access).at_least(:once)
        rise360_module  # The creation of this object causes the callback to fire.
        expect(rise360_module.quiz_questions).to eq(4)
        expect(rise360_module.activity_id).to eq('http://OrDngAKqbvX4sCs0vBpsk-P1VXsst1vc_rise')
      end

    end
  end
end
