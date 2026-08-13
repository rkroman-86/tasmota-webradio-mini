# Installation guide

Complete step-by-step setup for the Tasmota Web Radio Mini
(ESP32-S3 Super Mini + PCM5102A).

The install is done in two stages: flash **stock Tasmota** first with the official
web installer, then **upgrade** to the web radio firmware. You only need a
Chromium-based browser (Chrome / Edge).

---

## Before you start

- An assembled unit (see [`hardware/`](../hardware/)).
- A USB-C cable.
- Chrome or Edge on a computer.
- The files from this repository:
  - `firmware/tasmota32s3superminiwebradio.bin`
  - the `filesystem/` folder
  - the template and commands in `config/`

> The build targets an ESP32-S3 **with PSRAM**. Use it on a Super Mini S3
> that has PSRAM.

---

## Step 1 — Flash stock Tasmota

1. Plug the device into the computer with USB-C.
2. Open the Tasmota web installer: <https://tasmota.github.io/install/>
3. Select **Tasmota (english)** and the ESP32-S3 variant.
4. Click **Connect**, then choose the serial port. On the ESP32-S3 it appears as
   **"USB JTAG/serial debug unit"** (native USB — no serial adapter needed).
5. Enable **Erase device** (recommended on first install), then **Install**.
6. During flashing the USB port may re-enumerate. If you get
   **"Device has been reset to firmware mode. The USB port has changed"**,
   click **Select Port** and pick the port again.

---

## Step 2 — WiFi setup

1. After flashing, the device starts a WiFi access point named `tasmota-xxxx`.
2. Connect to it from a phone or computer.
3. A captive portal opens (at `192.168.4.1`). Enter your WiFi network name and
   password.
4. On success the page shows **Successful WiFi Connection** and redirects to the
   device's new IP on your network. **Note that IP.**

---

## Step 3 — Upgrade to the web radio firmware

1. Open the device web UI at its IP (from Step 2).
2. Go to **Firmware Upgrade -> Use file upload**.
3. Select `firmware/tasmota32s3superminiwebradio.bin`
   (the ~2.2 MB application image).
4. Click **Start upgrade**.
5. The device switches to **SAFEBOOT** to perform the update, shows
   **Upload Successful**, and reboots.

> Seeing **"SAFEBOOT"** in red at this step is **normal** for a firmware this
> size — it is the safe update mechanism, not an error.

---

## Step 4 — Apply the template

The template maps the GPIOs (I2S audio, button, RGB LED). Without it there is
no sound.

1. Open the device web UI (its IP).
2. Go to **Configuration -> Configure Other**.
3. Paste the template from `config/` (the `{"NAME":"Web Radio", ...}` line) into
   the **Template** field.
4. Tick **Activate**. *(Essential — without it the GPIOs are not applied.)*
5. Tick **HTTP API enable** (needed by the web UI).
6. Optionally set a device name and an admin password.
7. Click **Save**. The device reboots and the title becomes **Web Radio**.

---

## Step 5 — One-time parameters

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

## Step 6 — Upload the filesystem

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

## Step 7 — Verify

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

---

## Note on direct factory flashing

A full `factory.bin` is also provided in `firmware/`. In theory it can be flashed
in one step over USB via the installer's **Upload factory.bin** option. This was
unreliable during testing on this build, so the two-step method above is the
recommended and supported path.
