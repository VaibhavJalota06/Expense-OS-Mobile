from PIL import Image

def enlarge_app_icon():
    img = Image.open('assets/icon/app_icon.png')
    
    # The inner squircle in the image is roughly from (140, 140) to (884, 884)
    # Let's crop into the inner squircle so the logo fills the entire app icon
    w, h = img.size
    crop_box = (145, 145, 879, 879)
    cropped = img.crop(crop_box)
    
    # Resize back to 1024x1024 with high quality LANCZOS filter
    enlarged = cropped.resize((1024, 1024), Image.Resampling.LANCZOS)
    enlarged.save('assets/icon/app_icon.png', 'PNG')
    print("App icon enlarged successfully!")

if __name__ == '__main__':
    enlarge_app_icon()
