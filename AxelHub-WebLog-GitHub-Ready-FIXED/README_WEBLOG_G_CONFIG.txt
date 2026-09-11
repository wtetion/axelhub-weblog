AXEL WEB LOG GLOBAL CONFIG
===========================

The script now exposes a mutable global config through both:

    getgenv().AxelWebLogConfig
    _G.AxelWebLogConfig

Example (put this BEFORE loading the Axel script):

getgenv().AxelWebLogConfig = {
    Enabled = true,
    URL = "https://your-domain.example/api/telemetry",
    Key = "axel_your_personal_telemetry_key",
    Interval = 5,
    Debug = false,
    LocalFallback = true,
}

Fields:
- Enabled        : true/false, turns telemetry on/off without changing the rest of the script.
- URL            : POST endpoint, normally your /api/telemetry URL.
- Key            : private telemetry token from Axel WebLog.
- Interval       : telemetry send interval in seconds (minimum 1).
- Debug          : true to print missing-key diagnostics.
- LocalFallback  : true to retry localhost:3000 when the main endpoint fails.

Runtime editing is supported because the sender reads the config on each cycle.
Examples:

getgenv().AxelWebLogConfig.Enabled = false
getgenv().AxelWebLogConfig.Interval = 10
getgenv().AxelWebLogConfig.URL = "https://example.com/api/telemetry"

The API table also exposes:

_G.AxelWebLog.GetConfig()
_G.AxelWebLog.SetConfig("Enabled", false)

Legacy variables AXEL_WEBLOG_URL / AXEL_WEBLOG_KEY remain accepted for compatibility.
