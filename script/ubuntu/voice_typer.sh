#!/bin/bash

# ==========================================
# Voice Typer Installer (Ultimate Version)
# ==========================================
# 1. Compiles ydotool from source (Fixes Ubuntu 24.04 daemon).
# 2. Uses 'Double Paste' strategy (Ctrl+Shift+V + Ctrl+V) to work everywhere.
# 3. Pre-downloads Whisper 'small' model.
# 4. Sets up auto-start services and F8 shortcut.

set -e # Exit on error

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}>>> 1. STOPPING OLD PROCESSES...${NC}"
systemctl --user stop voice-typer || true
systemctl --user stop ydotoold || true

echo -e "${BLUE}>>> 2. INSTALLING DEPENDENCIES...${NC}"
sudo apt update
sudo apt install -y python3-venv python3-pip portaudio19-dev git curl \
    build-essential cmake pkg-config scdoc libevdev-dev wl-clipboard \
    xdotool wmctrl wtype


# --- BUILDING YDOTOOL ---
# Check if our self-built daemon is installed. If not - build it.
if ! command -v ydotoold &> /dev/null; then
    echo -e "${BLUE}>>> Building ydotool from source...${NC}"
    BUILD_DIR="/tmp/voice_typer_build_final"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    build_git() {
        URL=$1
        NAME=$2
        echo -e "${BLUE}>>> Downloading $NAME...${NC}"
        cd "$BUILD_DIR"
        rm -rf "$NAME"
        git clone "$URL" "$NAME"
        cd "$NAME"
        mkdir -p build && cd build
        cmake .. -DCMAKE_INSTALL_PREFIX=/usr
        make
        sudo make install
    }

    build_git "https://github.com/YukiWorkshop/libevdevPlus.git" "libevdevPlus"
    build_git "https://github.com/YukiWorkshop/libuInputPlus.git" "libuInputPlus"
    build_git "https://github.com/ReimuNotMoe/ydotool.git" "ydotool"

    rm -rf "$BUILD_DIR"
    sudo ldconfig
    echo -e "${GREEN}>>> ydotool successfully built!${NC}"
fi

# --- ACCESS RIGHTS ---
echo -e "${BLUE}>>> Setting up udev permissions...${NC}"
echo 'KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/80-uinput.rules > /dev/null
echo 'SUBSYSTEM=="input", GROUP="input", MODE="0664"' | sudo tee -a /etc/udev/rules.d/80-uinput.rules > /dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger

# Add user to input group
sudo usermod -aG input $USER

# Load uinput module and set permissions
sudo modprobe uinput
sudo chmod 666 /dev/uinput

# Create a script to set permissions on boot
sudo tee /etc/systemd/system/uinput-permissions.service > /dev/null << 'EOF'
[Unit]
Description=Set uinput permissions
After=systemd-udev-settle.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'modprobe uinput && chmod 666 /dev/uinput'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable uinput-permissions.service
sudo systemctl start uinput-permissions.service

# --- CREATING ENVIRONMENT ---
PROJECT_DIR="$HOME/voice-typer"
echo -e "${BLUE}>>> Setting up folder ${PROJECT_DIR}...${NC}"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

echo -e "${BLUE}>>> Installing Python libraries...${NC}"
source venv/bin/activate
pip install --upgrade pip
pip install faster-whisper sounddevice numpy scipy

# --- MODEL PRELOADING ---
echo -e "${BLUE}>>> DOWNLOADING 'small' MODEL ...${NC}"
echo -e "${BLUE}>>> This is needed to make the first run fast.${NC}"
cat << 'EOF' > download_model.py
from faster_whisper import WhisperModel
print("--- Start Download ---")
model = WhisperModel("small", device="cpu", compute_type="int8")
print("--- Download Complete ---")
EOF
python download_model.py
rm download_model.py

