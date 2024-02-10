import os
import sys


file_name = sys.argv[1]
size = os.path.getsize(f"{file_name}.bin")

small = open(f"{file_name}.bin", "rb")
big = open(f"{file_name}.img", "wb")
big.write(small.read())
bytes = b'\x00' * (1474560 - size)
big.write(bytes)