require 'singleton'

module S3MultipartUpload
  class Config
    include Singleton

    attr_reader :s3, :gd

    def initialize
      @s3 = S3Config.new
      @gd = GDConfig.new
    end

    class S3Config
      attr_accessor :bucket_name, :secret, :key
    end

    class GDConfig
      attr_accessor :client_email, :secret, :private_key
    end
  end
end
