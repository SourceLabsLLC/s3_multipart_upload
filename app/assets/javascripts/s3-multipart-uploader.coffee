do ($, _, Bacon) ->
  slice = (data, start, end) ->
    if data.slice
      data.slice start, end
    else if data.webkitSlice
      data.webkitSlice start, end
    else if data.mozSlice
      data.mozSlice start, end

  BitrateEstimator = ->
    SMOOTHING_FACTOR = 0.35
    BITRATE_INTERVAL = 5000
    MINIMUM_SAMPLE_SIZE = 4

    @init = ->
      @lastSample = timestamp: (new Date()).getTime(), loaded: 0, size: 0

    @compute = (loaded) ->
      currentTime = (new Date()).getTime()
      timeDifference = currentTime - @lastSample.timestamp

      if not @lastSample.bitrate or timeDifference > BITRATE_INTERVAL
        currentBitrate = (loaded - @lastSample.loaded) * (1000 / timeDifference) * 8
        averageBitrate = SMOOTHING_FACTOR * currentBitrate + (1 - SMOOTHING_FACTOR) * (@lastSample.bitrate || currentBitrate)
        @lastSample = timestamp: currentTime, loaded: loaded, bitrate: averageBitrate, size: @lastSample.size + 1

      if @lastSample.size >= MINIMUM_SAMPLE_SIZE
        value: @lastSample.bitrate
      else
        computing: true
    @

  S3MultipartUploader = ({bucket, folder, signer, concurrent, start, progress, process, success}) ->
    MIN_PART_SIZE = 5 * 1024 * 1024
    MAX_PARTS = 10000
    MAX_CONCURRENT_PARTS_UPLOAD = 5

    host = "https://#{bucket}.s3.amazonaws.com"
    bitrateEstimator = new BitrateEstimator()

    computePartSize = (size) ->
      partSize = MIN_PART_SIZE
      partSize *= 2 while size / partSize > MAX_PARTS
      partSize

    splitIntoParts = (data, partSize) ->
      _start = 0

      parts = while _start < data.size
        currStart = _start
        currEnd = Math.min currStart + partSize, data.size
        _start += partSize
        slice data, currStart, currEnd

      _.zip _.range(1, parts.length + 1), parts

    signRequest = ({data, onSuccess, onError}) ->
      $.ajax
        type: "POST"
        url: signer
        data: data
        dataType: "json"
        success: onSuccess
        error: onError

    initiateUpload = (objectPath, mimeType) ->
      xhr = new XMLHttpRequest

      relativeUrl = "#{objectPath}?uploads"
      absoluteUrl = "#{host}#{relativeUrl}"

      _success = Bacon.fromEventTarget(xhr, "load")
        .map (e) ->
          if xhr.status is 200
            complete: true
            uploadId: $(xhr.response).find("UploadId").text()
          else
            error: true
            retry: _start

      _error = Bacon.fromEventTarget(xhr, "error")
        .map (e) ->
          error: true
          retry: _start

      [_success, _error].forEach (es) -> es.onValue ->

      _signError = new Bacon.Bus()

      _start = ->
        signRequest
          data: { method: "POST", url: relativeUrl, content_type: mimeType }
          onSuccess: ({date, signature}) ->
            xhr.open "POST", absoluteUrl
            xhr.setRequestHeader "x-amz-date", date
            xhr.setRequestHeader "Authorization", signature
            xhr.setRequestHeader "Content-Type", mimeType
            xhr.responseType = "document"
            xhr.send()
          onError: (e) ->
            _signError.push error: true, retry: _start

      Bacon.mergeAll(_success, _error, _signError).toProperty(waiting: true, start: _start)

    prepareForUpload = (part, objectPath, uploadId) ->
      xhr = new XMLHttpRequest

      relativeUrl = "#{objectPath}?partNumber=#{part.key}&uploadId=#{uploadId}"
      absoluteUrl = "#{host}#{relativeUrl}"

      _progress = Bacon.fromEventTarget(xhr.upload, "progress")
        .map (e) ->
          uploading: true
          uploaded: e.loaded
          total: e.total

      _success = Bacon.fromEventTarget(xhr, "load")
        .map (e) ->
          if xhr.status is 200
            part.etag = xhr.getResponseHeader "ETag"
            complete: true
            part: part
          else
            error: true
            retry: _start

      _error = Bacon.fromEventTarget(xhr, "error")
        .map (e) ->
          error: true
          retry: _start

      [_progress, _success, _error].forEach (es) -> es.onValue ->

      _signError = new Bacon.Bus()

      _queued = new Bacon.Bus()

      _start = ->
        _queued.push queue: true
        signRequest
          data: { url: relativeUrl, method: "PUT" }
          onSuccess: ({date, signature}) ->
            xhr.open "PUT", absoluteUrl
            xhr.setRequestHeader "x-amz-date", date
            xhr.setRequestHeader "Authorization", signature
            xhr.send part.data
          onError: ->
            _signError.push error: true, retry: _start

      Bacon.mergeAll(_queued, _progress, _success, _error, _signError).toProperty(waiting: true, start: _start)

    uploadParts = (parts, objectPath, uploadId) ->
      uploads = _.map parts, (part) -> prepareForUpload(part, objectPath, uploadId)

      bitrateEstimator.init()

      Bacon.combineAsArray(uploads).map (_uploads) ->
        complete = _uploads.filter (x) -> x.complete
        uploading = _uploads.filter (x) -> x.uploading
        waiting = _uploads.filter (x) -> x.waiting
        queued = _uploads.filter (x) -> x.queue
        failed = _uploads.filter (x) -> x.error

        concurrencyLevel = if concurrent then MAX_CONCURRENT_PARTS_UPLOAD else 1

        if failed.length
          _.delay _.first(failed).retry, 1000
        else if waiting.length and (queued.length + uploading.length) < concurrencyLevel
          _.first(waiting).start()

        if complete.length is parts.length
          complete: true
          parts: parts
        else if uploading.length
          uploaded = _.reduce(uploading, ((s, x) -> s + x.uploaded), 0) + _.reduce(complete, ((s,x) -> s + x.part.data.size), 0)
          total = _.reduce(parts, ((s,x) -> s + x.data.size), 0)
          uploadSpeed = bitrateEstimator.compute uploaded

          uploading: true
          total: total
          uploaded: uploaded
          timeRemaining: ((total - uploaded) * 8 / uploadSpeed.value) unless uploadSpeed.computing?
        else
          waiting: true

    completeUpload = (parts, objectPath, uploadId) ->
      relativeUrl = "#{objectPath}?uploadId=#{uploadId}"
      absoluteUrl = "#{host}#{relativeUrl}"

      partsXml = _.chain(parts)
        .sortBy (p) ->
          p.key
        .map (p) ->
          "<Part><PartNumber>#{p.key}</PartNumber><ETag>#{p.etag}</ETag></Part>"
        .reduce ((s, xml) -> s + xml), ""
        .value()

      payload = "<CompleteMultipartUpload>#{partsXml}</CompleteMultipartUpload>"

      xhr = new XMLHttpRequest

      _success = Bacon.fromEventTarget(xhr, "load")
        .map (e) ->
          if xhr.status is 200 and $(xhr.response).is("error") is no
            complete: true
            url: unescape $(xhr.response).find("Location").text()
          else
            error: true
            retry: _start

      _error = Bacon.fromEventTarget(xhr, "error")
        .map (e) ->
          error: true
          retry: _start

      [_success, _error].forEach (es) -> es.onValue ->

      _signError = new Bacon.Bus()

      _start = ->
        signRequest
          data: { method: "POST", url: relativeUrl, content_type: "application/xml; charset=UTF-8" }
          onSuccess: ({date, signature}) ->
            xhr.open "POST", absoluteUrl
            xhr.setRequestHeader "x-amz-date", date
            xhr.setRequestHeader "Authorization", signature
            xhr.setRequestHeader "Content-Type", "application/xml; charset=UTF-8"
            xhr.responseType = "document"
            xhr.send payload
          onError: (e) ->
            _signError.push error: true, retry: _start

      Bacon.mergeAll(_success, _error, _signError).toProperty(waiting: true, start: _start)

    upload = (file) ->
      partSize = computePartSize file.size
      parts = _.map splitIntoParts(file, partSize), (part) -> key: part[0], data: part[1]

      sanitizedFileName = file.name.replace(/[^0-9a-z.]/gi, "_").toLowerCase()

      objectPath = "/#{folder}/#{sanitizedFileName}"

      start file: file

      initiateUpload(objectPath, file.type).onValue (status) ->
        if status.waiting
          status.start()
        else if status.complete
          {uploadId} = status
          uploadParts(parts, objectPath, uploadId).onValue (status) ->
            if status.complete
              completeUpload(status.parts, objectPath, uploadId).onValue (status) ->
                if status.waiting
                  status.start()
                  process()
                else if status.complete
                  success url: status.url
                else if status.error
                  _.delay status.retry, 1000
            else if status.uploading
              {uploaded, total, timeRemaining} = status
              progress uploaded: uploaded, total: total, timeRemaining: timeRemaining
        else if status.error
          _.delay status.retry, 1000

    @upload = upload

    @

  @S3MultipartUploader = S3MultipartUploader