# --- PROGRAM GENERATION ---
echo -e "${BLUE}>>> Creating main_wayland.py (Double Paste Logic)...${NC}"
cat << 'EOF' > main_wayland.py
import sys
import os
import signal
import time
import subprocess
import sounddevice as sd
import numpy as np
from scipy.io.wavfile import write
from faster_whisper import WhisperModel

MODEL_SIZE = "small"
COMPUTE_TYPE = "int8"
SAMPLE_RATE = 16000
TEMP_AUDIO_FILE = "/tmp/voice_input.wav"

class VoiceTyper:
    def __init__(self):
        self.model = None
        self.recording = False
        self.audio_data = []
        self.stream = None

    def load_model(self):
        print(f"Initializing model ({MODEL_SIZE})...")
        try:
            self.model = WhisperModel(MODEL_SIZE, device="cpu", compute_type=COMPUTE_TYPE)
            print(f"✅ Ready! PID: {os.getpid()}")
        except Exception as e:
            print(f"Loading error: {e}")

    def toggle_recording(self):
        if not self.model:
            print("⚠️ Model is still loading, please wait...")
            return
        if self.recording:
            self.stop_recording()
        else:
            self.start_recording()

    def start_recording(self):
        print("--- 🔴 RECORDING ---")
        self.recording = True
        self.audio_data = []
        self.stream = sd.InputStream(samplerate=SAMPLE_RATE, channels=1, callback=self.audio_callback)
        self.stream.start()

    def stop_recording(self):
        print("--- ⏹️ STOP ---")
        self.recording = False
        if self.stream:
            self.stream.stop()
            self.stream.close()

        if not self.audio_data:
            return

        my_recording = np.concatenate(self.audio_data, axis=0)
        my_recording = (my_recording * 32767).astype(np.int16)
        write(TEMP_AUDIO_FILE, SAMPLE_RATE, my_recording)

        segments, info = self.model.transcribe(TEMP_AUDIO_FILE, beam_size=1)
        text = " ".join([segment.text for segment in segments]).strip()
        print(f"Recognized ({info.language}): '{text}'")

        if text:
            self.paste_text(text)

    def audio_callback(self, indata, frames, time, status):
        if self.recording:
            self.audio_data.append(indata.copy())

    def paste_text(self, text):
        """
        Smart paste method with Wayland compatibility:
        1. Copies text to clipboard.
        2. Uses wtype for Wayland or ydotool for X11.
        3. Detects active window and uses appropriate paste command.
        """
        try:
            # 1. Copy to clipboard
            subprocess.run(["wl-copy", text], check=True)
            time.sleep(0.1) # Longer pause for clipboard in Wayland

            # 2. Check if we're in Wayland
            if self.is_wayland():
                print("DEBUG: Using Wayland method")
                self.paste_wayland(text)
            else:
                print("DEBUG: Using X11 method")
                self.paste_x11(text)

        except Exception as e:
            print(f"Paste error: {e}")
            # Ultimate fallback: try typing the text directly
            self.fallback_type_text(text)

    def is_wayland(self):
        """Check if we're running in Wayland"""
        return os.environ.get('WAYLAND_DISPLAY') is not None or os.environ.get('XDG_SESSION_TYPE') == 'wayland'

    def paste_wayland(self, text):
        """Paste using wtype for Wayland with ydotool fallback"""
        try:
            # First try wtype if available
            subprocess.run(["which", "wtype"], check=True, capture_output=True)
            
            # Detect if terminal is active
            is_terminal = self.is_terminal_active()
            
            if is_terminal:
                # For terminal: use Ctrl+Shift+V
                subprocess.run(["wtype", "-M", "ctrl", "-M", "shift", "v"], check=True)
                print("--- PASTED (Wayland Terminal: Ctrl+Shift+V) ---")
            else:
                # For GUI: use Ctrl+V
                subprocess.run(["wtype", "-M", "ctrl", "v"], check=True)
                print("--- PASTED (Wayland GUI: Ctrl+V) ---")
                
        except subprocess.CalledProcessError:
            print("wtype not available, trying ydotool fallback...")
            # Fallback to ydotool even in Wayland
            try:
                env = os.environ.copy()
                env["YDOTOOL_SOCKET"] = "/tmp/.ydotool_socket"
                
                is_terminal = self.is_terminal_active()
                
                if is_terminal:
                    # Terminal: use Ctrl+Shift+V
                    subprocess.run(["ydotool", "key", "29:1", "42:1", "47:1", "47:0", "42:0", "29:0"], env=env, check=True)
                    print("--- PASTED (Wayland+ydotool Terminal: Ctrl+Shift+V) ---")
                else:
                    # GUI applications: use Ctrl+V
                    subprocess.run(["ydotool", "key", "29:1", "47:1", "47:0", "29:0"], env=env, check=True)
                    print("--- PASTED (Wayland+ydotool GUI: Ctrl+V) ---")
                    
            except Exception as ydotool_error:
                print(f"ydotool fallback failed: {ydotool_error}")
                self.fallback_type_text(text)
                
        except Exception as e:
            print(f"Wayland paste error: {e}")
            self.fallback_type_text(text)

    def paste_x11(self, text):
        """Paste using ydotool for X11"""
        try:
            env = os.environ.copy()
            env["YDOTOOL_SOCKET"] = "/tmp/.ydotool_socket"

            # Detect active window
            is_terminal = self.is_terminal_active()
            
            if is_terminal:
                # Terminal: use Ctrl+Shift+V
                subprocess.run(["ydotool", "key", "29:1", "42:1", "47:1", "47:0", "42:0", "29:0"], env=env, check=True)
                print("--- PASTED (X11 Terminal: Ctrl+Shift+V) ---")
            else:
                # GUI applications: use Ctrl+V
                subprocess.run(["ydotool", "key", "29:1", "47:1", "47:0", "29:0"], env=env, check=True)
                print("--- PASTED (X11 GUI: Ctrl+V) ---")

        except Exception as e:
            print(f"X11 paste error: {e}")
            self.fallback_type_text(text)

    def paste_wayland(self, text):
        """Paste using wtype for Wayland with ydotool fallback"""
        try:
            # First try wtype if available
            subprocess.run(["which", "wtype"], check=True, capture_output=True)
            
            # Detect if terminal is active
            is_terminal = self.is_terminal_active()
            
            if is_terminal:
                # For terminal: use Ctrl+Shift+V
                subprocess.run(["wtype", "-M", "ctrl", "-M", "shift", "v"], check=True)
                print("--- PASTED (Wayland Terminal: Ctrl+Shift+V) ---")
            else:
                # For GUI: use Ctrl+V
                subprocess.run(["wtype", "-M", "ctrl", "v"], check=True)
                print("--- PASTED (Wayland GUI: Ctrl+V) ---")
                
        except subprocess.CalledProcessError:
            print("wtype not available, trying ydotool fallback...")
            # Fallback to ydotool even in Wayland
            try:
                env = os.environ.copy()
                env["YDOTOOL_SOCKET"] = "/tmp/.ydotool_socket"
                
                is_terminal = self.is_terminal_active()
                
                if is_terminal:
                    # Terminal: use Ctrl+Shift+V
                    subprocess.run(["ydotool", "key", "29:1", "42:1", "47:1", "47:0", "42:0", "29:0"], env=env, check=True)
                    print("--- PASTED (Wayland+ydotool Terminal: Ctrl+Shift+V) ---")
                else:
                    # GUI applications: use Ctrl+V
                    subprocess.run(["ydotool", "key", "29:1", "47:1", "47:0", "29:0"], env=env, check=True)
                    print("--- PASTED (Wayland+ydotool GUI: Ctrl+V) ---")
                    
            except Exception as ydotool_error:
                print(f"ydotool fallback failed: {ydotool_error}")
                self.fallback_type_text(text)
                
        except Exception as e:
            print(f"Wayland paste error: {e}")
            self.fallback_type_text(text)

    def paste_x11(self, text):
        """Paste using ydotool for X11"""
        try:
            env = os.environ.copy()
            env["YDOTOOL_SOCKET"] = "/tmp/.ydotool_socket"

            # Detect active window
            is_terminal = self.is_terminal_active()
            
            if is_terminal:
                # Terminal: use Ctrl+Shift+V
                subprocess.run(["ydotool", "key", "29:1", "42:1", "47:1", "47:0", "42:0", "29:0"], env=env, check=True)
                print("--- PASTED (X11 Terminal: Ctrl+Shift+V) ---")
            else:
                # GUI applications: use Ctrl+V
                subprocess.run(["ydotool", "key", "29:1", "47:1", "47:0", "29:0"], env=env, check=True)
                print("--- PASTED (X11 GUI: Ctrl+V) ---")

        except Exception as e:
            print(f"X11 paste error: {e}")
            self.fallback_type_text(text)



    def fallback_type_text(self, text):
        """Fallback: type text directly"""
        try:
            print("Using fallback: typing text directly")
            
            # Try ydotool direct typing first (works in both X11 and Wayland)
            env = os.environ.copy()
            env["YDOTOOL_SOCKET"] = "/tmp/.ydotool_socket"
            subprocess.run(["ydotool", "type", text], env=env, check=True)
            print("--- TYPED (ydotool direct) ---")
            
        except Exception as ydotool_error:
            print(f"ydotool typing failed: {ydotool_error}")
            
            # Try wtype direct typing as last resort
            try:
                subprocess.run(["wtype", text], check=True)
                print("--- TYPED (wtype direct) ---")
            except Exception as wtype_error:
                print(f"wtype typing failed: {wtype_error}")
                print("All methods failed. Text is in clipboard - paste manually with Ctrl+V or Ctrl+Shift+V")

    def is_terminal_active(self):
        """
        Check if the active window is a terminal application.
        Works in both X11 and Wayland environments.
        """
        window_name = ""
        window_class = ""
        
        # For Wayland, we need different approach
        if self.is_wayland():
            return self.is_terminal_wayland()
        
        try:
            # Method 1: Get active window info using xdotool (works in X11)
            result = subprocess.run(["xdotool", "getactivewindow", "getwindowname"], 
                                  capture_output=True, text=True, timeout=1)
            if result.returncode == 0:
                window_name = result.stdout.strip().lower()
                print(f"DEBUG: Window name: '{window_name}'")
            
            # Get window class as well
            result = subprocess.run(["xdotool", "getactivewindow", "getwindowclassname"], 
                                  capture_output=True, text=True, timeout=1)
            if result.returncode == 0:
                window_class = result.stdout.strip().lower()
                print(f"DEBUG: Window class: '{window_class}'")
        except Exception as e:
            print(f"DEBUG: xdotool error: {e}")
        
        # Extended list of terminal identifiers
        terminal_keywords = [
            'terminal', 'konsole', 'gnome-terminal', 'xterm', 'alacritty', 
            'kitty', 'tilix', 'terminator', 'urxvt', 'rxvt', 'st', 'foot',
            'wezterm', 'hyper', 'iterm', 'qterminal', 'lxterminal',
            'mate-terminal', 'xfce4-terminal', 'terminology'
        ]
        
        # Check both window name and class
        for keyword in terminal_keywords:
            if keyword in window_name or keyword in window_class:
                print(f"DEBUG: Terminal detected via keyword: '{keyword}'")
                return True
        
        try:
            # Method 2: Check using wmctrl for active window
            result = subprocess.run(["wmctrl", "-l", "-p"], capture_output=True, text=True, timeout=1)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                # Get active window ID
                active_result = subprocess.run(["xdotool", "getactivewindow"], 
                                             capture_output=True, text=True, timeout=1)
                if active_result.returncode == 0:
                    active_id = active_result.stdout.strip()
                    # Convert to hex format that wmctrl uses
                    active_hex = hex(int(active_id))[2:].upper().zfill(8)
                    
                    for line in lines:
                        if active_hex in line.upper():
                            line_lower = line.lower()
                            for keyword in terminal_keywords:
                                if keyword in line_lower:
                                    print(f"DEBUG: Terminal detected via wmctrl: '{keyword}' in '{line}'")
                                    return True
        except Exception as e:
            print(f"DEBUG: wmctrl error: {e}")
        
        try:
            # Method 3: Check process name of active window
            result = subprocess.run(["xdotool", "getactivewindow", "getwindowpid"], 
                                  capture_output=True, text=True, timeout=1)
            if result.returncode == 0:
                pid = result.stdout.strip()
                proc_result = subprocess.run(["ps", "-p", pid, "-o", "comm="], 
                                           capture_output=True, text=True, timeout=1)
                if proc_result.returncode == 0:
                    process_name = proc_result.stdout.strip().lower()
                    print(f"DEBUG: Process name: '{process_name}'")
                    for keyword in terminal_keywords:
                        if keyword in process_name:
                            print(f"DEBUG: Terminal detected via process: '{keyword}'")
                            return True
        except Exception as e:
            print(f"DEBUG: Process check error: {e}")
        
        print("DEBUG: No terminal detected, assuming GUI application")
        return False

    def is_terminal_wayland(self):
        """
        Check if terminal is active in Wayland.
        Uses process inspection and environment variables.
        """
        try:
            # Check if we're running inside a terminal by looking at parent processes
            current_pid = os.getpid()
            
            # Get process tree
            result = subprocess.run(["ps", "-eo", "pid,ppid,comm"], 
                                  capture_output=True, text=True, timeout=2)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')[1:]  # Skip header
                
                # Build process tree
                processes = {}
                for line in lines:
                    parts = line.strip().split()
                    if len(parts) >= 3:
                        pid, ppid, comm = parts[0], parts[1], ' '.join(parts[2:])
                        processes[pid] = {'ppid': ppid, 'comm': comm.lower()}
                
                # Walk up the process tree from current process
                check_pid = str(current_pid)
                depth = 0
                while check_pid in processes and depth < 10:
                    process = processes[check_pid]
                    comm = process['comm']
                    print(f"DEBUG: Checking parent process: {comm}")
                    
                    terminal_keywords = [
                        'terminal', 'konsole', 'gnome-terminal', 'xterm', 'alacritty', 
                        'kitty', 'tilix', 'terminator', 'urxvt', 'rxvt', 'st', 'foot',
                        'wezterm', 'hyper', 'qterminal', 'lxterminal',
                        'mate-terminal', 'xfce4-terminal', 'terminology'
                    ]
                    
                    for keyword in terminal_keywords:
                        if keyword in comm:
                            print(f"DEBUG: Terminal detected in Wayland via parent process: '{keyword}'")
                            return True
                    
                    check_pid = process['ppid']
                    depth += 1
        except Exception as e:
            print(f"DEBUG: Wayland terminal detection error: {e}")
        
        # Fallback: check environment variables
        term_env = os.environ.get('TERM', '').lower()
        if term_env and term_env != 'dumb':
            print(f"DEBUG: Terminal detected via TERM env: '{term_env}'")
            return True
        
        print("DEBUG: No terminal detected in Wayland, assuming GUI application")
        return False

