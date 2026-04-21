from model import KeyCounter
from keyboard_listener import start_listener
from ui import start_ui
from datetime import datetime, timedelta
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

def auto_log(counter, filename="keycounter_log.txt"):
    while True:
        now = datetime.now()
        next_noon = now.replace(hour=21, minute=0, second=0, microsecond=0)
        if now >= next_noon:
            next_noon = next_noon + timedelta(days=1)

        sleep_seconds = (next_noon - now).total_seconds()
        time.sleep(sleep_seconds)

        write_log(counter, filename="keycounter_log.txt")

def main():
    counter = KeyCounter()
    listener = start_listener(counter)
    autosave_thread = threading.Thread(
        target=auto_log,
        args=(counter,),
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