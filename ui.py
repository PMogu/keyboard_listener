import os
import time

def start_ui(counter):
    while True:
        os.system("cls" if os.name == "nt" else "clear")

        print("Start time: ", counter.get_start_time())
        print("Key count: ", counter.get_count())

        time.sleep(0.5)