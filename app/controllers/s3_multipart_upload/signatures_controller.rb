module S3MultipartUpload
  class SignaturesController < ApplicationController
    def generate
      time = Time.now.strftime "%a, %d %b %Y %T %z"
      render json: { date: time, signature: sign_request(time) }
    end

    private

    def sign_request(time)
      unsigned_request = <<-REQUEST.gsub(/\n +/, "\n").strip
        #{params[:method]}
        #{params[:content_md5]}
        #{params[:content_type]}

        x-amz-date:#{time}
        /#{s3_config.bucket_name}#{URI::escape(params[:url])}
      REQUEST

      signature = Base64.strict_encode64(OpenSSL::HMAC.digest('sha1', s3_config.secret, unsigned_request))

      "AWS #{s3_config.key}:#{signature}"
    end

    def s3_config
      S3MultipartUpload.config.s3
    end
  end
end