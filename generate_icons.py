import os
from PIL import Image, ImageDraw, ImageFont

def generate_monex_icon():
    size = 1024
    img = Image.new('RGBA', (size, size), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)

    blue = (43, 89, 255, 255) # #2B59FF

    # Draw large 3 slanted rounded bars in the center
    # Slashes parameters (slanted dynamic rectangles)
    # Top bar
    # (x, y) coordinates for rounded bars
    # Bar 1: Top
    draw.rounded_rectangle([250, 180, 774, 320], radius=50, fill=blue)
    # Bar 2: Middle (Prominent long)
    draw.rounded_rectangle([150, 390, 874, 530], radius=50, fill=blue)
    # Bar 3: Bottom
    draw.rounded_rectangle([250, 600, 774, 740], radius=50, fill=blue)

    # Save to icon paths
    os.makedirs('assets/icon', exist_ok=True)
    img.save('assets/icon/app_icon.png', 'PNG')
    img.save('assets/logo.png', 'PNG')
    img.save('assets/icon.png', 'PNG')
    print("Icons generated successfully!")

if __name__ == '__main__':
    generate_monex_icon()
