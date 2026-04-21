from datetime import datetime
class KeyCounter:
    def __init__(self):
        self.start_time = datetime.now()
        self.key_count = 0

    def increment(self):
        self.key_count += 1
    
    def get_count(self):
        return self.key_count
    
    def get_start_time(self):
        return self.start_time