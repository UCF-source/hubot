# Description:
#   A way to interact with the Google Images API.
#
# Configuration
#   HUBOT_GOOGLE_CSE_KEY - Your Google developer API key
#   HUBOT_GOOGLE_CSE_ID - The ID of your Custom Search Engine
#   HUBOT_MUSTACHIFY_URL - Optional. Allow you to use your own mustachify instance.
#   HUBOT_GOOGLE_IMAGES_HEAR - Optional. If set, bot will respond to any line that begins with "image me" or "animate me" without needing to address the bot directly
#   HUBOT_GOOGLE_SAFE_SEARCH - Optional. Search safety level.
#   HUBOT_GOOGLE_IMAGES_FALLBACK - The URL to use when API fails. `{q}` will be replaced with the query string.
#
# Commands:
#   hubot image me <query> - The Original. Queries Google Images for <query> and returns a random top result.
#   hubot animate me <query> - The same thing as `image me`, except adds a few parameters to try to return an animated GIF instead.
#   hubot mustache me <url> - Adds a mustache to the specified URL.
#   hubot mustache me <query> - Searches Google Images for the specified query and mustaches it.

module.exports = (robot) ->
  lastImageUrl = {}
  lastMessageReference = {}

  robot.on 'selfmessage', (msg) ->
    if msg.text and msg.subtype != "bot_message"
      for key of lastImageUrl
        if msg.text.indexOf(lastImageUrl[key]) != -1
          lastMessageReference[key] = msg

  robot.respond /delete/i, (msg) ->
    if lastMessageReference[msg.message.rawMessage.channel]
      queryData =  {
          token: process.env.HUBOT_SLACK_TOKEN
          channel: msg.message.rawMessage.channel
          ts: lastMessageReference[msg.message.rawMessage.channel].ts
        }

      robot.http("https://slack.com/api/chat.delete")
        .query(queryData)
        .post() (err, res, body) ->
          msg.reply "I deleted the message. Sorry about that. :relieved:"
          lastMessageReference[msg.message.rawMessage.channel] = null
          return
    else
      msg.reply "Nothing to delete :flushed:"

  robot.respond /(image|img)( me)? (.+)/i, (msg) ->
    imageMe msg, msg.match[3], (url) ->
      lastImageUrl[msg.message.rawMessage.channel] = url
      msg.send url

  robot.respond /animate( me)? (.+)/i, (msg) ->
    imageMe msg, msg.match[2], true, (url) ->
      lastImageUrl[msg.message.rawMessage.channel] = url
      console.log("============== MESSAGE ==== ", msg.send(url))

  robot.respond /(?:mo?u)?sta(?:s|c)h(?:e|ify)?(?: me)? (.+)/i, (msg) ->
    mustacheBaseUrl =
      process.env.HUBOT_MUSTACHIFY_URL?.replace(/\/$/, '') or
      "http://mustachify.me"
    mustachify = "#{mustacheBaseUrl}/rand?src="
    imagery = msg.match[1]

    if imagery.match /^https?:\/\//i
      encodedUrl = encodeURIComponent imagery
      msg.send "#{mustachify}#{encodedUrl}"
    else
      imageMe msg, imagery, false, true, (url) ->
        encodedUrl = encodeURIComponent url
        msg.send "#{mustachify}#{encodedUrl}"

imageMe = (msg, query, animated, faces, cb) ->
  cb = animated if typeof animated == 'function'
  cb = faces if typeof faces == 'function'
  googleCseId = process.env.HUBOT_GOOGLE_CSE_ID
  if googleCseId
    # Using Google Custom Search API
    googleApiKey = process.env.HUBOT_GOOGLE_CSE_KEY
    if !googleApiKey
      msg.robot.logger.error "Missing environment variable HUBOT_GOOGLE_CSE_KEY"
      msg.send "Missing server environment variable HUBOT_GOOGLE_CSE_KEY."
      return
    q =
      q: query,
      searchType:'image',
      safe: process.env.HUBOT_GOOGLE_SAFE_SEARCH || 'high',
      fields:'items(link)',
      cx: googleCseId,
      key: googleApiKey
    if animated is true
      q.fileType = 'gif'
      q.hq = 'animated'
      q.tbs = 'itp:animated'
    if faces is true
      q.imgType = 'face'
    url = 'https://www.googleapis.com/customsearch/v1'
    msg.http(url)
      .query(q)
      .get() (err, res, body) ->
        if err
          if res.statusCode is 403
            msg.send "Daily image quota exceeded, using alternate source."
            deprecatedImage(msg, query, animated, faces, cb)
          else
            msg.send "Encountered an error :( #{err}"
          return
        if res.statusCode isnt 200
          msg.send "Bad HTTP response :( #{res.statusCode}"
          return
        response = JSON.parse(body)
        if response?.items
          image = msg.random response.items
          cb ensureResult(image.link, animated)
        else
          console.log(body)
          console.log(err)
          console.log(res)
          msg.send "Oops. I had trouble searching '#{query}'. Try later."
          ((error) ->
            msg.robot.logger.error error.message
            msg.robot.logger
              .error "(see #{error.extendedHelp})" if error.extendedHelp
          ) error for error in response.error.errors if response.error?.errors
  else
    msg.send "Google Image Search API is not longer available. " +
      "Please setup up Custom Search Engine API."
    deprecatedImage(msg, query, animated, faces, cb)

deprecatedImage = (msg, query, animated, faces, cb) ->
  # Show a fallback image
  imgUrl = process.env.HUBOT_GOOGLE_IMAGES_FALLBACK ||
    'http://i.imgur.com/CzFTOkI.png'
  imgUrl = imgUrl.replace(/\{q\}/, encodeURIComponent(query))
  cb ensureResult(imgUrl, animated)

# Forces giphy result to use animated version
ensureResult = (url, animated) ->
  if animated is true
    ensureImageExtension url.replace(
      /(giphy\.com\/.*)\/.+_s.gif$/,
      '$1/giphy.gif')
  else
    ensureImageExtension url

# Forces the URL look like an image URL by adding `#.png`
ensureImageExtension = (url) ->
  if /(png|jpe?g|gif)$/i.test(url)
    url
  else
    "#{url}#.png"
