#!/bin/bash

# ==========================================
# Voice Typer Installer for Ubuntu Wayland
# ==========================================

set -e # Exit immediately if a command exits with a non-zero status

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}>>> Starting Voice Typer installation...${NC}"

# 1. Install system dependencies
echo -e "${BLUE}>>> Installing system packages...${NC}"
sudo apt update
sudo apt install -y python3-venv python3-pip portaudio19-dev git ydotool curl

# 2. Configure permissions (udev rules) for ydotool
# This fixes the "failed to open uinput device" error permanently
echo -e "${BLUE}>>> Configuring udev rules for ydotool (permissions)...${NC}"
echo 'KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/80-uinput.rules > /dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger
# Add current user to the input group
sudo usermod -aG input $USER

# 3. Create project directory
PROJECT_DIR="$HOME/voice-typer"
echo -e "${BLUE}>>> Creating project directory: ${PROJECT_DIR}${NC}"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 4. Create virtual environment
if [ ! -d "venv" ]; then
    echo -e "${BLUE}>>> Creating Python virtual environment (venv)...${NC}"
    python3 -m venv venv
fi

# 5. Install Python libraries
echo -e "${BLUE}>>> Installing Python libraries (Whisper, SoundDevice)...${NC}"
source venv/bin/activate
pip install --upgrade pip
pip install faster-whisper sounddevice numpy scipy

# 6. Generate the main Python script (main_wayland.py)
echo -e "${BLUE}>>> Generating application code (main_wayland.py)...${NC}"
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

# --- CONFIGURATION ---
MODEL_SIZE = "small"
COMPUTE_TYPE = "int8"
SAMPLE_RATE = 16000
TEMP_AUDIO_FILE = "/tmp/voice_input.wav"

# Translation Map: Russian char -> English key
# Required because ydotool (simulating a US keyboard) does not understand Cyrillic input.
# This maps the Russian character to the physical key location on a US keyboard.
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

        # Language auto-detection
        segments, info = self.model.transcribe(TEMP_AUDIO_FILE, beam_size=1)
        print(f"Detected language: {info.language} (probability {info.language_probability:.2f})")

        text = " ".join([segment.text for segment in segments]).strip()
        print(f"Recognized: '{text}'")

        if text:
            self.type_mapped_text(text)

    def audio_callback(self, indata, frames, time, status):
        if self.recording:
            self.audio_data.append(indata.copy())

    def type_mapped_text(self, text):
        """
        Smart Typing:
        1. If char is in the Russian map, convert to English key (for RU layout).
        2. If char is not in map (English/Numbers), type as is.
        """
        final_keystrokes = ""
        for char in text:
            if char in RU_TO_EN_KEYMAP:
                final_keystrokes += RU_TO_EN_KEYMAP[char]
            else:
                final_keystrokes += char

        try:
            env = os.environ.copy()
            # Set default socket path if not present in environment
            if "YDOTOOL_SOCKET" not in env:
                env["YDOTOOL_SOCKET"] = "/tmp/.ydotool_socket"

            # key_delay ensures the system processes keystrokes correctly
            subprocess.run(["ydotool", "type", "--key-delay", "100", final_keystrokes], env=env)
            print("--- TYPED ---")
        except Exception as e:
            print(f"Typing Error: {e}")

typer = VoiceTyper()

def signal_handler(sig, frame):
    typer.toggle_recording()

if __name__ == "__main__":
    signal.signal(signal.SIGUSR1, signal_handler)
    # Keep the script running
    while True:
        time.sleep(1)
EOF

# 7. Configure Systemd service for ydotoold (Input Daemon)
echo -e "${BLUE}>>> Configuring ydotoold service...${NC}"
mkdir -p ~/.config/systemd/user
cat << EOF > ~/.config/systemd/user/ydotoold.service
[Unit]
Description=ydotool daemon

[Service]
Type=simple
ExecStart=/usr/bin/ydotoold
Restart=always

[Install]
WantedBy=default.target
EOF

# 8. Configure Systemd service for Voice Typer (Main App)
echo -e "${BLUE}>>> Configuring voice-typer service...${NC}"
cat << EOF > ~/.config/systemd/user/voice-typer.service
[Unit]
Description=Whisper Voice Typing Service
After=network.target sound.target ydotoold.service
Requires=ydotoold.service

[Service]
Type=simple
Environment=PYTHONUNBUFFERED=1
Environment=DISPLAY=:0
# ydotool usually listens on this socket
Environment=YDOTOOL_SOCKET=/tmp/.ydotool_socket

ExecStart=$PROJECT_DIR/venv/bin/python $PROJECT_DIR/main_wayland.py
WorkingDirectory=$PROJECT_DIR

# Prevent Systemd from killing child processes (like ydotool/wl-copy)
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

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}INSTALLATION SUCCESSFUL!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "There is ONE LAST STEP (Keyboard Shortcut Setup):"
echo -e "1. Go to Settings -> Keyboard -> View and Customize Shortcuts -> Custom Shortcuts."
echo -e "2. Add a new shortcut:"
echo -e "   Name:     Voice Typing"
echo -e "   Command:  systemctl --user kill -s SIGUSR1 voice-typer"
echo -e "   Shortcut: F8 (or your preference)"
echo -e ""
echo -e "Usage:"
echo -e "1. Switch keyboard layout to Russian (for RU speech) or English (for EN speech)."
echo -e "2. Press F8, speak, then press F8 again."
echo -e ""
echo -e "${BLUE}To view logs, run: journalctl --user -u voice-typer -f${NC}"