typer = VoiceTyper()

def signal_handler(sig, frame):
    typer.toggle_recording()

if __name__ == "__main__":
    # First set up the handler so F8 doesn't kill the process at startup
    signal.signal(signal.SIGUSR1, signal_handler)
    # Then load the model
    typer.load_model()

    while True:
        time.sleep(1)
EOF

# --- SYSTEMD SERVICES ---
echo -e "${BLUE}>>> Setting up systemd...${NC}"
mkdir -p ~/.config/systemd/user

# ydotool daemon
cat << EOF > ~/.config/systemd/user/ydotoold.service
[Unit]
Description=ydotool daemon

[Service]
Type=simple
# Specify socket explicitly so clients can find it
ExecStart=/usr/bin/ydotoold --socket-path=/tmp/.ydotool_socket
Restart=always
RestartSec=3
Environment=DISPLAY=:0

[Install]
WantedBy=default.target
EOF

# Main script
cat << EOF > ~/.config/systemd/user/voice-typer.service
[Unit]
Description=Whisper Voice Typing Service
After=network.target sound.target ydotoold.service
Requires=ydotoold.service

[Service]
Type=simple
Environment=PYTHONUNBUFFERED=1
Environment=DISPLAY=:0
Environment=YDOTOOL_SOCKET=/tmp/.ydotool_socket

