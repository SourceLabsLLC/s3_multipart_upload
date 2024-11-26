require 'aws-sdk-s3'
require 'active_support/core_ext/numeric/bytes'

module S3MultipartUpload
  module Uploader
    class << self
      MIN_PART_SIZE = 5.megabytes
      MAX_PARTS = 10000

      def upload(file, path)
        part_size = compute_part_size file.file_size
        parts = file.split_into_parts(part_size)

        s3_object = s3_bucket.object(path)

        s3_object.multipart_upload(acl: :public_read, content_type: file.mime_type) do |upload|
          parts.each do |part|
            upload.add_part part.data
          end
        end

        { public_url: s3_object.public_url.to_s }
      end

      private

      def s3_config
        S3MultipartUpload.config.s3
      end

      def s3_bucket
        s3 = Aws::S3::Resource.new access_key_id: s3_config.key, secret_access_key: s3_config.secret
        s3.bucket(s3_config.bucket_name)
      end

      def compute_part_size(size)
        part_size = MIN_PART_SIZE
        while size / part_size > MAX_PARTS
          part_size *= 2
        end
        part_size
      end
    end
  end
end