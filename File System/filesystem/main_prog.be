import persist
import string

var fav_list = []
var last_station = {"name":"", "url":""}
var state = {"playing": false, "level": 20}
var playlist = {"items": [], "index": 0, "mode": "one"}

def load_data()
    if persist.Fav != nil
        fav_list = persist.Fav
        print(fav_list)
    else
        fav_list = []
        persist.Fav = fav_list
        persist.save()
    end

    if persist.LastP != nil
        last_station = persist.LastP
        print(last_station)
    else
        last_station = {"name":"", "url":""}
        persist.LastP = last_station
        persist.save()
    end
end

def save_data()
    persist.Fav = fav_list
    persist.LastP = last_station
    persist.save()
end

def play_station(name, url)
    if url != ""
        state["playing"] = true
        tasmota.cmd("i2swr1")
        tasmota.cmd("delay 10")
        tasmota.cmd("i2swr1 " + url)
        print("playing " + name + " " + url)
        tasmota.cmd("delay 10")
        tasmota.cmd("displaydimmer 1")
        tasmota.set_timer(5000, def()
            last_station = {"name":name, "url":url}
            save_data()
        end)
    end
end

def play_fav(index)
    if (index >= 0) && (index < fav_list.size())
        var s = fav_list[index]
        play_station(s["name"], s["url"])
    end
end

def cmd_playfav(cmd, idx, payload, raw)
    var i = int(payload)
    play_fav(i-1)
    print("playing fav " + str(i))
    tasmota.resp_cmnd_done()
end

def add_fav(index, name, url)
    if (index >= 0) && (index < fav_list.size())
        fav_list[index] = {"name":name, "url":url}
        save_data()
    end
end

def play_last()
    if last_station["url"] != ""
        tasmota.cmd("delay 20")
        play_station(last_station["name"], last_station["url"])
    end
end

def cmd_play(cmd, idx, payload, raw)
  play_last()
  tasmota.resp_cmnd_done()
end

def cmd_stop(cmd, idx, payload, raw)
  tasmota.cmd("I2SStop")
  print("Stopped")
  tasmota.cmd("displaydimmer 0")
  state["playing"] = false
  # playlist intentionnellement non effacée
  tasmota.resp_cmnd_done()
end

def cmd_playurl(cmd, idx, payload, raw)
  var parts = string.split(payload, "||u=")
  if parts.size() >= 2
    play_station(parts[0], parts[1])
  else
    play_station("web", payload)
  end
  tasmota.resp_cmnd_done()
end

# --- Playlist ---

def playlist_next()
  if !state["playing"]
    return
  end
  var items = playlist["items"]
  var index = playlist["index"]
  var mode  = playlist["mode"]
  var n     = items.size()

  if n == 0  return  end

  if mode == "one"
    return

  elif mode == "loop_one"
    play_station("dlna", items[index])

  elif mode == "all"
    index += 1
    if index < n
      playlist["index"] = index
      play_station("dlna", items[index])
    end

  elif mode == "loop_all"
    index = (index + 1) % n
    playlist["index"] = index
    play_station("dlna", items[index])

  elif mode == "shuffle"
    import math
    var new_index = int(math.rand() % n)
    playlist["index"] = new_index
    play_station("dlna", items[new_index])

  end
end

def cmd_setplaylist(cmd, idx, payload, raw)
  var parts = string.split(payload, "||")
  var items = []
  var mode  = "one"
  var index = 0

  for part : parts
    if string.startswith(part, "mode=")
      mode = part[5..]
    elif string.startswith(part, "index=")
      index = int(part[6..])
    elif string.startswith(part, "url=")
      items.push(part[4..])
    end
  end

  if items.size() == 0
    tasmota.resp_cmnd_error()
    return
  end

  playlist = {"items": items, "index": index, "mode": mode}
  print("playlist set: " + str(items.size()) + " items, mode=" + mode + ", index=" + str(index))
  play_station("dlna", items[index])
  tasmota.resp_cmnd_done()
end

def cmd_getplaymode(cmd, idx, payload, raw)
  tasmota.resp_cmnd_str(playlist["mode"])
end

def cmd_setplaymode(cmd, idx, payload, raw)
  var mode = payload
  if mode == "one" || mode == "loop_one" || mode == "all" || mode == "loop_all" || mode == "shuffle"
    playlist["mode"] = mode
    print("play mode set to " + mode)
    tasmota.resp_cmnd_done()
  else
    tasmota.resp_cmnd_error()
  end
end

# --- Fin playlist ---

