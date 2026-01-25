## How to Configure the Keyboard Shortcut in XFCE

**1. Open Keyboard Settings**
* Open the **Application Menu** (Mouse icon in the top-left corner).
* Go to **Settings** → **Keyboard**.

**2. Add a New Shortcut**
* Switch to the **Application Shortcuts** tab.
* Click the **Add** button at the bottom.

**3. Select the Script**
* In the **Command** field, do not type manually to avoid errors. Instead:
    1.  Click the **Folder Icon** (Browse) on the right side of the text box.
    2.  Navigate to your **Home** folder.
    3.  Open the folder `voice-typer`.
    4.  Select the file `trigger.sh` and click **Open**.
* *Alternatively, if you want to type the path manually, replace `YOUR_USERNAME` with your actual user:*
    `/home/YOUR_USERNAME/voice-typer/trigger.sh`
* Click **OK**.

**4. Assign the Key**
* A popup window saying **"Command Shortcut"** will appear.
* Press the key you want to use (e.g., **F8** or **Ctrl+Space**).

**5. Test It**
* Open a **Terminal**.
* Press your hotkey (you should hear a beep).
* Speak a phrase.
* Press the hotkey again (second beep).
* The text should appear automatically.