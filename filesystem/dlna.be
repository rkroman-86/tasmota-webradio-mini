import webserver
import string

# =====================================================================
#  DLNA / UPnP ContentDirectory - multi-serveur
#  Decouverte SSDP de tous les serveurs, selection cote UI,
#  proxy SOAP qui route vers le serveur choisi.
# =====================================================================

# Liste des serveurs decouverts : [{"name":..., "url":...}, ...]
var dlna_servers = []

# ---------------------------------------------------------------------
#  Nettoyage d'une valeur (URL / header) : coupe sur \r ou \n,
#  retire espaces en tete et octets non imprimables en fin.
# ---------------------------------------------------------------------
def dlna_clean(str_in)
  var s = str_in
  var cut = size(s)
  var i = 0
  while i < size(s)
    var c = s[i..i]
    if c == "\r" || c == "\n"
      cut = i
      break
    end
    i += 1
  end
  s = s[0..cut-1]
  while size(s) > 0 && s[0..0] == " "
    s = s[1..]
  end
  var sb = bytes().fromstring(s)
  while size(sb) > 0
    var code = sb[size(sb)-1]
    if code < 0x20 || code > 0x7E
      sb = sb[0..size(sb)-2]
    else
      break
    end
  end
  return sb.asstring()
end

# ---------------------------------------------------------------------
#  Extrait "http://host:port" d'une URL de LOCATION.
# ---------------------------------------------------------------------
def dlna_origin(location)
  var p = string.find(location, "/", 7)   # 1er "/" apres "http://"
  if p >= 0
    return location[0..p-1]
  end
  return location
end

# ---------------------------------------------------------------------
#  A partir d'une LOCATION, fetch le descriptif et, s'il contient
#  un service ContentDirectory, ajoute {name, url} a dlna_servers.
# ---------------------------------------------------------------------
def dlna_add_server(location)
  var cl = webclient()
  cl.begin(location)
  var code = cl.GET()
  if code != 200
    cl.close()
    return
  end
  var xml = cl.get_string()
  cl.close()

  # -- friendlyName (nom affiche) --
  var name = location
  var np = string.find(xml, "<friendlyName>")
  if np >= 0
    var ne = string.find(xml, "</friendlyName>", np)
    if ne >= 0
      name = dlna_clean(xml[np+14..ne-1])
    end
  end

  # -- controlURL du ContentDirectory --
  var cd = string.find(xml, "ContentDirectory")
  if cd < 0
    return   # pas de service ContentDirectory sur ce serveur
  end
  var cp = string.find(xml, "<controlURL>", cd)
  if cp < 0
    return
  end
  var ce = string.find(xml, "</controlURL>", cp)
  var ctrl = dlna_clean(xml[cp+12..ce-1])

  # -- resolution absolu / relatif --
  var url
  if string.find(ctrl, "http://") == 0 || string.find(ctrl, "https://") == 0
    url = ctrl
  else
    if size(ctrl) > 0 && ctrl[0..0] != "/"
      ctrl = "/" + ctrl
    end
    url = dlna_origin(location) + ctrl
  end

  # -- eviter les doublons (meme url) --
  for srv : dlna_servers
    if srv["url"] == url
      return
    end
  end

  dlna_servers.push({"name": name, "url": url})
  print("DLNA: serveur + " + name + " -> " + url)
end

# ---------------------------------------------------------------------
#  Decouverte SSDP : collecte TOUS les serveurs ContentDirectory.
# ---------------------------------------------------------------------
def dlna_discover()
  print("DLNA: decouverte SSDP (multi)...")
  dlna_servers = []
  var sock = udp()
  sock.begin_multicast("239.255.255.250", 1900)
  var msearch = "M-SEARCH * HTTP/1.1\r\n"
                "HOST: 239.255.255.250:1900\r\n"
                "MAN: \"ssdp:discover\"\r\n"
                "MX: 3\r\n"
                "ST: urn:schemas-upnp-org:service:ContentDirectory:1\r\n\r\n"
  sock.send_multicast(bytes().fromstring(msearch))
  tasmota.delay(3000)

  # Memoriser les LOCATION deja traitees (les serveurs repondent en double)
  var seen = []
  var resp = sock.read()
  while resp != nil
    var s = resp.asstring()
    var lp = string.find(s, "LOCATION:")
    if lp < 0 lp = string.find(s, "Location:") end
    if lp < 0 lp = string.find(s, "location:") end
    if lp >= 0
      var le = string.find(s, "\r", lp)
      if le < 0 le = string.find(s, "\n", lp) end
      var location = dlna_clean(s[lp+9..le-1])
      var dup = false
      for x : seen
        if x == location dup = true end
      end
      if !dup
        seen.push(location)
        dlna_add_server(location)
      end
    end
    resp = sock.read()
  end
  sock.close()

  print("DLNA: " + str(size(dlna_servers)) + " serveur(s) trouve(s)")
  return dlna_servers
end

# ---------------------------------------------------------------------
#  Construit le JSON de la liste des serveurs.
# ---------------------------------------------------------------------
def dlna_servers_json()
  var j = "["
  var first = true
  for srv : dlna_servers
    if !first j += "," end
    first = false
    # echapper les guillemets du nom
    var nm = string.replace(srv["name"], '"', '\\"')
    j += '{"name":"' + nm + '","url":"' + srv["url"] + '"}'
  end
  j += "]"
  return j
end

# =====================================================================
#  Routes webserver
# =====================================================================

# --- Proxy SOAP : le control URL cible est passe en query (?ctrl=...) ---
webserver.on('/dlna', def(req, res)
  var body = webserver.arg('plain')
  var ctrl = webserver.arg('ctrl')
  if ctrl == nil || size(ctrl) == 0
    # fallback : premier serveur connu
    if size(dlna_servers) > 0
      ctrl = dlna_servers[0]["url"]
    else
      webserver.content_response('<error>no server</error>')
      return
    end
  end
  var cl = webclient()
  cl.begin(ctrl)
  cl.add_header('Content-Type', 'text/xml; charset="utf-8"')
  cl.add_header('SOAPACTION', '"urn:schemas-upnp-org:service:ContentDirectory:1#Browse"')
  cl.add_header('User-Agent', 'Android/15 UPnP/1.0 BubbleUPnP/4.6.3')
  cl.add_header('Connection', 'Keep-Alive')
  cl.add_header('Content-Length', str(size(body)))
  var code = cl.POST(body)
  var result = cl.get_string()
  cl.close()
  print("DLNA proxy: code=" + str(code) + " taille=" + str(size(result)))
  webserver.header('Content-Type', 'text/xml')
  webserver.content_response(result)
end)

# --- Lancer la decouverte ---
webserver.on('/dlna/discover', def(req, res)
  dlna_discover()
  webserver.content_response(dlna_servers_json())
end)

# --- Lire la liste courante sans relancer la decouverte ---
webserver.on('/dlna/servers', def(req, res)
  webserver.content_response(dlna_servers_json())
end)

# --- Decouverte auto 10 s apres le demarrage ---
tasmota.set_timer(10000, def()
  dlna_discover()
end)