def ap_mode()
  tasmota.cmd("stop")
  tasmota.cmd("WifiConfig 2")
  tasmota.cmd("Delay 10")
  #tasmota.cmd("DisplayText [z][x5y10] AP mode[x5y20] SSID: T-WebRadio[x5y30] Pass: empty[x5y50] IP:192.168.4.1/wi")
  #tasmota.cmd("displaydimmer 1") 
  tasmota.cmd("backlog color 00ff00; dimmer 100") 
  print("AP mode started")
end

def wifi_connected()
  tasmota.set_timer(3000, 
    def ()
        var ssid = tasmota.wifi()["ssid"]
        #tasmota.cmd("DisplayText [x0y0][u126:64:3][x5y30]" + str(ssid))
        var ip = tasmota.wifi()["ip"]
        #tasmota.cmd("DisplayText [x5y40]" + str(ip) + "[x5y50]/webradio")
        #tasmota.cmd("DisplayText [x5y20]           [x5y20]Vol: " + str(state["level"]))
    end)
  tasmota.cmd("backlog color 0000ff; dimmer 100")
  print("Wifi connected")
end

def set_vol(value)
  tasmota.cmd("I2SGain " + str(value))
  #tasmota.cmd("DisplayText [x5y20]           [x5y20]Vol: " + str(value))
  print("Volume set to " + str(value))
end

def cmd_vol(cmd, idx, payload, raw)
  state["level"] = int(payload)
  if state["level"] >= 0 && state["level"] <= 100
    set_vol(state["level"])
    tasmota.resp_cmnd_done()
  else
    tasmota.resp_cmnd_error()
  end
end


def display_now_playing(title)
   print(str(title))
   tasmota.cmd("DisplayText [x5y10]                           [x5y10]" + str(title) + "[x0y0][u126:64:3]")
end

def cmd_savefav(cmd, idx, payload, raw)
  var parts = string.split(payload, "||")
  print(parts)

  var num = -1
  var name = ""
  var url = ""

  for part : parts
    if string.startswith(part, "num=")
      num = int(part[4..]) - 1
    elif string.startswith(part, "name=")
      name = part[5..]
    elif string.startswith(part, "url=")
      url = part[4..]
    end
  end

  if num >= 0 && num < fav_list.size() && url != ""
    fav_list[num] = {"name": name, "url": url}
    save_data()
    print("fav " + str(num+1) + " saved: " + name)
    tasmota.resp_cmnd_done()
  else
    tasmota.resp_cmnd_error()
  end
end

def cmd_getfav(cmd, idx, payload, raw)
  var result = "["
  for i: 0..fav_list.size()-1
    var s = fav_list[i]
    result += '{"num":' + str(i+1) + ',"name":"' + s["name"] + '","url":"' + s["url"] + '"}'
    if i < fav_list.size()-1
      result += ","
    end
  end
  result += "]"
  tasmota.resp_cmnd_str(result)
end

tasmota.add_cmd("playlast",     play_last)
tasmota.add_cmd("playfav",      cmd_playfav)
tasmota.add_cmd("stop",         cmd_stop)
tasmota.add_cmd("play",         cmd_play)
tasmota.add_cmd("vol",          cmd_vol)
tasmota.add_cmd("playurl",      cmd_playurl)
tasmota.add_cmd("savefav",      cmd_savefav)
tasmota.add_cmd("getfav",       cmd_getfav)
tasmota.add_cmd("setplaylist",  cmd_setplaylist)
tasmota.add_cmd("getplaymode",  cmd_getplaymode)
tasmota.add_cmd("setplaymode",  cmd_setplaymode)

tasmota.add_rule("Event#I2SPlay=Ended", def (value, trigger, msg)
  playlist_next()
end)

#tasmota.add_rule("Switch1#State=3", def (value, trigger, msg)
#  if state["playing"]
#    tasmota.cmd("stop")
#  else
#    tasmota.cmd("play")
#  end
#end)

tasmota.add_rule("Switch1#State=0", def (value, trigger, msg)
  ap_mode()
end)

#tasmota.add_rule("Rotary1#Pos1", def (value, trigger, msg)
#  set_vol(value)
#end)

tasmota.add_rule("Wifi#Connected", def (value, trigger, msg)
  wifi_connected()
end)

tasmota.add_rule("StatusSNS#Audio#Title", def (value, trigger, msg)
  display_now_playing(value)
end)

tasmota.add_cron("*/15 * * * * *", def ()
  tasmota.cmd("Status 8")
end, "refresh_title")

#tasmota.add_rule("System#Boot", def (value, trigger, msg)
#  tasmota.set_timer(10000, def()
#    if !state["playing"]
#      tasmota.cmd("displaydimmer 0")
#    end
#  end)
#end)

load_data()
#tasmota.cmd("DisplayText [z]")
set_vol(state["level"])
tasmota.cmd("backlog color ff0000; dimmer 100")
