from model import KeyCounter
from keyboard_listener import start_listener
from ui import start_ui
from datetime import datetime
import threading
import time

def write_log(counter, filename="keycounter_log.txt"):
    start_time = counter.get_start_time()
    end_time = datetime.now()
    duration = end_time - start_time
    count = counter.get_count()

    start_str = start_time.strftime("%Y-%m-%d %H:%M:%S")
    end_str = end_time.strftime("%Y-%m-%d %H:%M:%S")
    duration_seconds = int(duration.total_seconds())

    line = f"start={start_str} | end={end_str} | duration={duration_seconds}s | keys={count}\n"

    with open(filename, "a", encoding="utf-8") as f:
        f.write(line)

def auto_log(counter, interval=60, filename="keycounter_log.txt"):
    while True:
        time.sleep(interval)
        write_log(counter, filename="keycounter_log.txt")

def main():
    counter = KeyCounter()
    listener = start_listener(counter)
    autosave_thread = threading.Thread(
        target=auto_log,
        args=(counter, 86400, "keycounter_log.txt"),
        daemon=True,
    )
    autosave_thread.start()
    try:
        start_ui(counter)
    except KeyboardInterrupt:
        print("\nExiting and saving session...")
    finally:
        write_log(counter)
        print("Session saved to log file.")

if __name__ == "__main__":
    main()