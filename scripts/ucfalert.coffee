parseXml = require("xml2js").parseString

fs = require 'fs'

if fs.existsSync("latest-alert.txt")
  alertMemory = fs.readFileSync("latest-alert.txt").toString()
else
  alertMemory = ""

module.exports = (robot) ->
  alertCheckCount = 0
  checkUCFAlert = ->
    alertCheckCount++
    robot.http("https://alert.ucf.edu/rssfeed.php")
      .get() (err, res, body) ->
        parseXml body, (err, result) ->
          topItem = result.rss.channel[0].item[0]
          if alertMemory == ""
            alertMemory = topItem.pubDate.toString()
            saveAlertMemory()
            return
          if topItem.pubDate.toString() != alertMemory
            robot.messageRoom "social", ":rotating_light: *UCF Alert* :rotating_light:\n\n" + topItem.description
            alertMemory = topItem.pubDate.toString()
            saveAlertMemory()

  checkUCFAlert()
  setInterval checkUCFAlert, 120000

  saveAlertMemory = ->
    fs.writeFileSync("latest-alert.txt", alertMemory)
