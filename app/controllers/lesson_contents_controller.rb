require 'zip'

class LessonContentsController < ApplicationController
	def new
		@lesson_content = LessonContent.new
	end

	def create
		@filename = params[:lesson_content_zipfile]
		@lesson_content = LessonContent.new(lesson_content_params)
		@lesson_content.save

		# TODO
		# Unzip and upload here (it's in "show" for now so I can easily test it)
	end

	# TODO: Show a preview of the lesson, no LRS or anything set up
	def show
		lesson_content = LessonContent.find(params[:id])
		@path = url_for(lesson_content.lesson_content_zipfile)

		@bucket_prefix = 'lessons/' + lesson_content.lesson_content_zipfile.key + '/'

		# Connect to AWS S3
	    credentials = Aws::Credentials.new(ENV["AWS_ACCESS_KEY_ID"], ENV["AWS_SECRET_ACCESS_KEY"])
	    Aws.config.update({credentials: credentials})
	    s3 = Aws::S3::Resource.new(region: ENV["AWS_REGION"])
	    bucket = s3.bucket(ENV["AWS_S3_BUCKET"])

	    # Create a client so we can set permissions
	    client = Aws::S3::Client.new(region: ENV["AWS_REGION"])

		# Unzip
		# TODO: alternate: store .zip on disk with ActiveStorage 
		# since we don't really need to persist it instead of downloading
		@all_files = ''
		@all_dirs = ''
		lesson_content.lesson_content_zipfile.open do |file|
			@filepath = file.path
			puts file.path
			# zipfile = Zip::File.new(file.path)
			# zipfile.each_with_index do |entry, index|
			# 	@all_files += "entry #{index} is #{entry.name}, size = #{entry.size}, compressed size = #{entry.compressed_size}"
			# 	@all_files += "\n"
			# end
			Zip::File.open(file.path) do |zip_file|
				zip_file.each do |entry|
					if entry.file?
						@all_files +=  "#{entry.name}"

						# Upload the temporary file to the bucket
						# This gets us the right directory structure
						object_key = @bucket_prefix + "#{entry.name}"

						s3_obj = bucket.object(object_key)
						s3_obj.put(body: entry.get_input_stream.read)

						# TODO: Make each object public read as we're making it?
						client.put_object_acl( {
							acl: "public-read",
							bucket: ENV["AWS_S3_BUCKET"],
							key: object_key,
						})
						# Nope, don't do this, this upload the entire zipfile??? WTF.
						#s3_obj.put(body: entry.get_raw_input_stream)

						#entry.extract
						#content = entry.get_input_stream.read
						#puts content

						# This works, but it's unbearably slow
						# Extract and read input to temporary file
						# tempfile = Tempfile.new(File.basename(entry.name))
						# tempfile.binmode
						# tempfile.write(entry.get_input_stream.read)
						#s3_obj.upload_file(tempfile)
					elsif entry.directory? 
						@all_dirs += "#{entry.name}"
					end
				end
			end

			# Now that we've succeeded, make the bucket public
	    	client.put_bucket_acl({
  				acl: "public-read",
  				bucket: ENV["AWS_S3_BUCKET"],
			})
		end


# 		Zip::File.open('foo.zip') do |zip_file|
#   # Handle entries one by one
#   			zip_file.each do |entry|
#     puts "Extracting #{entry.name}"
#     raise 'File too large when extracted' if entry.size > MAX_SIZE

#     # Extract to file or directory based on name in the archive
#     entry.extract

#     # Read into memory
#     content = entry.get_input_stream.read
#   end

#   # Find specific entry
#   entry = zip_file.glob('*.csv').first
#   raise 'File too large when extracted' if entry.size > MAX_SIZE
#   puts entry.get_input_stream.read
# end

# 		lesson_content.lesson_content_zipfile.open do |file|
# 			file_list = Zip::File.open(file.path)
# 			file_list.each do |f|
# 				filename = f.name
# 				basename = File.basename(filename)

# 				tempfile = Tempfile.new(basename)
# 				tempfile.binmode
# 				tempfile.write file_list.get_input_stream(f).read

# 			  	s3_obj = bucket.objects[ @bucket_prefix + filename ]
# 			  	s3_obj.write(tempfile)
# 			end
# 		end

				# lesson_contents + ID? 
				# obj = bucket.object(@bucket_prefix + "#{entry.name}")
				# obj.upload_file(entry)
# file_list = Zip::ZipFile.open(zipped_file)
# file_list.each do |file|
#   filename = file.name
#   basename = File.basename(filename)

#   tempfile = Tempfile.new(basename)
#   tempfile.binmode
#   tempfile.write file.get_input_stream.read            

#   s3_obj = bucket.objects[ 'attachments/' + filename ]
#   s3_obj.write(tempfile)
# end


	    # TODO: Access credentials from the shell environment instead


	    # obj = bucket.object('unlock-your-hustle')
	    # obj.upload_file('unlock-your-hustle.zip')


		# Download the zipfile
		# Zip file system: http://rubyzip.sourceforge.net/classes/Zip/ZipFileSystem.html

		# zipfile = lesson_content.lesson_content_zipfile.download
		# zf = Zip::File.new(zipfile)
		# zf.each_with_index do |entry, index|
  # 			puts "entry #{index} is #{entry.name}, size = #{entry.size}, compressed size = #{entry.compressed_size}"
  # 			# use zf.get_input_stream(entry) to get a ZipInputStream for the entry
  # 			# entry can be the ZipEntry object or any object which has a to_s method that
  # 			# returns the name of the entry.
		# end

				# Recursively upload to AWS


	end

	private
    def lesson_content_params
    	params.permit(:lesson_content_zipfile)
    end

    def unzip_file(filename, destination)
    end
end



# def unzip_file (file, destination)
#   Zip::ZipFile.open(file) { |zip_file|
#    zip_file.each { |f|
#      f_path=File.join(destination, f.name)
#      FileUtils.mkdir_p(File.dirname(f_path))
#      zip_file.extract(f, f_path) unless File.exist?(f_path)
#    }
#   }
# end