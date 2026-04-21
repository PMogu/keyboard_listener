from pynput import keyboard

def start_listener(counter):
    def on_press(key):
        counter.increment()

    listener = keyboard.Listener(on_press=on_press)
    listener.start()
    return listener