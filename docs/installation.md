# Installation guide

Complete step-by-step setup for the Tasmota Web Radio Mini
(ESP32-S3 Super Mini + PCM5102A).

There are two ways to flash: **Method A** (direct, recommended) flashes the
web radio firmware in one step. **Method B** (two-step) installs stock Tasmota
first, then upgrades to the web radio firmware. Both use the official Tasmota
web installer and only require a Chromium-based browser (Chrome / Edge).

---

## Before you start

- An assembled unit (see [`hardware/`](../hardware/)).
- A USB-C cable.
- Chrome or Edge on a computer.
- The files from this repository:
  - `firmware/tasmota32s3superminiwebradio.factory.bin`
  - `firmware/tasmota32s3superminiwebradio.bin`
  - the `filesystem/` folder
  - the template and commands in `config/`

> The build targets an ESP32-S3 **with PSRAM**. Use it on a Super Mini S3
> that has PSRAM.

---

## Method A — Direct flash (recommended)

One step: flash the full web radio image over USB.

1. Plug the device into the computer with USB-C.
2. Open the Tasmota web installer: <https://tasmota.github.io/install/>
3. Scroll to the bottom and use **Upload factory.bin** (drag & drop or file dialog).
4. Select `firmware/tasmota32s3superminiwebradio.factory.bin`.
5. Click **Connect**, then choose the serial port. On the ESP32-S3 it appears as
   **"USB JTAG/serial debug unit"** (native USB — no adapter needed).
6. Confirm the erase/flash. Wait until it completes.

When done, continue at **[WiFi setup](#wifi-setup)** below.

> If the direct method fails for any reason, use Method B instead.

---

## Method B — Two-step (fallback)

### B.1 Flash stock Tasmota

1. Plug in the device (USB-C).
2. Open <https://tasmota.github.io/install/>.
3. Select **Tasmota (english)** and the ESP32-S3 variant.
4. Click **Connect**, choose the **USB JTAG/serial debug unit** port.
5. Enable **Erase device** on first install, then **Install**.
6. During flashing the USB port may re-enumerate. If prompted with
   **"Device has been reset to firmware mode. The USB port has changed"**,
   click **Select Port** and pick the port again.

### B.2 Upgrade to the web radio firmware

1. Complete **[WiFi setup](#wifi-setup)** first (so the device is on your network).
2. Open the device web UI at its IP.
3. Go to **Firmware Upgrade -> Use file upload**.
4. Select `firmware/tasmota32s3superminiwebradio.bin`
   (the ~2.2 MB application image — **not** the factory image).
5. Click **Start upgrade**.
6. The device switches to **SAFEBOOT** to update, shows **Upload Successful**,
   and reboots. Seeing "SAFEBOOT" in red here is normal for a firmware this size.

---

## WiFi setup

1. After flashing, the device starts a WiFi access point named `tasmota-xxxx`.
2. Connect to it from a phone or computer.
3. A captive portal opens (at `192.168.4.1`). Enter your WiFi network name and
   password.
4. On success the page shows **Successful WiFi Connection** and redirects to the
   device's new IP on your network. Note that IP.

---

## Apply the template

The template maps the GPIOs (I2S audio, button, RGB LED). Without it there is
no sound.

1. Open the device web UI (its IP).
2. Go to **Configuration -> Configure Other**.
3. Paste the template from `config/` (the `{"NAME":"Web Radio", ...}` line) into
   the **Template** field.
4. Tick **Activate**. *(This is essential — without it the GPIOs are not applied.)*
5. Tick **HTTP API enable** (needed by the web UI).
6. Optionally set a device name and an admin password.
7. Click **Save**. The device reboots and the title becomes **Web Radio**.

---

## One-time parameters

In **Tools -> Console**, run (all at once):

```
Backlog SwitchMode1 1; SetOption55 1; Hostname webradio1
```

Or one by one:

```
SwitchMode1 1
SetOption55 1
Hostname webradio1
```

- `SwitchMode1 1` — button behaviour
- `SetOption55 1` — enable mDNS (so `webradio1.local` works)
- `Hostname webradio1` — device network name

The device reboots automatically after applying these. It is then reachable at
`webradio1.local`.

---

## Upload the filesystem

The Berry scripts and the web UI live on the device filesystem. Copy them from
the `filesystem/` folder of this repository, **keeping the same structure**,
including the `webradio/` subfolder.

Go to **Tools -> Manage File system**, then upload each file.

Root level:
- `autoexec.be`
- `main_prog.be`
- `dlna.be`
- `webradio_ui.be`
- `_persist.json` (ships with a few example favorites)

In the `webradio/` subfolder:
- `webradio/index.htm`
- `webradio/app.js`
- `webradio/style.css`
- `webradio/ui.be`

> To create the `webradio/` subfolder, include the path in the file name when
> uploading / creating (e.g. `webradio/index.htm`). Tasmota creates the folder
> automatically.

Files are kept individual (not packed into a `.tapp`) so you can edit the UI and
Berry scripts directly from the file manager later.

After uploading everything, reboot the device (**Restart**, or `Restart 1` in
the console).

---

## Verify

1. Open **Tools -> Console** and check the boot log:
   - `Module: Web Radio`
   - `I2S: config loaded ...`
   - `WebRadio: UI enabled`
   - `Web server active on webradio1.local`
   - Berry scripts load without errors.
2. Open `http://webradio1.local/webradio` in a browser.
3. Play a station and confirm audio from the 3.5 mm jack.

The RGB LED indicates state: **red** at boot, **blue** when WiFi is connected,
**green** in AP config mode.

---

## Troubleshooting

- **No sound:** make sure the template is applied **and Activate was ticked**.
- **Web UI empty / missing:** verify the `webradio/` files were uploaded into the
  `webradio/` subfolder (not at the root).
- **Not reachable by name:** confirm `SetOption55 1` and the hostname were set;
  use the raw IP otherwise.
- **Direct factory flash failed:** use Method B (stock Tasmota, then OTA upgrade).
