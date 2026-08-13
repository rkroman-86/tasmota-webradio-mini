# Wiring

## I2S audio (ESP32-S3 Super Mini → PCM5102A)

| ESP32-S3 GPIO | PCM5102A pin | Signal |
|---------------|--------------|--------|
| GPIO10 | BCK  | I2S bit clock |
| GPIO9  | DIN  | I2S data |
| GPIO8  | LRCK | I2S word select (L/R clock) |
| —      | SCK  | Not connected (internal PLL) |

## Power

| Source | Destination | Notes |
|--------|-------------|-------|
| 5 V (Super Mini) | PCM5102A VIN | DAC has an onboard 3.3 V regulator for AVCC |
| GND | PCM5102A GND | Common ground |

## PCM5102A configuration strap

| Strap | Purpose |
|-------|---------|
| A3V3 → XSMT | Hardware un-mute (DAC always active, frees one GPIO) |

## Other I/O (on the ESP32-S3 Super Mini)

| GPIO | Function | Notes |
|------|----------|-------|
| GPIO0  | Button (BOOT) | Triggers WiFi AP config mode |
| GPIO48 | WS2812 RGB LED (onboard) | Status: red = boot, blue = WiFi connected, green = AP mode |

## Notes
- SCK is left unconnected: the PCM5102A generates its system clock internally.
- Audio output is taken from the 3.5 mm jack (line / headphone level).
- Power is supplied over USB-C (5 V).
