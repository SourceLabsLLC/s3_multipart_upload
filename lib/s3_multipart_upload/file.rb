module S3MultipartUpload
  class File
    attr_accessor :url, :file_size, :mime_type

    def part(starts, ends)
    end

    def split_into_parts(part_size)
      boundaries = Range.new(0, file_size).step(part_size).to_a.tap do |_|
        _.push(file_size) unless _.last == file_size
      end

      starts = boundaries[0...-1]
      ends = boundaries[1..-1]

      starts.zip(ends).map do |_|
        part(_.first, _.last - 1).tap do |o|
          o.file = self
        end
      end
    end

    class Part < ::Range
      attr_accessor :file, :data
    end
  end
end