# Kibana ICMP Bulk Monitor Creator

A professional PowerShell script to bulk-create ICMP monitors in Kibana Synthetics. It reads a simple text file containing targets and provisions them via the Kibana API.

Compatible with **Windows PowerShell 5.1** and **PowerShell 7+**.

---

## ✨ Features

*   **Bulk Creation:** Add hundreds of ICMP monitors in seconds.
*   **Fully Dynamic Configuration:** No hardcoded values. If the Kibana URL, API Key, or Private Location are not provided via switches, the script will securely prompt you for them.
*   **Smart URL Handling:** Automatically fixes missing protocols (`https://`) and strips unnecessary paths if you paste a full Kibana dashboard URL.
*   **Advanced Settings:** Supports custom schedules, timeouts, labels, namespaces, and multiple tags.
*   **Safe & Secure:** Credentials are kept strictly in memory. Nothing is saved to disk or sent to third-party servers.
*   **Detailed Logging:** Displays the exact settings for each monitor before creation and reports `SUCCESS`, `SKIPPED`, or `FAILED` clearly.

---

## 📋 Prerequisites

Before running the script, ensure you have:

1.  **Kibana Instance:** Access to a Kibana server with **Synthetics** enabled.
2.  **API Key:** A valid Kibana API Key with permissions to create Synthetics monitors. You can generate one from **Kibana → Stack Management → API Keys**.
3.  **Private Location:** The name of your configured Private Location (e.g., `My-Datacenter`). You can find your locations under **Observability → Synthetics → Settings → Private Locations**.
4.  **PowerShell:** Windows PowerShell 5.1 (built-in) or PowerShell 7+.

---

## 📥 Download

You can download the script directly from the repository:

1.  Navigate to the `synthetics-monitor` folder.
2.  Click on `icmp-creator.ps1`.
3.  Click the **Raw** button and save the file (e.g., right-click → Save as) to a folder on your computer.

Alternatively, clone the entire repository:

```bash
git clone https://github.com/mehrazino/kibana-bulk-creator.git
```

---

## 🚀 Quick Start

### Step 1: Create Your List File

Create a new text file (e.g., `my_targets.txt`) in the same folder as the script. Add one monitor per line using the following format:

```text
IP|Name|Tag1,Tag2
```

**Example:**

```text
10.0.0.1|server-alpha - windows - 10.0.0.1|Windows
10.0.0.2|core-router - cisco-ios - 10.0.0.2|CiscoRS
10.0.0.3|fw-edge - fortigate - 10.0.0.3|Firewall,Edge
```

> **Note:** Tags are optional. If you do not need tags, you can leave the third part empty (e.g., `10.0.0.5|linux-server - 10.0.0.5|`).

### Step 2: Open PowerShell in the Script Folder

1.  Open the folder containing `icmp-creator.ps1` and your `.txt` file.
2.  Click on the **address bar** at the top of the folder window.
3.  Type `powershell` and press **Enter**. A PowerShell window will open in that directory.

### Step 3: (Optional) Bypass Execution Policy Temporarily

If you encounter an "Execution Policy" error, run the following command once in that PowerShell window:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

> **Security Note:** This only affects the current PowerShell session. As soon as you close the window, the policy reverts to its original state. Your system-wide settings are not changed.

### Step 4: Run the Script

Execute the script by pointing it to your list file:

```powershell
.\icmp-creator.ps1 -f .\my_targets.txt
```

The script will interactively prompt you for any missing information:
*   **Kibana URL** (e.g., `https://kibana.example.com:5601`)
*   **API Key**
*   **Private Location Name**

You can also provide these upfront using the `-k`, `-a`, and `-l` switches to skip the prompts:

```powershell
.\icmp-creator.ps1 -f .\my_targets.txt -k "https://kibana.example.com:5601" -a "your-api-key" -l "My-Datacenter"
```

---

## ⚙️ Script Parameters

The script accepts the following optional parameters to fine-tune each monitor. If omitted, the default values (as defined by the Kibana API) are used.

| Switch | Description | Default |
| :--- | :--- | :--- |
| `-f` | **(Required)** Path to the text file containing targets. | — |
| `-k` | Kibana URL. | (Prompt) |
| `-a` | Kibana API Key. | (Prompt) |
| `-l` | Name of the Private Location. | (Prompt) |
| `-s` | Schedule interval in minutes. Allowed: `1, 3, 5, 10, 15, 30, 60, 120, 240`. | `3` |
| `-t` | Timeout in seconds. | `16` |
| `-e` | Enable or disable the monitor (`true` / `false`). | `true` |
| `-n` | Namespace for the data stream. | `default` |
| `-lbl` | Labels in `key:value,key2:value2` format. | (None) |
| `-al` | Enable status alerts (`true` / `false`). | `true` |
| `-re` | Retest on failure (`true` / `false`). | `true` |
| `-h` or `--help` | Display the help menu. | — |

### Example with Advanced Settings

```powershell
.\icmp-creator.ps1 -f .\my_targets.txt -s 5 -t 30 -lbl "env:prod,team:network" -l "My-Datacenter"
```

This command creates monitors with a 5-minute schedule, a 30-second timeout, adds labels `env:prod` and `team:network`, and assigns them to the `My-Datacenter` location.

---

## 🛠️ Troubleshooting

| Issue | Solution |
| :--- | :--- |
| **"Execution Policy" error** | Run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` before executing the script. |
| **"The URI prefix is not recognized"** | Ensure the Kibana URL includes `https://`. The script attempts to fix this automatically, but double-check the input. |
| **"FAILED" with an authorization error** | Verify that your API Key is correct and has the necessary permissions for Synthetics. |
| **"SKIPPED (Already exists)"** | A monitor with the same name already exists. The script will skip it and continue with the next one. |
| **"FAILED" with a timeout error** | The Kibana server may be unreachable. Check your network connection and the URL. |
| **"FAILED" with a location error** | Ensure the Private Location name exactly matches what is configured in your Kibana instance. |

---

## 🔒 Security Notice

This script is designed with security in mind:

*   The **Kibana URL**, **API Key**, and **Private Location** are used **strictly in-memory** for the current session.
*   They are **not** saved to disk, logged to any file, or sent to any third-party servers.
*   Once the PowerShell window is closed, these credentials are forgotten.

Please ensure you run this script in a trusted environment and avoid sharing your API Key in plain text.

---

## 🤝 Contributing

Contributions are welcome! If you have suggestions for improvements or encounter any issues, please open an issue or submit a pull request.
