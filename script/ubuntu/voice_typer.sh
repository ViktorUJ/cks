#!/bin/bash

# ==========================================
# Voice Typer Installer for Ubuntu Wayland
# ==========================================
# VERSION: CLIPBOARD PASTE (Instant & Error-free)
# 1. Compiles ydotool.
# 2. Installs wl-clipboard.
# 3. Uses Ctrl+V to insert text instantly.

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}>>> Starting Voice Typer installation...${NC}"

# 1. Install Dependencies
# Added 'wl-clipboard' for copy-paste functionality
echo -e "${BLUE}>>> Installing system dependencies...${NC}"
sudo apt update
sudo apt install -y python3-venv python3-pip portaudio19-dev git curl \
    build-essential cmake pkg-config scdoc libevdev-dev wl-clipboard

# 2. Compile Ydotool from Source
echo -e "${BLUE}>>> Compiling ydotool from source...${NC}"

BUILD_DIR="/tmp/voice_typer_build_final"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

build_git() {
    URL=$1
    NAME=$2
    echo -e "${BLUE}>>> Building $NAME...${NC}"
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

if ! command -v ydotoold &> /dev/null; then
    echo -e "\033[0;31mError: ydotoold failed to install.\033[0m"
    exit 1
fi
echo -e "${GREEN}>>> ydotool installed successfully!${NC}"

# 3. Configure Permissions
echo -e "${BLUE}>>> Configuring permissions...${NC}"
echo 'KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/80-uinput.rules > /dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo usermod -aG input $USER

# 4. Project Setup
PROJECT_DIR="$HOME/voice-typer"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 5. Python Environment
if [ ! -d "venv" ]; then
    echo -e "${BLUE}>>> Creating Python venv...${NC}"
    python3 -m venv venv
fi

# 6. Install Python Libs
echo -e "${BLUE}>>> Installing Python libraries...${NC}"
source venv/bin/activate
pip install --upgrade pip
pip install faster-whisper sounddevice numpy scipy

# 7. Generate App Code (CLIPBOARD VERSION)
echo -e "${BLUE}>>> Generating main_wayland.py...${NC}"
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

# --- CONFIG ---
MODEL_SIZE = "medium"
COMPUTE_TYPE = "int8"
SAMPLE_RATE = 16000
TEMP_AUDIO_FILE = "/tmp/voice_input.wav"

class VoiceTyper:
    def __init__(self):
        print(f"Loading Whisper Model ({MODEL_SIZE})...")
        self.model = WhisperModel(MODEL_SIZE, device="cpu", compute_type=COMPUTE_TYPE)
        print(f"Model loaded. PID: {os.getpid()}")
        self.recording = False
        self.audio_data = []
        self.stream = None

    def toggle_recording(self):
        if self.recording:
            self.stop_recording()
        else:
            self.start_recording()

    def start_recording(self):
        print("--- 🔴 REC ---")
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
        print(f"Detected language: {info.language}")

        text = " ".join([segment.text for segment in segments]).strip()
        print(f"Recognized: '{text}'")

        if text:
            self.paste_text(text)

    def audio_callback(self, indata, frames, time, status):
        if self.recording:
            self.audio_data.append(indata.copy())

    def paste_text(self, text):
        """
        Copies text to clipboard using wl-copy and presses Ctrl+V.
        This is much faster and safer than typing character by character.
        """
        try:
            # 1. Copy to clipboard (Wayland)
            subprocess.run(["wl-copy", text], check=True)

            # 2. Press Ctrl+V using ydotool
            env = os.environ.copy()
            env["YDOTOOL_SOCKET"] = "/tmp/.ydotool_socket"

            # Key codes: 29=Left Ctrl, 47=V
            # Sequence: Ctrl Down, V Down, V Up, Ctrl Up
            subprocess.run(["ydotool", "key", "29:1", "47:1", "47:0", "29:0"], env=env)

            print("--- PASTED ---")
        except Exception as e:
            print(f"Paste Error: {e}")

typer = VoiceTyper()

def signal_handler(sig, frame):
    typer.toggle_recording()

if __name__ == "__main__":
    signal.signal(signal.SIGUSR1, signal_handler)
    while True:
        time.sleep(1)
EOF

# 8. Configure Systemd Services
echo -e "${BLUE}>>> Configuring systemd services...${NC}"
mkdir -p ~/.config/systemd/user

# ydotoold service
cat << EOF > ~/.config/systemd/user/ydotoold.service
[Unit]
Description=ydotool daemon

[Service]
Type=simple
ExecStart=/usr/bin/ydotoold --socket-path=/tmp/.ydotool_socket
Restart=always

[Install]
WantedBy=default.target
EOF

# voice-typer service
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

# 9. Start Services
echo -e "${BLUE}>>> Starting services...${NC}"
systemctl --user daemon-reload
systemctl --user enable --now ydotoold
systemctl --user enable --now voice-typer

# 10. Configure F8 Shortcut
echo -e "${BLUE}>>> Configuring F8 Shortcut...${NC}"
KEY_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-voice-typer/"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH name 'Voice Typing'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH command 'systemctl --user kill -s SIGUSR1 voice-typer'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH binding 'F8'

CURRENT_BINDINGS=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
if [[ "$CURRENT_BINDINGS" == "@as []" ]]; then
    NEW_BINDINGS="['$KEY_PATH']"
else
    if [[ "$CURRENT_BINDINGS" != *"$KEY_PATH"* ]]; then
        NEW_BINDINGS="${CURRENT_BINDINGS%]*}, '$KEY_PATH']"
    else
        NEW_BINDINGS="$CURRENT_BINDINGS"
    fi
fi
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$NEW_BINDINGS"

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "Usage:"
echo -e "1. Press F8 -> Speak -> Press F8."
echo -e "2. The text will be inserted INSTANTLY (via Ctrl+V)."