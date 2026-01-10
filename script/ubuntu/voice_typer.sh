#!/bin/bash

# ==========================================
# Voice Typer Installer for Ubuntu Wayland
# ==========================================
# Features:
# 1. Installs via APT (standard package manager).
# 2. Automatically fixes the broken ydotool package in Ubuntu 24.04.
# 3. Sets up Python virtual environment.
# 4. Configures systemd services.
# 5. Automatically registers the F8 keyboard shortcut.

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}>>> Starting Voice Typer installation...${NC}"

# 1. Install system dependencies
echo -e "${BLUE}>>> Installing system packages via APT...${NC}"
sudo apt update
sudo apt install -y python3-venv python3-pip portaudio19-dev git curl ydotool

# 2. FIX FOR BROKEN YDOTOOL IN UBUNTU 24.04
# The standard package often misses 'ydotoold'. We fix this by symlinking.
echo -e "${BLUE}>>> Checking/Fixing ydotool installation...${NC}"

if ! command -v ydotoold &> /dev/null; then
    echo "⚠️ 'ydotoold' binary not found (common Ubuntu bug)."
    if command -v ydotool &> /dev/null; then
        echo "✅ 'ydotool' client found. Creating symlink to fix the daemon..."
        # We link ydotool to ydotoold. In many versions, it's a multi-call binary.
        # If not, this is the best effort without compilation.
        sudo ln -sf $(which ydotool) /usr/bin/ydotoold
        sudo ln -sf $(which ydotool) /usr/local/bin/ydotoold
    else
        echo -e "${RED}Error: ydotool package failed to install.${NC}"
        exit 1
    fi
else
    echo "✅ 'ydotoold' is present."
fi

# 3. Configure permissions (udev rules)
echo -e "${BLUE}>>> Configuring udev rules (permissions)...${NC}"
echo 'KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/80-uinput.rules > /dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo usermod -aG input $USER

# 4. Create project directory
PROJECT_DIR="$HOME/voice-typer"
echo -e "${BLUE}>>> Setting up project folder: ${PROJECT_DIR}${NC}"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 5. Create Virtual Environment
if [ ! -d "venv" ]; then
    echo -e "${BLUE}>>> Creating Python venv...${NC}"
    python3 -m venv venv
fi

# 6. Install Python Libraries
echo -e "${BLUE}>>> Installing Python dependencies...${NC}"
source venv/bin/activate
pip install --upgrade pip
pip install faster-whisper sounddevice numpy scipy

# 7. Generate main_wayland.py
echo -e "${BLUE}>>> Generating application code...${NC}"
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

RU_TO_EN_KEYMAP = {
    'а': 'f', 'б': ',', 'в': 'd', 'г': 'u', 'д': 'l', 'е': 't', 'ё': '`', 'ж': ';', 'з': 'p',
    'и': 'b', 'й': 'q', 'к': 'r', 'л': 'k', 'м': 'v', 'н': 'y', 'о': 'j', 'п': 'g',
    'р': 'h', 'с': 'c', 'т': 'n', 'у': 'e', 'ф': 'a', 'х': '[', 'ц': 'w', 'ч': 'x',
    'ш': 'i', 'щ': 'o', 'ъ': ']', 'ы': 's', 'ь': 'm', 'э': "'", 'ю': '.', 'я': 'z',
    'А': 'F', 'Б': '<', 'В': 'D', 'Г': 'U', 'Д': 'L', 'Е': 'T', 'Ё': '~', 'Ж': ':', 'З': 'P',
    'И': 'B', 'Й': 'Q', 'К': 'R', 'Л': 'K', 'М': 'V', 'Н': 'Y', 'О': 'J', 'П': 'G',
    'Р': 'H', 'С': 'C', 'Т': 'N', 'У': 'E', 'Ф': 'A', 'Х': '{', 'Ц': 'W', 'Ч': 'X',
    'Ш': 'I', 'Щ': 'O', 'Ъ': '}', 'Ы': 'S', 'Ь': 'M', 'Э': '"', 'Ю': '>', 'Я': 'Z',
    '.': '/', ',': '?', '?': '&', ';': '$', ':': '^', '"': '@', '-': '-', ' ': ' '
}

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
            self.type_mapped_text(text)

    def audio_callback(self, indata, frames, time, status):
        if self.recording:
            self.audio_data.append(indata.copy())

    def type_mapped_text(self, text):
        final_keystrokes = ""
        for char in text:
            if char in RU_TO_EN_KEYMAP:
                final_keystrokes += RU_TO_EN_KEYMAP[char]
            else:
                final_keystrokes += char

        try:
            env = os.environ.copy()
            if "YDOTOOL_SOCKET" not in env:
                env["YDOTOOL_SOCKET"] = "/tmp/.ydotool_socket"

            subprocess.run(["ydotool", "type", "--key-delay", "100", final_keystrokes], env=env)
            print("--- TYPED ---")
        except Exception as e:
            print(f"Typing Error: {e}")

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

# Finds where the binary (or our symlink) is located
YDO_BIN=$(which ydotoold)

# Service for ydotool daemon
cat << EOF > ~/.config/systemd/user/ydotoold.service
[Unit]
Description=ydotool daemon

[Service]
Type=simple
ExecStart=$YDO_BIN
Restart=always

[Install]
WantedBy=default.target
EOF

# Service for main python script
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

# 10. Automated Keyboard Shortcut Setup (GNOME)
echo -e "${BLUE}>>> Configuring F8 Shortcut (GNOME)...${NC}"
KEY_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-voice-typer/"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH name 'Voice Typing'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH command 'systemctl --user kill -s SIGUSR1 voice-typer'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH binding 'F8'

# Add to active bindings list
CURRENT_BINDINGS=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
if [[ "$CURRENT_BINDINGS" == "@as []" ]]; then
    NEW_BINDINGS="['$KEY_PATH']"
else
    # Check if already exists to avoid duplicates (simple check)
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
echo -e "2. Switch keyboard layout to match your language (RU/EN)."
echo -e ""
echo -e "${BLUE}Logs: journalctl --user -u voice-typer -f${NC}"