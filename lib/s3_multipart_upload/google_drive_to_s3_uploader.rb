require 's3_multipart_upload/google_drive'
require 's3_multipart_upload/uploader'

module S3MultipartUpload
  module GoogleDriveToS3Uploader

    def self.upload(share_url, upload_path)
      file_id = share_url.split("/")[5]
      google_drive_file = GoogleDrive.find_by_id file_id

      response = Uploader.upload google_drive_file, upload_path

      response[:public_url]
    end

  end
end