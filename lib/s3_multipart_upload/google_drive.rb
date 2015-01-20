require 'google/api_client'

require 's3_multipart_upload/file'

module S3MultipartUpload
  module GoogleDrive
    class << self
      def find_by_id(id)
        response = client.execute(
          api_method: drive.files.get,
          parameters: { fileId: id }
        )
        GoogleDrive::File.new(response.data) if response.status == 200
      end

      def client
        @client ||= Google::APIClient.new(application_name: "S3MultipartUpload", application_version: "v1").tap do |client|
          key = OpenSSL::PKey::RSA.new client_credentials.private_key, client_credentials.secret
          client.authorization = Signet::OAuth2::Client.new(
            token_credential_uri: 'https://accounts.google.com/o/oauth2/token',
            audience: 'https://accounts.google.com/o/oauth2/token',
            scope: 'https://www.googleapis.com/auth/drive',
            issuer: client_credentials.client_email,
            signing_key: key
          )
          client.authorization.fetch_access_token!
        end
      end

      def drive
        @drive ||= client.discovered_api 'drive', 'v2'
      end

      private

      def client_credentials
        S3MultipartUpload.config.gd
      end
    end

    class File < S3MultipartUpload::File
      attr_reader :metadata

      delegate :file_size, :mime_type, to: :metadata

      def initialize(metadata)
        @metadata = metadata
      end

      def url
        metadata.download_url
      end

      def part(starts, ends)
        GoogleDrive::File::Part.new starts, ends
      end

      class Part < S3MultipartUpload::File::Part
        attr_accessor :file

        def data
          response = GoogleDrive.client.execute uri: file.url, headers: { Range: "bytes=#{self.first}-#{self.last}" }
          response.body
        end
      end
    end
  end
end