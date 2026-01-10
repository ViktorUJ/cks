#!/bin/bash

# ==========================================
# Voice Typer Installer (Ultimate Version)
# ==========================================
# 1. Compiles ydotool from source (Fixes Ubuntu 24.04 daemon).
# 2. Uses 'Double Paste' strategy (Ctrl+Shift+V + Ctrl+V) to work everywhere.
# 3. Pre-downloads Whisper 'medium' model.
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
    build-essential cmake pkg-config scdoc libevdev-dev wl-clipboard

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
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo usermod -aG input $USER

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
echo -e "${BLUE}>>> DOWNLOADING 'medium' MODEL (~1.5 GB)...${NC}"
echo -e "${BLUE}>>> This is needed to make the first run fast.${NC}"
cat << 'EOF' > download_model.py
from faster_whisper import WhisperModel
print("--- Start Download ---")
model = WhisperModel("medium", device="cpu", compute_type="int8")
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

MODEL_SIZE = "medium"
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
        'Double Paste' method:
        1. Copies text to clipboard.
        2. Presses Ctrl+Shift+V (for terminal).
        3. Presses Ctrl+V (for everything else).
        Extra press is usually just ignored by the system.
        """
        try:
            # 1. Copy to clipboard
            subprocess.run(["wl-copy", text], check=True)
            time.sleep(0.05) # Small pause for clipboard

            env = os.environ.copy()
            env["YDOTOOL_SOCKET"] = "/tmp/.ydotool_socket"

            # 2. ATTEMPT FOR TERMINAL (Ctrl+Shift+V)
            # 29=Ctrl, 42=Shift, 47=V
            subprocess.run(["ydotool", "key", "29:1", "42:1", "47:1", "47:0", "42:0", "29:0"], env=env)

            # 3. ATTEMPT FOR GUI (Ctrl+V)
            # 29=Ctrl, 47=V
            subprocess.run(["ydotool", "key", "29:1", "47:1", "47:0", "29:0"], env=env)

            print("--- PASTED (Double Paste) ---")
        except Exception as e:
            print(f"Paste error: {e}")

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

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN} READY! YOU CAN USE IT NOW. ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "Instructions:"
echo -e "1. Open Terminal, Browser or Telegram."
echo -e "2. Press F8."
echo -e "3. Say a phrase."
echo -e "4. Press F8."
echo -e "Text will be pasted automatically (uses both Ctrl+V and Ctrl+Shift+V)."