ExecStart=$PROJECT_DIR/venv/bin/python $PROJECT_DIR/main_wayland.py
WorkingDirectory=$PROJECT_DIR
KillMode=process
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

# --- STARTUP ---
echo -e "${BLUE}>>> Starting services...${NC}"
systemctl --user daemon-reload
systemctl --user enable ydotoold voice-typer
systemctl --user restart ydotoold
systemctl --user restart voice-typer

# --- F8 HOTKEY ---
echo -e "${BLUE}>>> Setting up F8...${NC}"
KEY_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-voice-typer/"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH name 'Voice Typing'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH command 'systemctl --user kill -s SIGUSR1 voice-typer'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH binding 'F8'

# Safe addition to list
CURRENT=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
if [[ "$CURRENT" != *"$KEY_PATH"* ]]; then
    if [[ "$CURRENT" == "@as []" ]]; then NEW="['$KEY_PATH']"; else NEW="${CURRENT%]*}, '$KEY_PATH']"; fi
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$NEW"
fi

# Ensure uinput module is loaded and permissions are set
sudo modprobe uinput
sudo chmod 666 /dev/uinput

# Restart services
systemctl --user restart ydotoold
systemctl --user restart voice-typer

# Wait a bit for services to start
sleep 3

# Check if wtype is available for Wayland, install if needed
if command -v wtype &> /dev/null; then
    echo -e "${GREEN}✅ wtype found - Wayland support enabled${NC}"
