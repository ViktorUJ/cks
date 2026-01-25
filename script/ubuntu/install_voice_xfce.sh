#!/bin/bash

# ==========================================
# Voice Typer Installer (Dual Buffer Fix)
# ==========================================

set -e

PROJECT_DIR="$HOME/voice-typer"
SERVICE_FILE="$HOME/.config/systemd/user/voice-typer.service"

echo -e "\033[0;34m>>> 1. Checking dependencies...\033[0m"
sudo apt update
sudo apt install -y python3-venv python3-pip portaudio19-dev build-essential xdotool xsel libasound-dev

echo -e "\033[0;34m>>> 2. Setting up Python...\033[0m"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"
rm -rf venv
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install "numpy==1.26.4"
pip install faster-whisper sounddevice scipy xlib

echo -e "\033[0;34m>>> 3. Model...\033[0m"
cat << 'EOF' > download_model.py
from faster_whisper import WhisperModel
try:
    model = WhisperModel("small", device="cpu", compute_type="int8")
except: pass
EOF
python download_model.py
rm download_model.py

echo -e "\033[0;34m>>> 4. Creating main.py (With dual buffer)...\033[0m"
cat << 'EOF' > main.py
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
        print(f"Loading {MODEL_SIZE}...")
        self.model = WhisperModel(MODEL_SIZE, device="cpu", compute_type=COMPUTE_TYPE)
        print("✅ Ready!")

    def toggle_recording(self):
        if self.recording:
            self.stop_recording()
        else:
            self.start_recording()

    def start_recording(self):
        print("--- 🔴 REC ---")
        os.system('paplay /usr/share/sounds/freedesktop/stereo/camera-shutter.oga 2>/dev/null &')
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

        os.system('paplay /usr/share/sounds/freedesktop/stereo/message.oga 2>/dev/null &')

        my_recording = np.concatenate(self.audio_data, axis=0)
        my_recording = (my_recording * 32767).astype(np.int16)
        write(TEMP_AUDIO_FILE, SAMPLE_RATE, my_recording)

        segments, info = self.model.transcribe(TEMP_AUDIO_FILE, beam_size=1)
        text = " ".join([segment.text for segment in segments]).strip()
        print(f"Recognized: '{text}'")

        if text:
            self.dual_paste(text)

    def audio_callback(self, indata, frames, time, status):
        if self.recording:
            self.audio_data.append(indata.copy())

    def dual_paste(self, text):
        """Fills both Clipboard and Primary buffers to work everywhere"""
        try:
            encoded_text = text.encode('utf-8')

            # 1. Fill CLIPBOARD (for Chrome, PyCharm - Ctrl+V)
            p1 = subprocess.Popen(['xsel', '-b', '-i'], stdin=subprocess.PIPE)
            p1.communicate(input=encoded_text)

            # 2. Fill PRIMARY (for Terminal - Shift+Insert)
            p2 = subprocess.Popen(['xsel', '-p', '-i'], stdin=subprocess.PIPE)
            p2.communicate(input=encoded_text)
            
            time.sleep(0.2) 

            # 3. Press Shift+Insert (universal)
            print("Debug: Pasting...")
            subprocess.run(["xdotool", "key", "--clearmodifiers", "Shift+Insert"])
                
        except Exception as e:
            print(f"Error: {e}")

typer = VoiceTyper()

def signal_handler(sig, frame):
    typer.toggle_recording()

if __name__ == "__main__":
    signal.signal(signal.SIGUSR1, signal_handler)
    typer.load_model()
    while True:
        time.sleep(1)
EOF

echo -e "\033[0;34m>>> 5. Trigger...\033[0m"
cat << 'EOF' > "$PROJECT_DIR/trigger.sh"
#!/bin/bash
systemctl --user kill -s SIGUSR1 voice-typer
EOF
chmod +x "$PROJECT_DIR/trigger.sh"

echo -e "\033[0;34m>>> 6. Restarting service...\033[0m"
mkdir -p ~/.config/systemd/user
cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Voice Typer
After=network.target sound.target

[Service]
Type=simple
Environment=PYTHONUNBUFFERED=1
Environment=DISPLAY=:0
ExecStart=$PROJECT_DIR/venv/bin/python $PROJECT_DIR/main.py
WorkingDirectory=$PROJECT_DIR
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable voice-typer
systemctl --user restart voice-typer

echo ""
echo "DONE! Now Russian text should be correctly pasted into the terminal as well."
