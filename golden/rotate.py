import os
from PIL import Image
import numpy as np


INPUT_IMAGE = "../data/input.jpg"
DATA_DIR = "../data"

WIDTH  = 1024
HEIGHT = 1024

ROTATE_ANGLE = 90  
if not os.path.exists(DATA_DIR):
    os.makedirs(DATA_DIR)
img = Image.open(INPUT_IMAGE)
if img.mode != "RGB":
    img = img.convert("RGB")
img = img.resize((WIDTH, HEIGHT))

arr = np.array(img)
height, width, channels = arr.shape
print(f"处理后图片大小: {width}x{height}, 通道数: {channels}")
input_file = os.path.join(DATA_DIR, "input.txt")

with open(input_file, "w") as f:
    for row in arr:
        for pixel in row:
            f.write(f"{pixel[0]} {pixel[1]} {pixel[2]}\n")

print(f"输入文件生成完成: {input_file}")
rotated_arr = np.rot90(arr)  

golden_file = os.path.join(DATA_DIR, "golden.txt")

with open(golden_file, "w") as f:
    for row in rotated_arr:
        for pixel in row:
            f.write(f"{pixel[0]} {pixel[1]} {pixel[2]}\n")

print(f"Golden 文件生成完成: {golden_file}")
print("输入像素数:", arr.shape[0] * arr.shape[1])
print("输出像素数:", rotated_arr.shape[0] * rotated_arr.shape[1])

print("所有文件生成完成，可以直接给 SystemVerilog Testbench 使用！")