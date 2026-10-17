#!/usr/bin/env python3
"""Lossless host-side crops; requires Pillow, like the film checker."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw
root=Path(sys.argv[1])
box=(328,154,972,556)
parts=[]
for build in ['base','branch']:
    source=Image.open(root/(build+'-text-grid.png')).convert('RGB')
    assert source.size==(1920,1080)
    tile=source.crop(box)
    tile.save(root/(build+'-text-tile.png'))
    parts.append(tile)
combined=Image.new('RGB',(2*parts[0].width+16,parts[0].height+28),'white')
draw=ImageDraw.Draw(combined)
for col,(name,tile) in enumerate(zip(['Base','Branch'],parts)):
    x=col*(tile.width+16)
    combined.paste(tile,(x,28))
    draw.text((x+8,8),name,fill='black')
    assert combined.crop((x,28,x+tile.width,28+tile.height)).tobytes()==tile.tobytes()
combined.save(root/'text-tile-comparison.png')
print('Unscaled source crop:',box)
