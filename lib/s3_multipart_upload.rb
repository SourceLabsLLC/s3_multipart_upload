require "s3_multipart_upload/version"

require "s3_multipart_upload/config"
require "s3_multipart_upload/engine"

require "s3_multipart_upload/google_drive_to_s3_uploader"

module S3MultipartUpload

  class << self
    def config(&block)
      yield S3MultipartUpload::Config.instance if block
      S3MultipartUpload::Config.instance
    end

    def upload_from_google_drive(share_url, upload_path)
      GoogleDriveToS3Uploader.upload share_url, upload_path
    end
  end

end
