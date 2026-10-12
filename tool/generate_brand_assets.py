"""Generate the ARODesk app icon and splash PNG from the checked-in brand artwork."""
from pathlib import Path
from io import BytesIO
from PIL import Image
import cairosvg

root = Path(__file__).resolve().parents[1]
svg = (root / "assets/arodesk_brand_mark.svg").read_bytes()
source = Image.open(BytesIO(cairosvg.svg2png(bytestring=svg, output_width=1600, output_height=1600))).convert("RGBA")
bbox = source.getchannel("A").getbbox()
if not bbox:
    raise RuntimeError("The ARODesk brand artwork has no visible pixels")
icon = source.crop(bbox)
icon.thumbnail((820, 820), Image.Resampling.LANCZOS)
canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
canvas.alpha_composite(icon, ((1024 - icon.width) // 2, (1024 - icon.height) // 2))
(canvas).save(root / "assets/logo.png", optimize=True)
android = root / "android/app/src/main/res/drawable"
android.mkdir(parents=True, exist_ok=True)
canvas.resize((512, 512), Image.Resampling.LANCZOS).save(android / "brand_splash.png", optimize=True)
print("Created ARODesk logo.png and Android splash from checked-in SVG brand source.")
