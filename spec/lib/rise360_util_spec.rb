require 'rails_helper'
require 'rise360_util'

RSpec.describe Rise360Util do

  let(:aws_bucket) { double(Rise360Util::AwsS3Bucket) }
  let(:aws_object) { instance_double(Aws::S3::Object) }
  let(:rise360_module) { create(:rise360_module_with_zipfile) }

  before(:each) do
    allow(Rise360Util::AwsS3Bucket).to receive(:new).and_return(aws_bucket)
    allow(aws_bucket).to receive(:object).and_return(aws_object)
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

  describe '#presigned_url' do
    context 'when valid Rise360 zipfile' do

      it 'returns a presigned URL' do
        presigned_query = 'X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=FAKEACCESSKEY%2F20210316%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20210316T175545Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=37FAKESIGNATURE9c'
        presigned_url = "https://S3-bucket-path/lessons/somekey/index.html?#{presigned_query}"

        expect(aws_bucket).to receive(:object).with('lessons/somekey/index.html').and_return(aws_object)
        expect(aws_object).to receive(:presigned_url).with(:get, Hash).and_return(presigned_url)
        expect(Rise360Util.presigned_url('/lessons/somekey/index.html')).to eq(presigned_url)
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
        expect(rise360_module.quiz_breakdown).to eq([2, 2])
        expect(rise360_module.activity_id).to eq('http://OrDngAKqbvX4sCs0vBpsk-P1VXsst1vc_rise')
      end

    end
  end
end
