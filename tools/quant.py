import glob,sys
from PIL import Image
for f in glob.glob(sys.argv[1]+'/*.png'):
    im=Image.open(f).convert('RGBA')
    im.quantize(colors=96,method=Image.Quantize.FASTOCTREE).save(f,optimize=True)