else
    echo -e "${BLUE}Installing wtype for Wayland support...${NC}"
    sudo apt install -y wtype
    if command -v wtype &> /dev/null; then
        echo -e "${GREEN}✅ wtype installed successfully${NC}"
    else
        echo -e "${BLUE}⚠️ wtype installation failed, will use ydotool fallback${NC}"
    fi
fi

# Check session type
SESSION_TYPE=$(echo $XDG_SESSION_TYPE)
echo -e "${BLUE}Session type: $SESSION_TYPE${NC}"

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN} READY! YOU CAN USE IT NOW. ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "Instructions:"
echo -e "1. Open Terminal, Browser or Telegram."
echo -e "2. Press F8 to start recording."
echo -e "3. Say a phrase."
echo -e "4. Press F8 to stop and paste."
echo -e ""
echo -e "The system will automatically detect:"
echo -e "- Terminal applications → uses Ctrl+Shift+V"
echo -e "- GUI applications → uses Ctrl+V"
echo -e "- Wayland → uses wtype"
echo -e "- X11 → uses ydotool"
echo -e ""
echo -e "Debug commands:"
echo -e "  Voice service: journalctl --user -u voice-typer -f"
echo -e "  ydotool daemon: journalctl --user -u ydotoold -f"
echo -e "  Check session: echo \$XDG_SESSION_TYPE"
echo -e "  Check permissions: ls -la /dev/uinput"
