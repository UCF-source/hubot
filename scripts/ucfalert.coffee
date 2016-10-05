parseXml = require("xml2js").parseString

fs = require 'fs'

if fs.existsSync("latest-alert.txt")
  alertMemory = fs.readFileSync("latest-alert.txt")
else
  alertMemory = ""

module.exports = (robot) ->
  checkUCFAlert = ->
    robot.http("https://alert.ucf.edu/rssfeed.php")
      .get() (err, res, body) ->
        parseXml body, (err, result) ->
          topItem = result.rss.channel[0].item[0]
          if alertMemory == ""
            alertMemory = topItem.pubDate
            saveAlertMemory()
            return
          if topItem.pubDate != alertMemory
            alertMemory = topItem.pubDate
            saveAlertMemory()
            robot.messageRoom "bmotestchannel", ":rotating_light: *UCF Alert* :rotating_light:\n\n" + topItem.description

  checkUCFAlert()
  setInterval checkUCFAlert, 120000

  saveAlertMemory = ->
    fs.writeFileSync("latest-alert.txt", alertMemory)

