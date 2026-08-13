import webserver
import string

class webradio_driver
  var _enabled
  var _html_file
  var _css_file
  var _js_file

  def init()
    self._enabled = false
    self._html_file = "webradio/index.htm"
    self._css_file  = "webradio/style.css"
    self._js_file   = "webradio/app.js"
    tasmota.set_timer(0, /-> self.start())
  end

  # lecture fichier texte (safe)
  def read_text_file(path)
    try
      var f = open(path, "r")
      var s = f.read()
      f.close()
      return s
    except .. as e
      return "/* ERROR reading " + path + " : " + string(e) + " */"
    end
  end

  # extrait le contenu entre <body ...> et </body>
  def extract_body(html)
    var s = html
    var b1 = string.find(s, "<body")
    if b1 != nil
      var gt = string.find(s, ">", b1)
      if gt != nil
        var b2 = string.find(s, "</body>", gt)
        if b2 != nil
          s = s[gt + 1 .. b2 - 1]
        end
      end
    end
    return s
  end

  def web_add_handler()
    webserver.on("/webradio", /-> self.http_get(), webserver.HTTP_GET)
  end

  def http_get()
    if !webserver.check_privileged_access() return nil end

    var html = self.read_text_file(self._html_file)
    var css  = self.read_text_file(self._css_file)
    var js   = self.read_text_file(self._js_file)

    webserver.content_start("WebRadio")

    # style Tasmota + ton CSS inline
    webserver.content_send_style()
    webserver.content_send("<style>\n" + css + "\n</style>\n")

    # wrapper + HTML body
    webserver.content_send("<div style='max-width:900px;margin:20px auto;padding:0 10px'>\n")
    webserver.content_send(self.extract_body(html))
    webserver.content_send("\n</div>\n")

    # ton JS inline (à la fin)
    webserver.content_send("<script>\n" + js + "\n</script>\n")

    webserver.content_button(webserver.BUTTON_MAIN)
    webserver.content_stop()
  end

  def start()
    if !self._enabled
      tasmota.add_driver(self)
      self.web_add_handler()
      self._enabled = true
      tasmota.publish_result('{"WebRadio":"UI enabled"}', "RESULT")
    end
  end
end

var d = webradio_driver()
return d