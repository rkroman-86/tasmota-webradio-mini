import webserver
import string

# URL du serveur DLNA découvert dynamiquement
# Fallback hardcodé si la découverte échoue
var dlna_control_url = 'http://192.168.1.1:49153/web/cds_control'

# ----------- Découverte SSDP -----------

def dlna_fetch_control(location)
  var cl = webclient()
  cl.begin(location)
  var code = cl.GET()
  if code != 200
    print("DLNA: description fetch failed: " + str(code))
    cl.close()
    return
  end
  var xml = cl.get_string()
  cl.close()

  # Extraire URLBase
  var base = ""
  var base_pos = string.find(xml, "<URLBase>")
  if base_pos >= 0
    var base_end = string.find(xml, "</URLBase>", base_pos)
    base = xml[base_pos+9..base_end-1]
  else
    # Construire depuis la location
    var p = string.find(location, "/", 7)
    if p >= 0
      base = location[0..p-1]
    else
      base = location
    end
  end

  # Extraire controlURL du ContentDirectory
  var cd_pos = string.find(xml, "ContentDirectory")
  if cd_pos >= 0
    var ctrl_pos = string.find(xml, "<controlURL>", cd_pos)
    if ctrl_pos >= 0
      var ctrl_end = string.find(xml, "</controlURL>", ctrl_pos)
      var ctrl = xml[ctrl_pos+12..ctrl_end-1]
      # Supprimer le slash final de base s'il existe
      if size(base) > 0 && base[size(base)-1..size(base)-1] == "/"
         base = base[0..size(base)-2]
      end
      dlna_control_url = base + ctrl
      print("DLNA: control URL = " + dlna_control_url)
    end
  end
end

def dlna_discover()
  print("DLNA: démarrage découverte SSDP...")
  var sock = udp()
  sock.begin_multicast("239.255.255.250", 1900)

  var msearch = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 3\r\nST: urn:schemas-upnp-org:service:ContentDirectory:1\r\n\r\n"
  sock.send_multicast(bytes().fromstring(msearch))

  tasmota.delay(3000)

  # Lire toutes les réponses disponibles
  var found = false
  var resp = sock.read()
  while resp != nil && !found
    var s = resp.asstring()
    var loc_pos = string.find(s, "LOCATION:")
    if loc_pos < 0
      loc_pos = string.find(s, "location:")
    end
    if loc_pos >= 0
      var loc_end = string.find(s, "\r\n", loc_pos)
      var location = s[loc_pos+9..loc_end-1]
      # Supprimer espaces en début
      while size(location) > 0 && location[0..0] == " "
        location = location[1..]
      end
      print("DLNA: LOCATION = " + location)
      dlna_fetch_control(location)
      if dlna_control_url != ""
        found = true
      end
    end
    resp = sock.read()
  end

  sock.close()

  if found
    print("DLNA: découverte OK -> " + dlna_control_url)
  else
    print("DLNA: aucun serveur trouvé, utilisation du fallback")
  end

  return dlna_control_url
end

# ----------- Routes webserver -----------

# Proxy SOAP -> serveur DLNA
webserver.on('/dlna', def(req, res)
  var body = webserver.arg('plain')
  var cl = webclient()
  cl.begin(dlna_control_url)
  cl.add_header('Content-Type', 'text/xml;charset=utf-8')
  cl.add_header('Soapaction', '"urn:schemas-upnp-org:service:ContentDirectory:1#Browse"')
  cl.add_header('User-Agent', 'Android/15 UPnP/1.0 BubbleUPnP/4.6.3')
  cl.add_header('Connection', 'Keep-Alive')
  cl.add_header('Content-Length', str(size(body)))
  var code = cl.POST(body)
  var result = cl.get_string()
  cl.close()
  webserver.header('Content-Type', 'text/xml')
  webserver.content_response(result)
end)

# Lancer la découverte depuis le navigateur
webserver.on('/dlna/discover', def(req, res)
  dlna_discover()
  webserver.content_response('{"url":"' + dlna_control_url + '"}')
end)

# Lire l'URL courante
webserver.on('/dlna/status', def(req, res)
  webserver.content_response('{"url":"' + dlna_control_url + '"}')
end)

# Lancer la découverte automatiquement au démarrage
tasmota.set_timer(10000, def()
  dlna_discover()
end)