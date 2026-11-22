#!/usr/bin/env python3
"""Puntea USB: duce datele mănușii (legată prin USB la calculator) în aplicația de pe telefon sau din emulator.

Mănușa (firmware-ul glove.cpp) scrie pe USB linii „P <28 cifre hex>” = pachetul Live din contract.
Puntea le trimite aplicației printr-o conexiune TCP pe portul 8765, iar comenzile aplicației
(„C <cod> <valoare>”) le scrie înapoi mănușii.

Telefonul sau emulatorul ajung la calculator prin `adb reverse`, pe care puntea îl pornește singură.

Rulare:
    ~/.platformio/penv/bin/python tools/usb_bridge.py
Oprire: Ctrl+C. Monitorul serial trebuie să fie închis: portul USB îl poate folosi un singur program.
"""

import glob
import os
import socket
import subprocess
import sys
import threading
import time

import serial  # pyserial, vine cu PlatformIO

PORT_TCP = 8765  # nu 5554–5585: acolo stau emulatoarele Android
BAUD = 115200
ADB = os.path.expanduser("~/Library/Android/sdk/platform-tools/adb")


def find_serial_port():
    ports = sorted(glob.glob("/dev/cu.usbserial*") + glob.glob("/dev/cu.wchusbserial*") + glob.glob("/dev/cu.SLAB*"))
    return ports[0] if ports else None


def adb_reverse():
    """Face ca 127.0.0.1:8765 pe telefon/emulator să ajungă la calculator."""
    if not os.path.exists(ADB):
        print("! Nu găsesc adb; pe telefon/emulator conexiunea poate să nu meargă.")
        return
    devices = [l.split("\t")[0] for l in subprocess.run([ADB, "devices"], capture_output=True, text=True).stdout.splitlines()[1:] if "\tdevice" in l]
    if not devices:
        print("! Niciun telefon sau emulator văzut de adb. Pornește emulatorul sau leagă telefonul, apoi repornește puntea.")
    for d in devices:
        subprocess.run([ADB, "-s", d, "reverse", f"tcp:{PORT_TCP}", f"tcp:{PORT_TCP}"], capture_output=True)
        print(f"  adb reverse pornit pentru {d}")


class Bridge:
    def __init__(self):
        self.client = None
        self.lock = threading.Lock()
        self.ser = None
        self.packets = 0

    def send_to_app(self, line: bytes):
        with self.lock:
            if self.client is None:
                return
            try:
                self.client.sendall(line)
            except OSError:
                self.client = None
                print("  aplicația s-a deconectat")

    def serial_loop(self):
        """Citește mănușa; dacă se deconectează cablul, așteaptă și se reconectează."""
        while True:
            port = find_serial_port()
            if not port:
                print("  aștept mănușa pe USB…")
                time.sleep(2)
                continue
            try:
                self.ser = serial.Serial(port, BAUD, timeout=1)
                print(f"* Mănușa conectată pe {port}")
                while True:
                    raw = self.ser.readline()
                    if not raw:
                        continue
                    if raw.startswith(b"P "):
                        self.packets += 1
                        self.send_to_app(raw)
                    elif raw.startswith(b"#"):
                        print("  mănușa:", raw.decode(errors="replace").strip())
            except (serial.SerialException, OSError) as e:
                print(f"! Legătura USB s-a întrerupt ({e}). Reîncerc…")
                self.ser = None
                time.sleep(2)

    def client_loop(self, conn):
        buf = b""
        while True:
            try:
                data = conn.recv(256)
            except OSError:
                break
            if not data:
                break
            buf += data
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                if (line.startswith(b"C ") or line.startswith(b"W ")) and self.ser is not None:
                    self.ser.write(line + b"\n")
                    # Parola Wi-Fi nu se afișează în terminal.
                    shown = line.split(b";")[0] + b";***" if line.startswith(b"W ") else line
                    print("  comandă către mănușă:", shown.decode(errors="replace"))
        with self.lock:
            if self.client is conn:
                self.client = None
        print("  aplicația s-a deconectat")

    def stats_loop(self):
        while True:
            time.sleep(10)
            print(f"  {self.packets / 10:.1f} pachete/s · aplicație {'conectată' if self.client else 'neconectată'}")
            self.packets = 0

    def run(self):
        print("Puntea USB a mănușii")
        adb_reverse()
        threading.Thread(target=self.serial_loop, daemon=True).start()
        threading.Thread(target=self.stats_loop, daemon=True).start()
        srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            srv.bind(("127.0.0.1", PORT_TCP))
        except OSError:
            print(f"! Portul {PORT_TCP} e ocupat: probabil puntea rulează deja în alt terminal. Oprește-o (Ctrl+C acolo) și încearcă din nou.")
            sys.exit(1)
        srv.listen(1)
        print(f"* Aștept aplicația pe portul {PORT_TCP} (Ctrl+C oprește puntea)")
        while True:
            conn, _ = srv.accept()
            conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            with self.lock:
                if self.client is not None:
                    try:
                        self.client.close()
                    except OSError:
                        pass
                self.client = conn
            print("* Aplicația s-a conectat")
            threading.Thread(target=self.client_loop, args=(conn,), daemon=True).start()


if __name__ == "__main__":
    try:
        Bridge().run()
    except KeyboardInterrupt:
        print("\nPuntea s-a oprit.")
        sys.exit(0)
